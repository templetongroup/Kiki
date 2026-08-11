import AppKit

/// Inserts text into the frontmost app by putting it on the pasteboard and
/// synthesizing ⌘V, then restoring the previous pasteboard string.
/// This is the most reliable insertion method across apps (same approach
/// as Wispr Flow-style tools).
enum TextInserter {
    enum Result {
        case inserted
        case copiedNeedsAccessibility
        case failed
    }

    @discardableResult
    @MainActor
    static func insert(_ text: String, context: AppContextSnapshot? = nil) -> Result {
        let pasteboard = NSPasteboard.general

        guard AXIsProcessTrusted() else {
            // Without Accessibility permission we can't synthesize keystrokes;
            // leave the text on the clipboard so the user can paste manually.
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            return .copiedNeedsAccessibility
        }

        let previous = pasteboard.string(forType: .string)
        let learningAnchor: CorrectionLearningObserver.Anchor? = context.flatMap { snapshot in
            guard Settings.learnFromCorrections, snapshot.privacyPolicy.learningEnabled else { return nil }
            return CorrectionLearningObserver.shared.captureAnchor(context: snapshot)
        }
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        guard synthesizePaste() else { return .failed }

        // Restore the old clipboard once the paste has landed, but only if
        // nothing else has written to the pasteboard in the meantime.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            if let previous, pasteboard.string(forType: .string) == text {
                pasteboard.clearContents()
                pasteboard.setString(previous, forType: .string)
            }
        }
        if let learningAnchor {
            CorrectionLearningObserver.shared.observe(
                insertedText: text,
                anchor: learningAnchor,
                context: context
            )
        }
        return .inserted
    }

    @MainActor
    static func copyOnly(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    @MainActor
    static func undoExact(_ text: String, processIdentifier: pid_t) -> Bool {
        guard AXIsProcessTrusted(),
              NSWorkspace.shared.frontmostApplication?.processIdentifier == processIdentifier else { return false }
        let application = AXUIElementCreateApplication(processIdentifier)
        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            application,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        ) == .success,
        let focusedValue else { return false }
        let focused = unsafeBitCast(focusedValue, to: AXUIElement.self)

        var valueRef: CFTypeRef?
        var selectionRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focused, kAXValueAttribute as CFString, &valueRef) == .success,
              let currentValue = valueRef as? String,
              AXUIElementCopyAttributeValue(focused, kAXSelectedTextRangeAttribute as CFString, &selectionRef) == .success,
              let selectionRef,
              CFGetTypeID(selectionRef) == AXValueGetTypeID() else { return false }
        let selectionValue = unsafeBitCast(selectionRef, to: AXValue.self)
        var selectedRange = CFRange()
        guard AXValueGetValue(selectionValue, .cfRange, &selectedRange) else { return false }
        let selection = NSRange(location: selectedRange.location, length: selectedRange.length)
        guard let deletionRange = ExactInsertionUndoPlanner.range(
            insertedText: text,
            currentValue: currentValue,
            selection: selection
        ) else { return false }

        var deletionCFRange = CFRange(location: deletionRange.location, length: deletionRange.length)
        guard let deletionValue = AXValueCreate(.cfRange, &deletionCFRange),
              AXUIElementSetAttributeValue(
                focused,
                kAXSelectedTextRangeAttribute as CFString,
                deletionValue
              ) == .success else { return false }
        if AXUIElementSetAttributeValue(focused, kAXSelectedTextAttribute as CFString, "" as CFString) == .success {
            return true
        }
        return synthesizeDelete()
    }

    private static func synthesizePaste() -> Bool {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey = CGKeyCode(9) // kVK_ANSI_V
        let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        guard let down, let up else { return false }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        return true
    }

    private static func synthesizeDelete() -> Bool {
        let source = CGEventSource(stateID: .combinedSessionState)
        let deleteKey = CGKeyCode(51)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: deleteKey, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: deleteKey, keyDown: false) else { return false }
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        return true
    }
}
