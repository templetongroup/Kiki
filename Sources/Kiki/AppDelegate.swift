import AppKit
import AVFoundation
import UniformTypeIdentifiers

enum DictationMenuCopy {
    static let start = "Start Dictation into Current App (⌃⌥D)"
    static let stop = "Stop, Transcribe, and Insert (⌃⌥D)"
    static let idleStatus = "Records locally, then inserts into the current app"
    static let recordingStatus = "Recording… Click again to stop and insert"
    static let privateRecordingStatus = "Recording privately… Click again to stop and insert"
}

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
    private var embeddedViews: [ObjectIdentifier: NSView] = [:]
    private var pendingVoicePrefill: String?
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
        controller.onAutomaticUpdatesChange = { [weak self] enabled in
            self?.updateController.automaticallyChecksForUpdates = enabled
        }
        controller.onOpenPersonalization = { [weak self] in
            self?.openWorkbench(section: .personalization)
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
    private lazy var workbenchHomeView: GuidedWorkbenchHomeView = {
        let view = GuidedWorkbenchHomeView()
        view.onStartDictation = { [weak self] in self?.controller.toggleRecording() }
        view.onOpenMeeting = { [weak self] in self?.openWorkbench(section: .meetings) }
        view.onOpenVoiceStudio = { [weak self] in self?.openWorkbench(section: .voice) }
        view.onOpenAudioFile = { [weak self] in self?.openWorkbench(section: .library, subpage: 1) }
        view.onOpenPersonalization = { [weak self] in self?.openWorkbench(section: .personalization) }
        view.onOpenCheckup = { [weak self] in self?.openCheckup() }
        return view
    }()
    private lazy var workbenchDictationView: GuidedWorkbenchDictationView = {
        let view = GuidedWorkbenchDictationView()
        view.onToggleDictation = { [weak self] in self?.controller.toggleRecording() }
        view.onUndo = { [weak self] in self?.controller.undoLastDictation() }
        view.onRetry = { [weak self] in self?.controller.retryLastDictation() }
        view.onPrivateSession = { [weak self] in self?.togglePrivateSession() }
        return view
    }()
    private lazy var workbenchSupportView: GuidedWorkbenchSupportView = {
        let view = GuidedWorkbenchSupportView()
        view.onCreateBundle = { [weak self] in self?.createSupportBundle() }
        view.onOpenModels = { [weak self] in self?.openModelsFolder() }
        view.onCheckUpdates = { [weak self] in self?.updateController.checkForUpdates(nil) }
        return view
    }()
    private lazy var workbenchAboutView: GuidedWorkbenchAboutView = {
        let view = GuidedWorkbenchAboutView()
        view.onRunCheckup = { [weak self] in self?.openCheckup() }
        return view
    }()
    private lazy var workbenchWindow: GuidedWorkbenchWindowController = {
        let window = GuidedWorkbenchWindowController()
        window.onRouteChange = { [weak self] route in self?.surface(for: route) }
        window.onToggleDictation = { [weak self] in self?.controller.toggleRecording() }
        window.onCanClose = { [weak self] in self?.canCloseWorkbench() ?? true }
        return window
    }()

    private let stateMenuItem = NSMenuItem(title: "Starting…", action: nil, keyEquivalent: "")
    private let modelMenuItem = NSMenuItem(title: "Model: none", action: nil, keyEquivalent: "")
    private let toggleMenuItem = NSMenuItem(title: DictationMenuCopy.start, action: #selector(toggleDictation), keyEquivalent: "")
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
            guard let self else { return }
            self.workbenchDictationView.update(state: self.controller.state, canUndo: canUndo, canRetry: canRetry)
        }
        hotkeys.onHoldStart = { [weak self] in
            guard let self else { return }
            if self.consumeCheckupShortcutTest() { return }
            if self.isCheckupVisible { self.checkupWindow.stopInputMonitor() }
            self.controller.startRecording()
        }
        hotkeys.onHoldEnd = { [weak self] in self?.controller.finishRecording() }
        hotkeys.onToggle = { [weak self] in
            guard let self else { return }
            if self.consumeCheckupShortcutTest() { return }
            if self.isCheckupVisible { self.checkupWindow.stopInputMonitor() }
            self.controller.toggleRecording()
        }
        hotkeys.onCancel = { [weak self] in self?.controller.cancelRecording() }
        hotkeys.start()

        controller.prepare()
        let shouldOpenWorkbench = ProcessInfo.processInfo.environment["KIKI_OPEN_WORKBENCH"] == "1"
            || CommandLine.arguments.contains("--preview-workbench")
            || NSWorkspace.shared.frontmostApplication?.bundleIdentifier == Bundle.main.bundleIdentifier
        if shouldOpenWorkbench {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.openWorkbench(section: .home)
            }
        }
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
        if ProcessInfo.processInfo.environment["KIKI_OPEN_MODELS"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.openWorkbench(section: .models)
            }
        }
        if ProcessInfo.processInfo.environment["KIKI_OPEN_MEETING"] == "1" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.openMeetingMode()
            }
        }
        showUnifiedWhatsNewIfNeeded()
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
        menu.addItem(menuItem("Open Kiki Workbench", symbol: "rectangle.split.3x1", action: #selector(openWorkbenchHome)))
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
        workbenchWindow.updateDictationState(state)
        workbenchDictationView.update(
            state: state,
            canUndo: state == .idle && controller.canUndoLastDictation,
            canRetry: state == .idle && controller.canRetryLastDictation
        )

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
                : DictationMenuCopy.idleStatus
            toggleMenuItem.title = DictationMenuCopy.start
            toggleMenuItem.isEnabled = true
        case .recording:
            stateMenuItem.title = PrivateSessionController.shared.isActive
                ? DictationMenuCopy.privateRecordingStatus
                : DictationMenuCopy.recordingStatus
            toggleMenuItem.title = DictationMenuCopy.stop
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
        openWorkbench(section: .settings)
    }

    @objc private func openCheckup() {
        openWorkbench(section: .settings, subpage: 4)
        refreshCheckup(restartInputMonitor: true)
    }

    @objc private func openHistory() {
        openWorkbench(section: .library)
    }

    @objc private func openPawprints() {
        openWorkbench(section: .settings, subpage: 5)
    }

    @objc private func openWhatsNew() {
        openWorkbench(section: .settings, subpage: 7)
    }

    @objc private func openDictionary() {
        openWorkbench(section: .personalization, subpage: 5)
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
        openWorkbench(section: .personalization)
    }

    @objc private func openFileTranscription() {
        openWorkbench(section: .library, subpage: 1)
    }

    @objc private func openMeetingMode() {
        openWorkbench(section: .meetings)
    }

    @objc private func openVoiceStudio() {
        openWorkbench(section: .voice)
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
        pendingVoicePrefill = selection
        openWorkbench(section: .voice)
    }

    @objc private func openWorkbenchHome() { openWorkbench(section: .home) }

    private var isCheckupVisible: Bool {
        checkupWindow.window?.isVisible == true
            || workbenchWindow.isShowing(section: .settings, subpage: 4)
    }

    private func openWorkbench(section: GuidedWorkbenchSection, subpage: Int = 0) {
        _ = captureExternalContext()
        workbenchWindow.show(section: section, subpage: subpage)
        if section == .settings, subpage == 4 {
            refreshCheckup(restartInputMonitor: true)
        }
    }

    private func surface(for route: GuidedWorkbenchRoute) -> GuidedWorkbenchSurface? {
        if !(route.section == .settings && route.subpage == 4) {
            checkupWindow.stopInputMonitor()
            checkupShortcutArmed = false
            checkupPracticeArmed = false
        }

        switch route.section {
        case .home:
            return GuidedWorkbenchSurface(view: workbenchHomeView, sizing: .fill)
        case .dictation:
            if route.subpage == 0 {
                workbenchDictationView.update(
                    state: controller.state,
                    canUndo: controller.state == .idle && controller.canUndoLastDictation,
                    canRetry: controller.state == .idle && controller.canRetryLastDictation
                )
                return GuidedWorkbenchSurface(view: workbenchDictationView, sizing: .fill)
            }
            return GuidedWorkbenchSurface(
                view: settingsWindow.workbenchPage(1),
                sizing: .fill
            )
        case .meetings:
            meetingWindow.prepareForEmbeddedDisplay()
            return GuidedWorkbenchSurface(
                view: embeddedView(for: meetingWindow),
                sizing: .scroll(NSSize(width: 960, height: 840))
            )
        case .voice:
            let prefill = pendingVoicePrefill
            pendingVoicePrefill = nil
            voiceStudioWindow.prepareForEmbeddedDisplay(prefilledText: prefill)
            return GuidedWorkbenchSurface(
                view: embeddedView(for: voiceStudioWindow),
                sizing: .scroll(NSSize(width: 1_080, height: 1_080))
            )
        case .library:
            if route.subpage == 0 {
                historyWindow.prepareForEmbeddedDisplay()
                return GuidedWorkbenchSurface(
                    view: embeddedView(for: historyWindow),
                    sizing: .top(NSSize(width: 920, height: 620))
                )
            }
            return GuidedWorkbenchSurface(
                view: embeddedView(for: fileTranscriptionWindow),
                sizing: .top(NSSize(width: 760, height: 720))
            )
        case .personalization:
            if route.subpage < 5 {
                return GuidedWorkbenchSurface(
                    view: personalizationWindow.workbenchPage(
                        context: captureExternalContext(),
                        page: route.subpage
                    ),
                    sizing: .scroll(NSSize(width: 1_030, height: 760))
                )
            }
            dictionaryWindow.prepareForEmbeddedDisplay()
            return GuidedWorkbenchSurface(
                view: embeddedView(for: dictionaryWindow),
                sizing: .top(NSSize(width: 760, height: 650))
            )
        case .models:
            return GuidedWorkbenchSurface(
                view: settingsWindow.workbenchPage(2),
                sizing: .fill
            )
        case .settings:
            switch route.subpage {
            case 0, 1, 2, 3:
                let settingsPage = [0, 1, 3, 4][route.subpage]
                return GuidedWorkbenchSurface(
                    view: settingsWindow.workbenchPage(settingsPage),
                    sizing: .fill
                )
            case 4:
                DispatchQueue.main.async { [weak self] in self?.refreshCheckup(restartInputMonitor: true) }
                return GuidedWorkbenchSurface(
                    view: embeddedView(for: checkupWindow),
                    sizing: .top(NSSize(width: 760, height: 650))
                )
            case 5:
                pawprintsWindow.prepareForEmbeddedDisplay()
                return GuidedWorkbenchSurface(
                    view: embeddedView(for: pawprintsWindow),
                    sizing: .top(NSSize(width: 760, height: 520))
                )
            case 6:
                return GuidedWorkbenchSurface(view: workbenchSupportView, sizing: .fill)
            default:
                return GuidedWorkbenchSurface(view: workbenchAboutView, sizing: .fill)
            }
        }
    }

    private func embeddedView(for controller: NSWindowController) -> NSView {
        let key = ObjectIdentifier(controller)
        if let view = embeddedViews[key] { return view }
        guard let window = controller.window, let view = window.contentView else {
            return NSView()
        }
        let placeholder = NSView(frame: view.frame)
        window.contentView = placeholder
        embeddedViews[key] = view
        return view
    }

    private func canCloseWorkbench() -> Bool {
        let message: String?
        if meetingWindow.preventsWorkbenchClose {
            message = "Stop and transcribe the meeting before closing Kiki."
        } else if voiceStudioWindow.preventsWorkbenchClose {
            message = "Stop the voice recording before closing Kiki."
        } else {
            message = nil
        }
        guard let message else {
            checkupWindow.stopInputMonitor()
            return true
        }
        let alert = NSAlert()
        alert.messageText = "Kiki is still recording"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
        return false
    }

    private func showUnifiedWhatsNewIfNeeded() {
        guard ProcessInfo.processInfo.environment["KIKI_SUPPRESS_WHATS_NEW"] != "1" else { return }
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "New"
        let key = "lastSeenWhatsNewVersion"
        let force = ProcessInfo.processInfo.environment["KIKI_FORCE_WHATS_NEW"] == "1"
        guard force || UserDefaults.standard.string(forKey: key) != version else { return }
        UserDefaults.standard.set(version, forKey: key)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            self?.openWorkbench(section: .settings, subpage: 7)
        }
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
        guard isCheckupVisible else { return }
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
