import AppKit

@MainActor
final class SettingsWindowController: NSWindowController {
    var onSettingsChange: (@MainActor (DictationShortcut, ActivationMode) -> Void)?
    var onModelChange: (@MainActor (TranscriptionModelID) -> Void)?
    var onAppearanceChange: (@MainActor () -> Void)?
    var onAutomaticUpdatesChange: (@MainActor (Bool) -> Void)?
    var onOpenPersonalization: (@MainActor () -> Void)?

    private let shortcutButton = NSButton(title: "", target: nil, action: nil)
    private let modePopup = NSPopUpButton()
    private let speechProfilePopup = NSPopUpButton()
    private let appearancePopup = NSPopUpButton()
    private let accentPopup = NSPopUpButton()
    private let soundPopup = NSPopUpButton()
    private let messageLabel = NSTextField(labelWithString: "")
    private let pageControl = NSSegmentedControl(
        labels: ["General", "Dictation", "Models", "Intelligence", "Privacy"],
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )
    private let pageHost = NSView()

    private let launchAtLoginCheckbox = NSButton(checkboxWithTitle: "Launch Kiki at login", target: nil, action: nil)
    private let automaticUpdatesCheckbox = NSButton(checkboxWithTitle: "Automatically check for signed updates", target: nil, action: nil)
    private let silenceAudioCheckbox = NSButton(checkboxWithTitle: "Mute all Mac audio while recording", target: nil, action: nil)
    private let liveTranscriptionCheckbox = NSButton(checkboxWithTitle: "Show live transcription while speaking", target: nil, action: nil)
    private let caretHUDCheckbox = NSButton(checkboxWithTitle: "Place the listening window beside the text cursor", target: nil, action: nil)
    private let zeroWaitCheckbox = NSButton(checkboxWithTitle: "Let me begin another dictation immediately", target: nil, action: nil)
    private let continuationsCheckbox = NSButton(checkboxWithTitle: "Join quick successive dictations naturally", target: nil, action: nil)
    private let learningCheckbox = NSButton(checkboxWithTitle: "Notice corrections and suggest what Kiki should learn", target: nil, action: nil)
    private let contextCheckbox = NSButton(checkboxWithTitle: "Use approved Contacts, Calendar, and project vocabulary", target: nil, action: nil)
    private let confidenceCheckbox = NSButton(checkboxWithTitle: "Audit results with a background Whisper model", target: nil, action: nil)
    private let historyCheckbox = NSButton(checkboxWithTitle: "Save text-only transcription history", target: nil, action: nil)

    private var pages: [NSView] = []
    private var modelCards: [ModelCardView] = []
    private var captureMonitor: Any?
    private var pendingModifierKeyCode: UInt16?
    private var pendingModifierFlags: NSEvent.ModifierFlags = []

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Kiki Settings"
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        window.minSize = NSSize(width: 720, height: 640)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildContent()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show() {
        refresh()
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildContent() {
        guard let content = window?.contentView else { return }
        content.wantsLayer = true

        let header = makeHeader()
        pageControl.target = self
        pageControl.action = #selector(pageChanged)
        pageControl.selectedSegment = 0
        pageControl.controlSize = .large
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        pageHost.translatesAutoresizingMaskIntoConstraints = false

        content.addSubview(header)
        content.addSubview(pageControl)
        content.addSubview(pageHost)
        NSLayoutConstraint.activate([
            header.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            header.topAnchor.constraint(equalTo: content.topAnchor),
            header.heightAnchor.constraint(equalToConstant: 126),
            pageControl.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 16),
            pageControl.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            pageHost.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            pageHost.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            pageHost.topAnchor.constraint(equalTo: pageControl.bottomAnchor, constant: 12),
            pageHost.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])

        configureControls()
        pages = [
            makeGeneralPage(),
            makeDictationPage(),
            makeModelsPage(),
            makeIntelligencePage(),
            makePrivacyPage(),
        ]
        showPage(index: 0)
        refresh()
    }

    private func makeHeader() -> NSView {
        let effect = NSVisualEffectView()
        effect.material = .sidebar
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.translatesAutoresizingMaskIntoConstraints = false

        let icon = NSImageView()
        icon.imageScaling = .scaleProportionallyUpOrDown
        if let url = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png") {
            icon.image = NSImage(contentsOf: url)
        } else {
            icon.image = NSImage(named: NSImage.applicationIconName)
        }
        icon.wantsLayer = true
        icon.layer?.cornerRadius = 16
        icon.layer?.masksToBounds = true

