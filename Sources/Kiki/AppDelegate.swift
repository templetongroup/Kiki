import AppKit
import AVFoundation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let controller = DictationController()
    private let hotkeys = HotkeyManager()
    private let updateController = UpdateController()
    private var lastExternalContext: AppContextSnapshot?
    private lazy var settingsWindow: SettingsWindowController = {
        let controller = SettingsWindowController()
        controller.onSettingsChange = { [weak self] shortcut, mode in
            self?.hotkeys.dictationShortcut = shortcut
            self?.hotkeys.activationMode = mode
            self?.render(self?.controller.state ?? .idle)
        }
        controller.onModelChange = { [weak self] model in
            self?.controller.selectModel(model)
        }
        controller.onAppearanceChange = {
            AppearanceController.apply()
        }
        controller.onAutomaticUpdatesChange = { [weak self] enabled in
            self?.updateController.automaticallyChecksForUpdates = enabled
        }
        controller.onOpenPersonalization = { [weak self] in
            guard let self else { return }
            self.personalizationWindow.show(context: self.captureExternalContext())
        }
        return controller
    }()
    private lazy var dictionaryWindow = CustomDictionaryWindowController()
    private lazy var historyWindow = HistoryWindowController()
    private lazy var personalizationWindow = PersonalizationWindowController()
    private lazy var whatsNewWindow: WhatsNewWindowController = {
        let window = WhatsNewWindowController()
        window.onExplore = { [weak self] in self?.settingsWindow.show() }
        return window
    }()
    private lazy var meetingWindow: MeetingWindowController = {
        let window = MeetingWindowController()
        window.onCaptureStateChange = { [weak self] active in
            self?.controller.setMeetingCaptureActive(active)
        }
        window.onTranscribe = { [weak self] capture, title in
            guard let self else { throw KikiError("Kiki is unavailable.") }
            return try await self.controller.transcribeMeeting(
                microphoneSamples: capture.microphoneSamples,
                systemSamples: capture.systemSamples,
                duration: capture.duration,
                title: title
            )
        }
        return window
    }()
    private lazy var fileTranscriptionWindow: FileTranscriptionWindowController = {
        let window = FileTranscriptionWindowController()
        window.onTranscribe = { [weak self] url in
            guard let self else { throw KikiError("Kiki is unavailable.") }
            return try await self.controller.transcribeFile(at: url)
        }
        return window
    }()

    private let stateMenuItem = NSMenuItem(title: "Starting…", action: nil, keyEquivalent: "")
    private let modelMenuItem = NSMenuItem(title: "Model: none", action: nil, keyEquivalent: "")
    private let toggleMenuItem = NSMenuItem(title: "Start Dictation", action: #selector(toggleDictation), keyEquivalent: "")
    private lazy var updateMenuItem: NSMenuItem = {
        let item = NSMenuItem(title: "Check for Updates…", action: #selector(UpdateController.checkForUpdates(_:)), keyEquivalent: "")
        item.target = updateController
        return item
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppearanceController.apply()
        updateController.onUpdateAvailable = { [weak self] available in
            self?.updateMenuItem.title = available ? "Update Available…" : "Check for Updates…"
        }
        setupStatusItem()
        requestPermissions()

        controller.onStateChange = { [weak self] state in
            self?.render(state)
        }
        hotkeys.onHoldStart = { [weak self] in self?.controller.startRecording() }
        hotkeys.onHoldEnd = { [weak self] in self?.controller.finishRecording() }
        hotkeys.onToggle = { [weak self] in self?.controller.toggleRecording() }
        hotkeys.onCancel = { [weak self] in self?.controller.cancelRecording() }
        hotkeys.start()

        controller.prepare()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            self?.whatsNewWindow.showIfNeeded()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.prepareForTermination()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = Self.menuBarIcon()

        let menu = NSMenu()
        stateMenuItem.isEnabled = false
        modelMenuItem.isEnabled = false
        toggleMenuItem.target = self
        menu.addItem(stateMenuItem)
        menu.addItem(modelMenuItem)
        menu.addItem(.separator())
        menu.addItem(toggleMenuItem)
        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let historyItem = NSMenuItem(title: "History…", action: #selector(openHistory), keyEquivalent: "")
        historyItem.target = self
        menu.addItem(historyItem)

        let whatsNewItem = NSMenuItem(title: "What’s New…", action: #selector(openWhatsNew), keyEquivalent: "")
        whatsNewItem.target = self
        menu.addItem(whatsNewItem)

        let dictionaryItem = NSMenuItem(title: "Dictionary…", action: #selector(openDictionary), keyEquivalent: "")
        dictionaryItem.target = self
        menu.addItem(dictionaryItem)

        let personalizationItem = NSMenuItem(title: "Personalization Studio…", action: #selector(openPersonalization), keyEquivalent: "")
        personalizationItem.target = self
        menu.addItem(personalizationItem)

        let fileItem = NSMenuItem(title: "Transcribe File…", action: #selector(openFileTranscription), keyEquivalent: "")
        fileItem.target = self
        menu.addItem(fileItem)

        let meetingItem = NSMenuItem(title: "Meeting Mode…", action: #selector(openMeetingMode), keyEquivalent: "")
        meetingItem.target = self
        menu.addItem(meetingItem)

        let modelsItem = NSMenuItem(title: "Open Models Folder", action: #selector(openModelsFolder), keyEquivalent: "")
        modelsItem.target = self
        menu.addItem(modelsItem)

        let permissionsItem = NSMenuItem(title: "Open Accessibility Settings", action: #selector(openAccessibilitySettings), keyEquivalent: "")
        permissionsItem.target = self
        menu.addItem(permissionsItem)

        let microphoneItem = NSMenuItem(title: "Open Microphone Settings", action: #selector(openMicrophoneSettings), keyEquivalent: "")
        microphoneItem.target = self
        menu.addItem(microphoneItem)

        menu.addItem(updateMenuItem)

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
            stateMenuItem.title = "Model unavailable — open Settings"
            toggleMenuItem.isEnabled = false
        case .loadingModel:
            stateMenuItem.title = "Loading model…"
            toggleMenuItem.isEnabled = false
        case .idle:
            stateMenuItem.title = "Idle — \(Settings.dictationShortcut.displayString) or ⌃⌥D"
            toggleMenuItem.title = "Start Dictation (⌃⌥D)"
            toggleMenuItem.isEnabled = true
        case .recording:
            stateMenuItem.title = "Recording…"
            toggleMenuItem.title = "Stop && Transcribe (⌃⌥D)"
            toggleMenuItem.isEnabled = true
        case .transcribing:
            stateMenuItem.title = "Transcribing…"
            toggleMenuItem.title = Settings.enableZeroWaitChaining
                ? "Start Another Dictation (⌃⌥D)"
                : "Transcribing…"
            toggleMenuItem.isEnabled = Settings.enableZeroWaitChaining
        }
    }

    @objc private func toggleDictation() {
        controller.toggleRecording()
    }

    @objc private func openSettings() {
        _ = captureExternalContext()
        settingsWindow.show()
    }

    @objc private func openHistory() {
        historyWindow.show()
    }

    @objc private func openWhatsNew() {
        whatsNewWindow.showIfNeeded(force: true)
    }

    @objc private func openDictionary() {
        dictionaryWindow.show()
    }

    @objc private func openPersonalization() {
        personalizationWindow.show(context: captureExternalContext())
    }

    @objc private func openFileTranscription() {
        fileTranscriptionWindow.show()
    }

    @objc private func openMeetingMode() {
        meetingWindow.show()
    }

    @objc private func openModelsFolder() {
        ModelStore.ensureDirectory()
        NSWorkspace.shared.open(ModelStore.modelsDirectory)
    }

    @objc private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    @objc private func openMicrophoneSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
        NSWorkspace.shared.open(url)
    }

    private func captureExternalContext() -> AppContextSnapshot? {
        let context = AppContextSnapshot.capture()
        if context.bundleIdentifier != Bundle.main.bundleIdentifier {
            lastExternalContext = context
        }
        return lastExternalContext
    }

    private static func menuBarIcon() -> NSImage? {
        guard let url = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png"),
              let image = NSImage(contentsOf: url) else { return nil }
        image.size = NSSize(width: 20, height: 20)
        image.isTemplate = false
        image.accessibilityDescription = "Kiki"
        return image
    }
}
