import AppKit
import Carbon.HIToolbox

/// Two activation paths:
///  - Hold Right Option (⌥): record while held, transcribe on release.
///  - ⌃⌥D: toggle recording on/off (better for long dictation).
///
/// The toggle uses a Carbon global hotkey (no permissions needed, swallows the
/// keystroke). The hold detection uses NSEvent modifier-flag monitors, which
/// need Accessibility permission to see events in other apps.
final class HotkeyManager {
    var onToggle: () -> Void = {}
    var onHoldStart: () -> Void = {}
    var onHoldEnd: () -> Void = {}

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var monitors: [Any] = []
    private var rightOptionDown = false

    private static let rightOptionKeyCode: UInt16 = 61 // kVK_RightOption

    func start() {
        registerToggleHotkey()
        installHoldMonitors()
    }

    private func registerToggleHotkey() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { manager.onToggle() }
            return noErr
        }, 1, &spec, selfPtr, &eventHandlerRef)

        let hotKeyID = EventHotKeyID(signature: OSType(0x4B69_6B69), id: 1) // 'Kiki'
        RegisterEventHotKey(UInt32(kVK_ANSI_D),
                            UInt32(controlKey | optionKey),
                            hotKeyID,
                            GetApplicationEventTarget(),
                            0,
                            &hotKeyRef)
    }

    private func installHoldMonitors() {
        let handle: (NSEvent) -> Void = { [weak self] event in
            self?.handleFlagsChanged(event)
        }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: handle) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: { event in
            handle(event)
            return event
        }) {
            monitors.append(local)
        }
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        guard event.keyCode == Self.rightOptionKeyCode else { return }
        let isDown = event.modifierFlags.contains(.option)
        if isDown && !rightOptionDown {
            rightOptionDown = true
            DispatchQueue.main.async { self.onHoldStart() }
        } else if !isDown && rightOptionDown {
            rightOptionDown = false
            DispatchQueue.main.async { self.onHoldEnd() }
        }
    }
}
