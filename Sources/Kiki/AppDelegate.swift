import AppKit
import AVFoundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let controller = DictationController()
    private let hotkeys = HotkeyManager()

    private let stateMenuItem = NSMenuItem(title: "Starting…", action: nil, keyEquivalent: "")
    private let modelMenuItem = NSMenuItem(title: "Model: none", action: nil, keyEquivalent: "")
    private let toggleMenuItem = NSMenuItem(title: "Start Dictation", action: #selector(toggleDictation), keyEquivalent: "")

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        requestPermissions()

        controller.onStateChange = { [weak self] state in
            self?.render(state)
        }
        hotkeys.onHoldStart = { [weak self] in self?.controller.startRecording() }
        hotkeys.onHoldEnd = { [weak self] in self?.controller.finishRecording() }
        hotkeys.onToggle = { [weak self] in self?.controller.toggleRecording() }
        hotkeys.start()

        controller.prepare()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = Self.icon("mic")

        let menu = NSMenu()
        stateMenuItem.isEnabled = false
        modelMenuItem.isEnabled = false
        toggleMenuItem.target = self
        menu.addItem(stateMenuItem)
        menu.addItem(modelMenuItem)
        menu.addItem(.separator())
        menu.addItem(toggleMenuItem)
        menu.addItem(.separator())

        let modelsItem = NSMenuItem(title: "Open Models Folder", action: #selector(openModelsFolder), keyEquivalent: "")
        modelsItem.target = self
        menu.addItem(modelsItem)

        let permissionsItem = NSMenuItem(title: "Open Accessibility Settings", action: #selector(openAccessibilitySettings), keyEquivalent: "")
        permissionsItem.target = self
        menu.addItem(permissionsItem)

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit Kiki", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        menu.autoenablesItems = false
        statusItem.menu = menu
    }

    private func requestPermissions() {
        AVCaptureDevice.requestAccess(for: .audio) { _ in }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    private func render(_ state: DictationState) {
        let model = controller.activeModelName ?? "none installed"
        modelMenuItem.title = "Model: \(model)"

        switch state {
        case .noModel:
            statusItem.button?.image = Self.icon("mic.slash")
            stateMenuItem.title = "No model — put one in the models folder"
            toggleMenuItem.isEnabled = false
        case .loadingModel:
            statusItem.button?.image = Self.icon("hourglass")
            stateMenuItem.title = "Loading model…"
            toggleMenuItem.isEnabled = false
        case .idle:
            statusItem.button?.image = Self.icon("mic")
            stateMenuItem.title = "Idle — hold Right ⌥ or press ⌃⌥D"
            toggleMenuItem.title = "Start Dictation (⌃⌥D)"
            toggleMenuItem.isEnabled = true
        case .recording:
            statusItem.button?.image = Self.icon("mic.fill")
            stateMenuItem.title = "Recording…"
            toggleMenuItem.title = "Stop && Transcribe (⌃⌥D)"
            toggleMenuItem.isEnabled = true
        case .transcribing:
            statusItem.button?.image = Self.icon("waveform")
            stateMenuItem.title = "Transcribing…"
            toggleMenuItem.isEnabled = false
        }
    }

    @objc private func toggleDictation() {
        controller.toggleRecording()
    }

    @objc private func openModelsFolder() {
        ModelStore.ensureDirectory()
        NSWorkspace.shared.open(ModelStore.modelsDirectory)
    }

    @objc private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    private static func icon(_ symbolName: String) -> NSImage? {
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Kiki")
        image?.isTemplate = true
        return image
    }
}
