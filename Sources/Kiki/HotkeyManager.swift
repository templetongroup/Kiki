import AppKit
import Carbon.HIToolbox

/// Two activation paths:
///  - Hold the configured modifier key: record while held, transcribe on release.
///  - ⌃⌥D: toggle recording on/off (better for long dictation).
///
/// The toggle uses a Carbon global hotkey (no permissions needed, swallows the
/// keystroke). The hold detection uses NSEvent modifier-flag monitors, which
/// need Accessibility permission to see events in other apps.
final class HotkeyManager {
    var onToggle: @MainActor () -> Void = {}
    var onHoldStart: @MainActor () -> Void = {}
    var onHoldEnd: @MainActor () -> Void = {}
    var onCancel: @MainActor () -> Void = {}

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var monitors: [Any] = []
    private var triggerDown = false

    var dictationShortcut: DictationShortcut = Settings.dictationShortcut {
        didSet { triggerDown = false }
    }
    var activationMode: ActivationMode = Settings.activationMode

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
        let mask: NSEvent.EventTypeMask = [.flagsChanged, .keyDown, .keyUp]
        let handle: (NSEvent) -> Void = { [weak self] event in
            self?.handleTriggerEvent(event)
        }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handle) {
            monitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { event in
            handle(event)
            return event
        }) {
            monitors.append(local)
        }
    }

    private func handleTriggerEvent(_ event: NSEvent) {
        if event.type == .keyDown, event.keyCode == UInt16(kVK_Escape) {
            DispatchQueue.main.async { self.onCancel() }
            return
        }
        let shortcut = dictationShortcut
        guard event.keyCode == shortcut.keyCode else { return }

        let isDown: Bool
        if shortcut.isModifierOnly, let flag = DictationShortcut.modifierFlag(for: shortcut.keyCode) {
            guard event.type == .flagsChanged else { return }
            isDown = event.modifierFlags.contains(flag)
        } else {
            guard event.type == .keyDown || event.type == .keyUp else { return }
            let relevant: NSEvent.ModifierFlags = [.command, .option, .control, .shift, .function]
            if event.type == .keyDown {
                guard event.modifierFlags.intersection(relevant) == shortcut.modifiers.intersection(relevant) else {
                    return
                }
                isDown = true
            } else {
                // A user can release the modifier before releasing the letter.
                // The matching key-up still ends the hold and rearms the shortcut.
                isDown = false
            }
        }

        if isDown && !triggerDown {
            triggerDown = true
            DispatchQueue.main.async {
                if self.activationMode == .hold { self.onHoldStart() } else { self.onToggle() }
            }
        } else if !isDown && triggerDown {
            triggerDown = false
            if activationMode == .hold { DispatchQueue.main.async { self.onHoldEnd() } }
        }
    }

    func processEventForDiagnostics(_ event: NSEvent) {
        handleTriggerEvent(event)
    }

    var diagnosticTriggerDown: Bool { triggerDown }
}
