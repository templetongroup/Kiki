import AppKit

/// Inserts text into the frontmost app by putting it on the pasteboard and
/// synthesizing ⌘V, then restoring the previous pasteboard string.
/// This is the most reliable insertion method across apps (same approach
/// as Wispr Flow-style tools).
enum TextInserter {
    static func insert(_ text: String) {
        let pasteboard = NSPasteboard.general

        guard AXIsProcessTrusted() else {
            // Without Accessibility permission we can't synthesize keystrokes;
            // leave the text on the clipboard so the user can paste manually.
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            return
        }

        let previous = pasteboard.string(forType: .string)
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        synthesizePaste()

        // Restore the old clipboard once the paste has landed, but only if
        // nothing else has written to the pasteboard in the meantime.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            if let previous, pasteboard.string(forType: .string) == text {
                pasteboard.clearContents()
                pasteboard.setString(previous, forType: .string)
            }
        }
    }

    private static func synthesizePaste() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey = CGKeyCode(9) // kVK_ANSI_V
        let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