        let title = NSTextField(labelWithString: "Kiki")
        title.font = .systemFont(ofSize: 30, weight: .bold)
        let subtitle = NSTextField(labelWithString: "Fast, private dictation that learns how you communicate.")
        subtitle.font = .systemFont(ofSize: 14, weight: .regular)
        subtitle.textColor = .secondaryLabelColor
        let labels = NSStackView(views: [title, subtitle])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 4

        let row = NSStackView(views: [icon, labels])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 18
        row.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(row)
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 64),
            icon.heightAnchor.constraint(equalToConstant: 64),
            row.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 32),
            row.trailingAnchor.constraint(lessThanOrEqualTo: effect.trailingAnchor, constant: -32),
            row.bottomAnchor.constraint(equalTo: effect.bottomAnchor, constant: -18),
        ])
        return effect
    }

    private func configureControls() {
        launchAtLoginCheckbox.target = self
        launchAtLoginCheckbox.action = #selector(launchAtLoginChanged)
        automaticUpdatesCheckbox.target = self
        automaticUpdatesCheckbox.action = #selector(automaticUpdatesChanged)
        silenceAudioCheckbox.target = self
        silenceAudioCheckbox.action = #selector(silenceAudioChanged)
        liveTranscriptionCheckbox.target = self
        liveTranscriptionCheckbox.action = #selector(liveTranscriptionChanged)
        caretHUDCheckbox.target = self
        caretHUDCheckbox.action = #selector(caretHUDChanged)
        zeroWaitCheckbox.target = self
        zeroWaitCheckbox.action = #selector(zeroWaitChanged)
        continuationsCheckbox.target = self
        continuationsCheckbox.action = #selector(continuationsChanged)
        learningCheckbox.target = self
        learningCheckbox.action = #selector(learningChanged)
        contextCheckbox.target = self
        contextCheckbox.action = #selector(contextChanged)
        confidenceCheckbox.target = self
        confidenceCheckbox.action = #selector(confidenceChanged)
        historyCheckbox.target = self
        historyCheckbox.action = #selector(historyChanged)

        appearancePopup.addItems(withTitles: AppAppearanceMode.allCases.map(\.title))
        appearancePopup.target = self
        appearancePopup.action = #selector(appearanceChanged)
        accentPopup.addItems(withTitles: KikiAccentColor.allCases.map(\.title))
        accentPopup.target = self
        accentPopup.action = #selector(accentChanged)
        soundPopup.addItems(withTitles: DictationSoundStyle.allCases.map(\.title))
        soundPopup.target = self
        soundPopup.action = #selector(soundChanged)
        modePopup.addItems(withTitles: ActivationMode.allCases.map(\.title))
        modePopup.target = self
        modePopup.action = #selector(modeChanged)
        speechProfilePopup.addItems(withTitles: SpeechProfile.allCases.map(\.title))
        speechProfilePopup.target = self
        speechProfilePopup.action = #selector(speechProfileChanged)

        shortcutButton.target = self
        shortcutButton.action = #selector(beginCapture)
        shortcutButton.bezelStyle = .rounded
        shortcutButton.font = .monospacedSystemFont(ofSize: 14, weight: .semibold)
        messageLabel.textColor = .secondaryLabelColor
        messageLabel.font = .systemFont(ofSize: 12)
    }

    private func makeGeneralPage() -> NSView {
        let appearanceRow = labeledRow("Appearance", controls: [appearancePopup, accentPopup])
        let soundRow = labeledRow("Dictation sounds", controls: [soundPopup])
        return page(with: [
            SettingsCard(
                title: "Startup & Updates",
                subtitle: "Keep Kiki ready and securely up to date.",
                views: [launchAtLoginCheckbox, automaticUpdatesCheckbox]
            ),
            SettingsCard(
                title: "Look & Sound",
                subtitle: "Make the listening experience feel at home on your Mac.",
                views: [appearanceRow, soundRow]
            ),
        ])
    }

    private func makeDictationPage() -> NSView {
        let reset = NSButton(title: "Restore Default", target: self, action: #selector(resetShortcut))
        let shortcutRow = labeledRow("Shortcut", controls: [shortcutButton, reset])
        let behaviorRow = labeledRow("Behavior", controls: [modePopup])
        let profileRow = labeledRow("Speech profile", controls: [speechProfilePopup])
        return page(with: [
            SettingsCard(
                title: "Activation",
                subtitle: "Hold one key or use a toggle for longer thoughts.",
                views: [shortcutRow, behaviorRow, messageLabel]
            ),
            SettingsCard(
                title: "Flow",
                subtitle: "These features work around transcription, never in front of it.",
                views: [zeroWaitCheckbox, continuationsCheckbox, liveTranscriptionCheckbox, caretHUDCheckbox]
            ),
            SettingsCard(
                title: "Audio & Accessibility",
                subtitle: "Protect microphone quality and adapt Kiki to the way you speak.",
                views: [silenceAudioCheckbox, profileRow, secondaryLabel(Settings.speechProfile.detail)]
            ),
        ])
    }

    private func makeModelsPage() -> NSView {
        modelCards = TranscriptionModelID.allCases.map { model in
            let card = ModelCardView(model: model)
            card.onUse = { [weak self] model in self?.use(model: model) }
            return card
        }
        let intro = secondaryLabel("Pick by capability—there is no hidden menu. Parakeet delivers the fastest live experience on Apple Silicon; Whisper remains available for compatibility and verification.")
        return page(with: [intro] + modelCards)
    }

    private func makeIntelligencePage() -> NSView {
        let manage = NSButton(title: "Open Personalization Studio…", target: self, action: #selector(openPersonalization))
        manage.bezelStyle = .rounded
        manage.controlSize = .large
        return page(with: [
            SettingsCard(
                title: "Kiki Learns You",
                subtitle: "Everything stays on this Mac. Suggestions require your approval before becoming permanent.",
                views: [learningCheckbox, contextCheckbox, manage]
            ),
            SettingsCard(
                title: "Confidence Shadow",
                subtitle: "The primary result still pastes immediately. If an installed Whisper model strongly disagrees, Kiki saves a private review for later.",
                views: [confidenceCheckbox]
            ),
        ])
    }

    private func makePrivacyPage() -> NSView {
        let manage = NSButton(title: "Manage Private Apps…", target: self, action: #selector(openPersonalization))
        return page(with: [
            SettingsCard(
                title: "Local History",
                subtitle: "Kiki stores text only. Microphone audio is never added to dictation history.",
                views: [historyCheckbox]
            ),
            SettingsCard(
                title: "Private Zones",
                subtitle: "Secure text fields are always private. Add apps where Kiki should also skip history, learning, and background verification.",
                views: [manage]
            ),
        ])
    }

    private func page(with views: [NSView]) -> NSView {
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        let document = NSView()
        document.translatesAutoresizingMaskIntoConstraints = false
        document.addSubview(stack)
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.documentView = document
        scroll.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            document.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor),
            stack.leadingAnchor.constraint(equalTo: document.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: document.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: document.topAnchor, constant: 14),
            stack.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -28),
        ])
        for view in views {
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        return scroll
    }

    private func labeledRow(_ title: String, controls: [NSView]) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.setContentHuggingPriority(.required, for: .horizontal)
        let spacer = NSView()
        let row = NSStackView(views: [label, spacer] + controls)
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        return row
    }

    private func secondaryLabel(_ text: String) -> NSTextField {
        let label = NSTextField(wrappingLabelWithString: text)
        label.textColor = .secondaryLabelColor
        label.font = .systemFont(ofSize: 13)
        return label
    }

    private func refresh() {
        shortcutButton.title = Settings.dictationShortcut.displayString
        launchAtLoginCheckbox.state = LaunchAtLoginController.isEnabled ? .on : .off
        automaticUpdatesCheckbox.state = UserDefaults.standard.object(forKey: "SUEnableAutomaticChecks") == nil
            || UserDefaults.standard.bool(forKey: "SUEnableAutomaticChecks") ? .on : .off
        appearancePopup.selectItem(at: AppAppearanceMode.allCases.firstIndex(of: Settings.appearanceMode) ?? 0)
        accentPopup.selectItem(at: KikiAccentColor.allCases.firstIndex(of: Settings.accentColor) ?? 0)
        soundPopup.selectItem(at: DictationSoundStyle.allCases.firstIndex(of: Settings.soundStyle) ?? 0)
        modePopup.selectItem(at: ActivationMode.allCases.firstIndex(of: Settings.activationMode) ?? 0)
        speechProfilePopup.selectItem(at: SpeechProfile.allCases.firstIndex(of: Settings.speechProfile) ?? 0)
        silenceAudioCheckbox.state = Settings.silenceSystemAudioWhileRecording ? .on : .off
        liveTranscriptionCheckbox.state = Settings.showLiveTranscription ? .on : .off
        caretHUDCheckbox.state = Settings.showHUDNearCaret ? .on : .off
        zeroWaitCheckbox.state = Settings.enableZeroWaitChaining ? .on : .off
        continuationsCheckbox.state = Settings.enableVoiceContinuations ? .on : .off
        learningCheckbox.state = Settings.learnFromCorrections ? .on : .off
        contextCheckbox.state = Settings.useContextVocabulary ? .on : .off
        confidenceCheckbox.state = Settings.enableConfidenceVerification ? .on : .off
        historyCheckbox.state = Settings.saveTranscriptionHistory ? .on : .off
        modelCards.forEach { $0.refresh() }
    }

    @objc private func pageChanged() { showPage(index: pageControl.selectedSegment) }

    private func showPage(index: Int) {
        pageHost.subviews.forEach { $0.removeFromSuperview() }
        guard pages.indices.contains(index) else { return }
        let page = pages[index]
        pageHost.addSubview(page)
        page.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            page.leadingAnchor.constraint(equalTo: pageHost.leadingAnchor),
            page.trailingAnchor.constraint(equalTo: pageHost.trailingAnchor),
            page.topAnchor.constraint(equalTo: pageHost.topAnchor),
            page.bottomAnchor.constraint(equalTo: pageHost.bottomAnchor),
        ])
    }

    @objc private func beginCapture() {
        stopCapture()
        pendingModifierKeyCode = nil
        pendingModifierFlags = []
        shortcutButton.title = "Press shortcut…"
        messageLabel.stringValue = "Press a modifier alone, or a modifier plus another key. Escape cancels."
        captureMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            self?.capture(event) ?? event
        }
    }

    private func capture(_ event: NSEvent) -> NSEvent? {
        let relevant = event.modifierFlags.intersection([.command, .option, .control, .shift, .function])
        if event.type == .keyDown {
            if event.keyCode == 53 { stopCapture(); refresh(); messageLabel.stringValue = ""; return nil }
            guard !relevant.isEmpty else { messageLabel.stringValue = "Use a modifier key or modified shortcut."; return nil }
            save(DictationShortcut(keyCode: event.keyCode, modifiersRawValue: relevant.rawValue))
            return nil
        }
        guard event.type == .flagsChanged,
              let flag = DictationShortcut.modifierFlag(for: event.keyCode)
        else { return nil }
        if relevant.contains(flag) {
            pendingModifierKeyCode = event.keyCode
            pendingModifierFlags = relevant
        } else if let keyCode = pendingModifierKeyCode {
            save(DictationShortcut(keyCode: keyCode, modifiersRawValue: pendingModifierFlags.rawValue))
        }
        return nil
    }

    private func save(_ shortcut: DictationShortcut) {
        Settings.dictationShortcut = shortcut
        stopCapture()
        refresh()
        messageLabel.stringValue = "Shortcut updated."
        onSettingsChange?(shortcut, Settings.activationMode)
    }

    private func stopCapture() {
        if let captureMonitor { NSEvent.removeMonitor(captureMonitor) }
        captureMonitor = nil
    }

    private func use(model: TranscriptionModelID) {
        guard model.isCompatible else { return }
        modelCards.forEach { $0.setBusy($0.model == model) }
        if model.isParakeet || ModelStore.isWhisperModelInstalled(model) {
            onModelChange?(model)
            modelCards.forEach { $0.refresh() }
            return
        }
        Task { [weak self] in
            do {
                try await ModelDownloadService.downloadWhisperModel(model)
                await MainActor.run {
                    self?.onModelChange?(model)
                    self?.modelCards.forEach { $0.refresh() }
                }
            } catch {
                await MainActor.run {
                    self?.modelCards.first(where: { $0.model == model })?.showError(error.localizedDescription)
                }
            }
        }
    }

    @objc private func resetShortcut() { save(.rightOption) }
    @objc private func modeChanged() {
        Settings.activationMode = ActivationMode.allCases[modePopup.indexOfSelectedItem]
        onSettingsChange?(Settings.dictationShortcut, Settings.activationMode)
    }
    @objc private func speechProfileChanged() {
        Settings.speechProfile = SpeechProfile.allCases[speechProfilePopup.indexOfSelectedItem]
        refresh()
    }
    @objc private func launchAtLoginChanged() {
        do {
            try LaunchAtLoginController.setEnabled(launchAtLoginCheckbox.state == .on)
        } catch {
            messageLabel.stringValue = "Could not change login setting: \(error.localizedDescription)"
            launchAtLoginCheckbox.state = LaunchAtLoginController.isEnabled ? .on : .off
        }
    }
    @objc private func automaticUpdatesChanged() { onAutomaticUpdatesChange?(automaticUpdatesCheckbox.state == .on) }
    @objc private func appearanceChanged() { Settings.appearanceMode = AppAppearanceMode.allCases[appearancePopup.indexOfSelectedItem]; onAppearanceChange?() }
    @objc private func accentChanged() { Settings.accentColor = KikiAccentColor.allCases[accentPopup.indexOfSelectedItem]; onAppearanceChange?() }
    @objc private func soundChanged() { Settings.soundStyle = DictationSoundStyle.allCases[soundPopup.indexOfSelectedItem] }
    @objc private func silenceAudioChanged() { Settings.silenceSystemAudioWhileRecording = silenceAudioCheckbox.state == .on }
    @objc private func liveTranscriptionChanged() { Settings.showLiveTranscription = liveTranscriptionCheckbox.state == .on }
    @objc private func caretHUDChanged() { Settings.showHUDNearCaret = caretHUDCheckbox.state == .on }
    @objc private func zeroWaitChanged() { Settings.enableZeroWaitChaining = zeroWaitCheckbox.state == .on; onSettingsChange?(Settings.dictationShortcut, Settings.activationMode) }
    @objc private func continuationsChanged() { Settings.enableVoiceContinuations = continuationsCheckbox.state == .on }
    @objc private func learningChanged() { Settings.learnFromCorrections = learningCheckbox.state == .on }
    @objc private func contextChanged() { Settings.useContextVocabulary = contextCheckbox.state == .on }
    @objc private func confidenceChanged() { Settings.enableConfidenceVerification = confidenceCheckbox.state == .on }
    @objc private func historyChanged() { Settings.saveTranscriptionHistory = historyCheckbox.state == .on }
    @objc private func openPersonalization() { onOpenPersonalization?() }
}
@MainActor
private final class SettingsCard: NSView {
    init(title: String, subtitle: String, views: [NSView]) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.65).cgColor
        layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.72).cgColor

        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        let subtitleLabel = NSTextField(wrappingLabelWithString: subtitle)
        subtitleLabel.font = .systemFont(ofSize: 12.5)
        subtitleLabel.textColor = .secondaryLabelColor
        let stack = NSStackView(views: [titleLabel, subtitleLabel] + views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -18),
            subtitleLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
        for view in views { view.widthAnchor.constraint(lessThanOrEqualTo: stack.widthAnchor).isActive = true }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

