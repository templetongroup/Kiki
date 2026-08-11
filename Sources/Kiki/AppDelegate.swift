import AppKit
import AVFoundation
import UniformTypeIdentifiers

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let controller = DictationController()
    private let hotkeys = HotkeyManager()
    private let updateController = UpdateController()
    private var lastExternalContext: AppContextSnapshot?
    private var checkupInputResponding = false
    private var checkupShortcutArmed = false
    private var checkupPracticeArmed = false
    private lazy var settingsWindow: SettingsWindowController = {
        let controller = SettingsWindowController()
        controller.onSettingsChange = { [weak self] shortcut, mode in
            self?.hotkeys.dictationShortcut = shortcut
            self?.hotkeys.activationMode = mode
            Settings.checkupShortcutVerified = false
            self?.render(self?.controller.state ?? .idle)
            self?.refreshCheckup(restartInputMonitor: false)
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
    private lazy var pawprintsWindow = PawprintsWindowController()
    private lazy var personalizationWindow = PersonalizationWindowController()
    private lazy var whatsNewWindow: WhatsNewWindowController = {
        let window = WhatsNewWindowController()
        window.onExplore = { [weak self] in self?.openCheckup() }
        return window
    }()
    private lazy var meetingWindow: MeetingWindowController = {
        let window = MeetingWindowController()
        window.onCaptureStateChange = { [weak self] active in
            self?.controller.setMeetingCaptureActive(active)
        }
        window.onBeginLiveTranscription = { [weak self] onUpdate in
            self?.controller.makeMeetingLiveTranscription(onUpdate: onUpdate)
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
    private lazy var voiceStudioWindow: VoiceStudioWindowController = {
        let window = VoiceStudioWindowController()
        window.onCaptureStateChange = { [weak self] active in
            self?.controller.setMeetingCaptureActive(active)
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
    private lazy var checkupWindow: KikiCheckupWindowController = {
        let window = KikiCheckupWindowController()
        window.onRefresh = { [weak self] in
            self?.checkupShortcutArmed = false
            self?.checkupPracticeArmed = false
            self?.refreshCheckup(restartInputMonitor: true)
        }
        window.onTestShortcut = { [weak self, weak window] in
            guard let self else { return }
            self.checkupShortcutArmed = true
            window?.armShortcutTest(displayString: Settings.dictationShortcut.displayString)
        }
        window.onBeginPractice = { [weak self] in
            guard let self else { return }
            self.checkupPracticeArmed = true
            self.checkupShortcutArmed = false
        }
        window.onMicrophoneSelected = { [weak self] uniqueID in
            Settings.microphoneDeviceUID = uniqueID
            self?.checkupInputResponding = false
            self?.refreshCheckup(restartInputMonitor: true)
        }
        window.onInputDetected = { [weak self] in
            self?.checkupInputResponding = true
            self?.refreshCheckup(restartInputMonitor: false)
        }
        window.onWillClose = { [weak self] in
            self?.checkupShortcutArmed = false
            self?.checkupPracticeArmed = false
        }
        return window
    }()

    private let stateMenuItem = NSMenuItem(title: "Starting…", action: nil, keyEquivalent: "")
    private let modelMenuItem = NSMenuItem(title: "Model: none", action: nil, keyEquivalent: "")
    private let toggleMenuItem = NSMenuItem(title: "Start Dictation", action: #selector(toggleDictation), keyEquivalent: "")
    private lazy var undoLastDictationMenuItem: NSMenuItem = {
        let item = menuItem("Undo Last Dictation", symbol: "arrow.uturn.backward", action: #selector(undoLastDictation))
        item.isEnabled = false
        return item
    }()
    private lazy var retryLastDictationMenuItem: NSMenuItem = {
        let item = menuItem("Retry Last Dictation", symbol: "arrow.clockwise", action: #selector(retryLastDictation))
        item.isEnabled = false
        return item
    }()
    private lazy var privateSessionMenuItem: NSMenuItem = {
        menuItem("Start Private Session", symbol: "eye.slash", action: #selector(togglePrivateSession))
    }()
    private lazy var updateMenuItem: NSMenuItem = {
        let item = NSMenuItem(title: "Check for Updates", action: #selector(UpdateController.checkForUpdates(_:)), keyEquivalent: "")
        item.target = updateController
        item.image = menuIcon("arrow.triangle.2.circlepath")
        return item
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppearanceController.apply()
        switch ProcessInfo.processInfo.environment["KIKI_PREVIEW_APPEARANCE"]?.lowercased() {
        case "light": NSApp.appearance = NSAppearance(named: .aqua)
        case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
        default: break
        }
        updateController.onUpdateAvailable = { [weak self] available in
            self?.updateMenuItem.title = available ? "Update Available" : "Check for Updates"
        }
        setupStatusItem()
        requestPermissions()

        controller.onStateChange = { [weak self] state in
            self?.render(state)
            self?.refreshCheckup(restartInputMonitor: false)
        }
        controller.onSuccessfulInsertion = { [weak self] _, context in
            guard let self,
                  self.checkupPracticeArmed,
                  context.bundleIdentifier == Bundle.main.bundleIdentifier else { return }
            self.checkupPracticeArmed = false
            Settings.checkupFirstDictationCompleted = true
            self.refreshCheckup(restartInputMonitor: true)
        }
        controller.onLastDictationActionsChange = { [weak self] canUndo, canRetry in
            self?.undoLastDictationMenuItem.isEnabled = canUndo
            self?.retryLastDictationMenuItem.isEnabled = canRetry
        }
        hotkeys.onHoldStart = { [weak self] in
            guard let self else { return }
            if self.consumeCheckupShortcutTest() { return }
            if self.checkupWindow.window?.isVisible == true { self.checkupWindow.stopInputMonitor() }
            self.controller.startRecording()
        }
        hotkeys.onHoldEnd = { [weak self] in self?.controller.finishRecording() }
        hotkeys.onToggle = { [weak self] in
            guard let self else { return }
            if self.consumeCheckupShortcutTest() { return }
            if self.checkupWindow.window?.isVisible == true { self.checkupWindow.stopInputMonitor() }
            self.controller.toggleRecording()
        }
        hotkeys.onCancel = { [weak self] in self?.controller.cancelRecording() }
        hotkeys.start()

        controller.prepare()
        if ProcessInfo.processInfo.environment["KIKI_OPEN_VOICE_STUDIO"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.openVoiceStudio()
            }
        }
        if ProcessInfo.processInfo.environment["KIKI_OPEN_CHECKUP"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.openCheckup()
            }
        }
        if ProcessInfo.processInfo.environment["KIKI_OPEN_PAWPRINTS"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.openPawprints()
            }
        }
        if ProcessInfo.processInfo.environment["KIKI_SUPPRESS_WHATS_NEW"] != "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
                self?.whatsNewWindow.showIfNeeded(
                    force: ProcessInfo.processInfo.environment["KIKI_FORCE_WHATS_NEW"] == "1"
                )
            }
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
        menu.addItem(undoLastDictationMenuItem)
        menu.addItem(retryLastDictationMenuItem)
        menu.addItem(privateSessionMenuItem)
        menu.addItem(.separator())

        menu.addItem(menuSection("Features"))
        menu.addItem(menuItem("Kiki Checkup", symbol: "checkmark.shield", action: #selector(openCheckup)))
        menu.addItem(menuItem("Meeting Mode", symbol: "person.2.wave.2", action: #selector(openMeetingMode)))
        menu.addItem(menuItem("Voice Studio", symbol: "waveform.badge.mic", action: #selector(openVoiceStudio)))
        menu.addItem(menuItem("Read Selection in My Voice", symbol: "speaker.wave.2", action: #selector(readSelectionInMyVoice)))
        menu.addItem(menuItem("Transcribe Audio File", symbol: "waveform.badge.magnifyingglass", action: #selector(openFileTranscription)))
        menu.addItem(menuItem("Personalization Studio", symbol: "brain.head.profile", action: #selector(openPersonalization)))

        menu.addItem(.separator())
        menu.addItem(menuSection("Library"))
        menu.addItem(menuItem("History", symbol: "clock.arrow.circlepath", action: #selector(openHistory)))
        menu.addItem(menuItem("Pawprints", symbol: "pawprint", action: #selector(openPawprints)))
        menu.addItem(menuItem("Dictionary", symbol: "text.book.closed", action: #selector(openDictionary)))
        menu.addItem(menuItem("Create Support Bundle…", symbol: "wrench.and.screwdriver", action: #selector(createSupportBundle)))

        menu.addItem(.separator())
        menu.addItem(menuItem("Settings", symbol: "gearshape", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(menuItem("What’s New in Kiki", symbol: "sparkles", action: #selector(openWhatsNew)))
        menu.addItem(menuItem("Models Folder", symbol: "folder", action: #selector(openModelsFolder)))

        menu.addItem(.separator())
        menu.addItem(menuItem("Accessibility Settings", symbol: "accessibility", action: #selector(openAccessibilitySettings)))
        menu.addItem(menuItem("Microphone Settings", symbol: "mic", action: #selector(openMicrophoneSettings)))

        menu.addItem(updateMenuItem)

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit Kiki", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        menu.autoenablesItems = false
        statusItem.menu = menu
    }

    private func menuItem(
        _ title: String,
        symbol: String,
        action: Selector,
        keyEquivalent: String = ""
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.target = self
        item.image = menuIcon(symbol)
        return item
    }

    private func menuSection(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title.uppercased(), action: nil, keyEquivalent: "")
        item.isEnabled = false
        item.attributedTitle = NSAttributedString(
            string: title.uppercased(),
            attributes: [
                .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
                .foregroundColor: NSColor.secondaryLabelColor,
                .kern: 0.7,
            ]
        )
        return item
    }

    private func menuIcon(_ symbol: String) -> NSImage? {
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        image?.size = NSSize(width: 15, height: 15)
        image?.isTemplate = true
        return image
    }

    private func requestPermissions() {
        AVCaptureDevice.requestAccess(for: .audio) { _ in }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    private func render(_ state: DictationState) {
        let model = controller.activeModelName ?? "none installed"
        modelMenuItem.title = "Model: \(model)"
        undoLastDictationMenuItem.isEnabled = state == .idle && controller.canUndoLastDictation
        retryLastDictationMenuItem.isEnabled = state == .idle && controller.canRetryLastDictation

        switch state {
        case .noModel:
            stateMenuItem.title = "Model unavailable — open Settings"
            toggleMenuItem.isEnabled = false
        case .loadingModel:
            stateMenuItem.title = "Loading model…"
            toggleMenuItem.isEnabled = false
        case .idle:
            stateMenuItem.title = PrivateSessionController.shared.isActive
                ? "Private Session — no history or learning"
                : "Idle — \(Settings.dictationShortcut.displayString) or ⌃⌥D"
            toggleMenuItem.title = "Start Dictation (⌃⌥D)"
            toggleMenuItem.isEnabled = true
        case .recording:
            stateMenuItem.title = PrivateSessionController.shared.isActive ? "Recording privately…" : "Recording…"
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

    @objc private func undoLastDictation() {
        controller.undoLastDictation()
    }

    @objc private func retryLastDictation() {
        controller.retryLastDictation()
    }

    @objc private func togglePrivateSession() {
        PrivateSessionController.shared.toggle()
        let active = PrivateSessionController.shared.isActive
        privateSessionMenuItem.title = active ? "End Private Session" : "Start Private Session"
        privateSessionMenuItem.state = active ? .on : .off
        if active { controller.markCurrentRecordingPrivate() }
        render(controller.state)
    }

    @objc private func openSettings() {
        _ = captureExternalContext()
        settingsWindow.show()
    }

    @objc private func openCheckup() {
        checkupWindow.show()
        refreshCheckup(restartInputMonitor: true)
    }

    @objc private func openHistory() {
        historyWindow.show()
    }

    @objc private func openPawprints() {
        pawprintsWindow.show()
    }

    @objc private func openWhatsNew() {
        whatsNewWindow.showIfNeeded(force: true)
    }

    @objc private func openDictionary() {
        dictionaryWindow.show()
    }

    @objc private func createSupportBundle() {
        let panel = NSSavePanel()
        panel.title = "Create Kiki Support Bundle"
        panel.nameFieldStringValue = "Kiki-Support.zip"
        panel.allowedContentTypes = [.zip]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try SupportBundleBuilder.createArchive(at: url, modelReady: controller.isModelReady)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
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

    @objc private func openVoiceStudio() {
        voiceStudioWindow.show()
    }

    @objc private func readSelectionInMyVoice() {
        guard let selection = AppContextSnapshot.selectedTextFromFrontmostApplication() else {
            let alert = NSAlert()
            alert.messageText = "Select text first"
            alert.informativeText = "Highlight text in any accessible app, then choose Read Selection in My Voice again."
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }
        voiceStudioWindow.show(prefilledText: selection)
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

    private func consumeCheckupShortcutTest() -> Bool {
        guard checkupShortcutArmed else { return false }
        checkupShortcutArmed = false
        Settings.checkupShortcutVerified = true
        refreshCheckup(restartInputMonitor: false)
        return true
    }

    private func refreshCheckup(restartInputMonitor: Bool) {
        guard checkupWindow.window?.isVisible == true else { return }
        let microphones = AudioInputDevice.available()
        let selected = AudioInputDevice.selected(from: microphones, preferredID: Settings.microphoneDeviceUID)
        if Settings.microphoneDeviceUID == nil { Settings.microphoneDeviceUID = selected?.uniqueID }
        checkupWindow.setMicrophones(
            microphones.map { .init(name: $0.name, uniqueID: $0.uniqueID) },
            selectedID: selected?.uniqueID
        )
        let microphoneAuthorized = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        checkupWindow.update(
            snapshot: KikiCheckupSnapshot(
                microphoneAuthorized: microphoneAuthorized,
                inputResponding: microphoneAuthorized && checkupInputResponding,
                accessibilityAuthorized: AXIsProcessTrusted(),
                modelReady: controller.isModelReady,
                shortcutVerified: Settings.checkupShortcutVerified,
                firstDictationCompleted: Settings.checkupFirstDictationCompleted
            )
        )
        if restartInputMonitor, microphoneAuthorized { checkupWindow.startInputMonitor() }
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
