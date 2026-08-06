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
    static func insert(_ text: String) -> Result {
        let pasteboard = NSPasteboard.general

        guard AXIsProcessTrusted() else {
            // Without Accessibility permission we can't synthesize keystrokes;
            // leave the text on the clipboard so the user can paste manually.
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            return .copiedNeedsAccessibility
        }

        let previous = pasteboard.string(forType: .string)
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
        return .inserted
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
}