@MainActor
private final class ModelCardView: NSView {
    let model: TranscriptionModelID
    var onUse: ((TranscriptionModelID) -> Void)?
    private let statusLabel = NSTextField(labelWithString: "")
    private let button = NSButton(title: "Use Model", target: nil, action: nil)

    init(model: TranscriptionModelID) {
        self.model = model
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.65).cgColor
        layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.72).cgColor

        let title = NSTextField(labelWithString: model.displayName)
        title.font = .systemFont(ofSize: 16, weight: .semibold)
        let detail = NSTextField(wrappingLabelWithString: model.detail)
        detail.font = .systemFont(ofSize: 13)
        detail.textColor = .secondaryLabelColor
        statusLabel.font = .systemFont(ofSize: 12, weight: .medium)
        button.target = self
        button.action = #selector(useModel)
        button.bezelStyle = .rounded
        button.controlSize = .large

        let labels = NSStackView(views: [title, detail, statusLabel])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 5
        let row = NSStackView(views: [labels, NSView(), button])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 18
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            row.topAnchor.constraint(equalTo: topAnchor, constant: 17),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -17),
            detail.widthAnchor.constraint(lessThanOrEqualToConstant: 520),
        ])
        refresh()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func refresh() {
        let selected = Settings.transcriptionModel == model
        let installed = model.isParakeet || ModelStore.isWhisperModelInstalled(model)
        if !model.isCompatible {
            statusLabel.stringValue = "Unavailable on this Mac"
            statusLabel.textColor = .tertiaryLabelColor
            button.title = "Unavailable"
            button.isEnabled = false
        } else if selected {
            statusLabel.stringValue = "● Currently in use"
            statusLabel.textColor = Settings.accentColor.color
            button.title = "Using"
            button.isEnabled = false
        } else {
            statusLabel.stringValue = installed ? "Installed" : "Downloads when selected"
            statusLabel.textColor = .secondaryLabelColor
            button.title = installed ? "Use Model" : "Download & Use"
            button.isEnabled = true
        }
    }

    func setBusy(_ busy: Bool) {
        guard busy else { return }
        statusLabel.stringValue = model.isParakeet ? "Loading local model…" : "Downloading model…"
        button.title = "Please Wait…"
        button.isEnabled = false
    }

    func showError(_ message: String) {
        statusLabel.stringValue = "Could not use model: \(message)"
        statusLabel.textColor = .systemRed
        button.title = "Try Again"
        button.isEnabled = true
    }

    @objc private func useModel() { onUse?(model) }
}
