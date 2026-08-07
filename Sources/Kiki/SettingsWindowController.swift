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
    private let speechProfileDescriptionLabel = kikiLabel("", size: 12.5, color: KikiPalette.secondaryText)
    private let pageHost = NSView()
    private let pageTitleLabel = kikiLabel("General", size: 28, weight: .bold)
    private let pageSubtitleLabel = kikiLabel(
        "Shape how Kiki looks, sounds, and starts.",
        size: 13.5,
        color: KikiPalette.secondaryText
    )
    private var navButtons: [KikiNavButton] = []

    private let pageMetadata: [(title: String, subtitle: String, symbol: String)] = [
        ("General", "Shape how Kiki looks, sounds, and starts.", "slider.horizontal.3"),
        ("Dictation", "Tune the way Kiki listens and keeps up with you.", "waveform"),
        ("Models", "Choose the local engine that fits your voice and workflow.", "cpu"),
        ("Intelligence", "Make Kiki more accurate without slowing down transcription.", "sparkles"),
        ("Privacy", "Control exactly what Kiki remembers—and where it remembers nothing.", "lock.shield"),
    ]

    private let launchAtLoginCheckbox = NSButton(checkboxWithTitle: "Launch Kiki at login", target: nil, action: nil)
    private let automaticUpdatesCheckbox = NSButton(checkboxWithTitle: "Automatically check for signed updates", target: nil, action: nil)
    private let silenceAudioCheckbox = NSButton(checkboxWithTitle: "Mute all Mac audio while recording", target: nil, action: nil)
    private let liveTranscriptionCheckbox = NSButton(checkboxWithTitle: "Show words while I speak", target: nil, action: nil)
    private let caretHUDCheckbox = NSButton(checkboxWithTitle: "Keep the listening window near my cursor", target: nil, action: nil)
    private let zeroWaitCheckbox = NSButton(checkboxWithTitle: "Start another dictation immediately", target: nil, action: nil)
    private let continuationsCheckbox = NSButton(checkboxWithTitle: "Join back-to-back dictations", target: nil, action: nil)
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
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Kiki Settings"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.minSize = NSSize(width: 900, height: 680)
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
        let backdrop = KikiBackdropView()
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        let sidebar = makeSidebar()
        sidebar.translatesAutoresizingMaskIntoConstraints = false

        let headingStack = NSStackView(views: [pageTitleLabel, pageSubtitleLabel])
        headingStack.orientation = .vertical
        headingStack.alignment = .leading
        headingStack.spacing = 5
        headingStack.translatesAutoresizingMaskIntoConstraints = false
        pageHost.translatesAutoresizingMaskIntoConstraints = false

        content.addSubview(backdrop)
        content.addSubview(sidebar)
        content.addSubview(headingStack)
        content.addSubview(pageHost)
        NSLayoutConstraint.activate([
            backdrop.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            backdrop.topAnchor.constraint(equalTo: content.topAnchor),
            backdrop.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            sidebar.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            sidebar.topAnchor.constraint(equalTo: content.topAnchor),
            sidebar.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            sidebar.widthAnchor.constraint(equalToConstant: 220),
            headingStack.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: 34),
            headingStack.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -34),
            headingStack.topAnchor.constraint(equalTo: content.topAnchor, constant: 54),
            pageHost.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: 6),
            pageHost.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            pageHost.topAnchor.constraint(equalTo: headingStack.bottomAnchor, constant: 18),
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

    private func makeSidebar() -> NSView {
        let sidebar = KikiSidebarView()
        let icon = NSImageView()
        icon.imageScaling = .scaleProportionallyUpOrDown
        if let url = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png") {
            icon.image = NSImage(contentsOf: url)
        } else {
            icon.image = NSImage(named: NSImage.applicationIconName)
        }
        icon.wantsLayer = true
        icon.layer?.cornerRadius = 12
        icon.layer?.masksToBounds = true

        let title = kikiLabel("Kiki", size: 21, weight: .bold)
        let subtitle = kikiLabel("VOICE INTELLIGENCE", size: 9.5, weight: .semibold, color: KikiPalette.tertiaryText)
        let labels = NSStackView(views: [title, subtitle])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 2

        let brand = NSStackView(views: [icon, labels])
        brand.orientation = .horizontal
        brand.alignment = .centerY
        brand.spacing = 12

        navButtons = pageMetadata.enumerated().map { index, item in
            let button = KikiNavButton(title: item.title, symbol: item.symbol, target: self, action: #selector(navigationChanged(_:)))
            button.tag = index
            button.isSelectedPage = index == 0
            return button
        }
        let navigation = NSStackView(views: navButtons)
        navigation.orientation = .vertical
        navigation.alignment = .width
        navigation.spacing = 6

        let localDot = NSView()
        localDot.wantsLayer = true
        localDot.layer?.backgroundColor = KikiPalette.success.cgColor
        localDot.layer?.cornerRadius = 4
        let localLabel = kikiLabel("100% local", size: 11.5, weight: .medium, color: KikiPalette.secondaryText)
        let localRow = NSStackView(views: [localDot, localLabel])
        localRow.orientation = .horizontal
        localRow.alignment = .centerY
        localRow.spacing = 8
        let footer = KikiCardView()
        footer.translatesAutoresizingMaskIntoConstraints = false
        footer.addSubview(localRow)
        localRow.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [brand, navigation, NSView(), footer])
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 26
        stack.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(stack)
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 46),
            icon.heightAnchor.constraint(equalToConstant: 46),
            localDot.widthAnchor.constraint(equalToConstant: 8),
            localDot.heightAnchor.constraint(equalToConstant: 8),
            localRow.leadingAnchor.constraint(equalTo: footer.leadingAnchor, constant: 14),
            localRow.trailingAnchor.constraint(lessThanOrEqualTo: footer.trailingAnchor, constant: -14),
            localRow.centerYAnchor.constraint(equalTo: footer.centerYAnchor),
            footer.heightAnchor.constraint(equalToConstant: 45),
            stack.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -18),
            stack.topAnchor.constraint(equalTo: sidebar.topAnchor, constant: 52),
            stack.bottomAnchor.constraint(equalTo: sidebar.bottomAnchor, constant: -22),
        ])
        return sidebar
    }

    private func configureControls() {
        let checkboxes = [
            launchAtLoginCheckbox, automaticUpdatesCheckbox, silenceAudioCheckbox,
            liveTranscriptionCheckbox, caretHUDCheckbox, zeroWaitCheckbox,
            continuationsCheckbox, learningCheckbox, contextCheckbox,
            confidenceCheckbox, historyCheckbox,
        ]
        checkboxes.forEach {
            $0.font = .systemFont(ofSize: 13)
        }

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

        [appearancePopup, accentPopup, soundPopup, modePopup, speechProfilePopup].forEach {
            $0.controlSize = .large
            $0.font = .systemFont(ofSize: 12.5, weight: .medium)
        }

        shortcutButton.target = self
        shortcutButton.action = #selector(beginCapture)
        shortcutButton.bezelStyle = .texturedRounded
        shortcutButton.controlSize = .large
        shortcutButton.font = .monospacedSystemFont(ofSize: 14, weight: .semibold)
        messageLabel.textColor = KikiPalette.secondaryText
        messageLabel.font = .systemFont(ofSize: 12)
        speechProfileDescriptionLabel.maximumNumberOfLines = 0
    }

    private func makeGeneralPage() -> NSView {
        let appearanceRow = labeledRow("Appearance", controls: [appearancePopup])
        let accentRow = labeledRow("Accent color", controls: [accentPopup])
        let soundRow = labeledRow("Dictation sounds", controls: [soundPopup])
        return page(with: [
            SettingsCard(
                title: "Startup & Updates",
                subtitle: "Keep Kiki ready and securely up to date.",
                views: [launchAtLoginCheckbox, automaticUpdatesCheckbox]
            ),
            SettingsCard(
                title: "Look & Sound",
                subtitle: "Choose a calm light or dark workspace that stays easy to read.",
                views: [appearanceRow, accentRow, soundRow]
            ),
        ])
    }

    private func makeDictationPage() -> NSView {
        let reset = KikiActionButton("Restore Default", kind: .secondary, target: self, action: #selector(resetShortcut))
        let shortcutRow = labeledRow("Shortcut", controls: [shortcutButton, reset])
        let behaviorRow = labeledRow("Behavior", controls: [modePopup])
        let profileRow = labeledRow("Transcription style", controls: [speechProfilePopup])
        return page(with: [
            SettingsCard(
                title: "Activation",
                subtitle: "Hold one key or use a toggle for longer thoughts.",
                views: [shortcutRow, behaviorRow, messageLabel]
            ),
            SettingsCard(
                title: "Flow",
                subtitle: "Optional conveniences that never change the speed or accuracy of your final transcription.",
                views: [
                    informativeToggle(
                        zeroWaitCheckbox,
                        title: "Start another dictation immediately",
                        detail: "Starts a fresh recording while the previous clip finishes transcribing. Your first result still pastes normally."
                    ),
                    informativeToggle(
                        continuationsCheckbox,
                        title: "Join back-to-back dictations",
                        detail: "When you dictate again within a few seconds, Kiki joins the thoughts with natural spacing instead of treating them as unrelated."
                    ),
                    informativeToggle(
                        liveTranscriptionCheckbox,
                        title: "Show words while I speak",
                        detail: "Shows partial words in the listening window as you speak. Your final text still comes from the complete local transcription."
                    ),
                    informativeToggle(
                        caretHUDCheckbox,
                        title: "Keep the listening window near my cursor",
                        detail: "Places the listening window beside the insertion point when Kiki can detect it. Otherwise, it appears near the bottom of the screen."
                    ),
                ]
            ),
            SettingsCard(
                title: "Audio",
                subtitle: "Protect microphone quality while Kiki is listening.",
                views: [silenceAudioCheckbox]
            ),
            SettingsCard(
                title: "Speech Style",
                subtitle: "Choose how closely Kiki should follow your spoken words. This changes text after transcription unless you choose Quiet Voice.",
                views: [profileRow, speechProfileDescriptionLabel]
            ),
        ])
    }

    private func makeModelsPage() -> NSView {
        modelCards = TranscriptionModelID.allCases.map { model in
            let card = ModelCardView(model: model)
            card.onUse = { [weak self] model in self?.use(model: model) }
            return card
        }
        let introduction = ModelSectionHeaderView(
            title: "Choose speed, range, or a second opinion.",
            detail: "Parakeet delivers Kiki’s fastest live experience on Apple Silicon. Whisper remains available for compatibility and optional confidence checks."
        )
        return page(with: [introduction] + modelCards)
    }

    private func makeIntelligencePage() -> NSView {
        let manage = KikiActionButton("Open Personalization Studio", kind: .primary, target: self, action: #selector(openPersonalization))
        return page(with: [
            FeatureSpotlightView(
                eyebrow: "PERSONAL, NOT CLOUD",
                title: "A voice model of you—not a profile about you.",
                detail: "Kiki notices the corrections, names, phrases, and rhythms that make your writing yours. Every rule stays on this Mac and remains under your control.",
                symbol: "person.crop.circle.badge.checkmark"
            ),
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
        let manage = KikiActionButton("Manage Private Apps", kind: .secondary, target: self, action: #selector(openPersonalization))
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
        let document = KikiFlippedView()
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
            stack.topAnchor.constraint(equalTo: document.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: document.bottomAnchor, constant: -34),
        ])
        for view in views {
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        return scroll
    }

    private func labeledRow(_ title: String, controls: [NSView]) -> NSView {
        let label = kikiLabel(title, size: 13, weight: .medium, color: KikiPalette.secondaryText)
        label.setContentHuggingPriority(.required, for: .horizontal)
        let spacer = NSView()
        let row = NSStackView(views: [label, spacer] + controls)
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        return row
    }

    private func secondaryLabel(_ text: String) -> NSTextField {
        kikiLabel(text, size: 13, color: KikiPalette.secondaryText)
    }

    private func informativeToggle(_ checkbox: NSButton, title: String, detail: String) -> NSView {
        let info = KikiInfoButton(title: title, detail: detail)
        let row = NSStackView(views: [checkbox, info])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 6
        checkbox.setContentHuggingPriority(.required, for: .horizontal)
        return row
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
        speechProfileDescriptionLabel.stringValue = Settings.speechProfile.detail
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

    @objc private func navigationChanged(_ sender: KikiNavButton) {
        showPage(index: sender.tag)
    }

    private func showPage(index: Int) {
        pageHost.subviews.forEach { $0.removeFromSuperview() }
        guard pages.indices.contains(index), pageMetadata.indices.contains(index) else { return }
        pageTitleLabel.stringValue = pageMetadata[index].title
        pageSubtitleLabel.stringValue = pageMetadata[index].subtitle
        navButtons.enumerated().forEach { $0.element.isSelectedPage = $0.offset == index }
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
private final class SettingsCard: KikiCardView {
    init(title: String, subtitle: String, views: [NSView]) {
        super.init(frame: .zero)

        let titleLabel = kikiLabel(title, size: 16.5, weight: .semibold)
        let subtitleLabel = kikiLabel(subtitle, size: 12.5, color: KikiPalette.secondaryText)
        let stack = NSStackView(views: [titleLabel, subtitleLabel] + views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 22),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -22),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -20),
            subtitleLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
        for view in views { view.widthAnchor.constraint(lessThanOrEqualTo: stack.widthAnchor).isActive = true }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

@MainActor
private final class ModelCardView: KikiCardView {
    let model: TranscriptionModelID
    var onUse: ((TranscriptionModelID) -> Void)?
    private let statusLabel = NSTextField(labelWithString: "")
    private let button = KikiActionButton("Use Model", kind: .primary, target: nil, action: nil)

    init(model: TranscriptionModelID) {
        self.model = model
        super.init(frame: .zero)

        let symbolName = model.isParakeet ? "bolt.horizontal.circle.fill" : "waveform.circle.fill"
        let symbol = NSImageView(image: NSImage(systemSymbolName: symbolName, accessibilityDescription: model.displayName) ?? NSImage())
        symbol.contentTintColor = model.isParakeet ? KikiPalette.cyan : KikiPalette.violet
        let symbolShell = KikiCardView()
        symbolShell.selected = true
        symbolShell.addSubview(symbol)
        symbol.translatesAutoresizingMaskIntoConstraints = false

        let title = kikiLabel(model.displayName, size: 16.5, weight: .semibold)
        let detail = kikiLabel(model.detail, size: 12.5, color: KikiPalette.secondaryText)
        statusLabel.font = .systemFont(ofSize: 12, weight: .medium)
        button.target = self
        button.action = #selector(useModel)

        let labels = NSStackView(views: [title, detail, statusLabel])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 5
        let row = NSStackView(views: [symbolShell, labels, NSView(), button])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 18
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            row.topAnchor.constraint(equalTo: topAnchor, constant: 18),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -18),
            symbolShell.widthAnchor.constraint(equalToConstant: 48),
            symbolShell.heightAnchor.constraint(equalToConstant: 48),
            symbol.widthAnchor.constraint(equalToConstant: 23),
            symbol.heightAnchor.constraint(equalToConstant: 23),
            symbol.centerXAnchor.constraint(equalTo: symbolShell.centerXAnchor),
            symbol.centerYAnchor.constraint(equalTo: symbolShell.centerYAnchor),
            detail.widthAnchor.constraint(lessThanOrEqualToConstant: 460),
        ])
        refresh()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func refresh() {
        let selected = Settings.transcriptionModel == model
        self.selected = selected
        let installed = model.isParakeet || ModelStore.isWhisperModelInstalled(model)
        if !model.isCompatible {
            statusLabel.stringValue = "Unavailable on this Mac"
            statusLabel.textColor = KikiPalette.tertiaryText
            button.title = "Unavailable"
            button.isEnabled = false
        } else if selected {
            statusLabel.stringValue = "● Currently in use"
            statusLabel.textColor = KikiPalette.cyan
            button.title = "Using"
            button.isEnabled = false
        } else {
            statusLabel.stringValue = installed ? "Installed" : "Downloads when selected"
            statusLabel.textColor = KikiPalette.secondaryText
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

@MainActor
private final class ModelSectionHeaderView: NSView {
    init(title: String, detail: String) {
        super.init(frame: .zero)
        let eyebrow = kikiLabel("LOCAL MODELS", size: 10, weight: .bold, color: KikiPalette.cyan)
        let titleLabel = kikiLabel(title, size: 19, weight: .semibold)
        let detailLabel = kikiLabel(detail, size: 13, color: KikiPalette.secondaryText)
        detailLabel.maximumNumberOfLines = 0
        let stack = NSStackView(views: [eyebrow, titleLabel, detailLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            detailLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

@MainActor
private final class FeatureSpotlightView: NSView {
    init(eyebrow: String, title: String, detail: String, symbol: String) {
        super.init(frame: .zero)

        let icon = NSImageView(image: NSImage(systemSymbolName: symbol, accessibilityDescription: title) ?? NSImage())
        icon.contentTintColor = KikiPalette.cyan

        let eyebrowLabel = kikiLabel(eyebrow, size: 10, weight: .bold, color: KikiPalette.cyan)
        let titleLabel = kikiLabel(title, size: 20, weight: .semibold)
        let detailLabel = kikiLabel(detail, size: 13, color: KikiPalette.secondaryText)
        let labels = NSStackView(views: [eyebrowLabel, titleLabel, detailLabel])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 6
        let row = NSStackView(views: [icon, labels])
        row.orientation = .horizontal
        row.alignment = .top
        row.spacing = 14
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 2),
            row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -2),
            row.topAnchor.constraint(equalTo: topAnchor, constant: 6),
            row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            icon.widthAnchor.constraint(equalToConstant: 28),
            icon.heightAnchor.constraint(equalToConstant: 28),
            detailLabel.widthAnchor.constraint(equalTo: labels.widthAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
