import AppKit

@MainActor
final class GuidedWorkbenchHomeView: NSView {
    var onStartDictation: (() -> Void)?
    var onOpenMeeting: (() -> Void)?
    var onOpenVoiceStudio: (() -> Void)?
    var onOpenAudioFile: (() -> Void)?
    var onOpenCheckup: (() -> Void)?
    var onOpenModels: (() -> Void)?
    private weak var heroArtworkView: KikiDecorativeImageView?
    private let homeTitleLabel = kikiLabel("Your voice, ready to work.", size: 31, weight: .bold)
    private let shortcutHelpLabel = kikiLabel("", size: 11.5, color: KikiPalette.secondaryText)
    private let readinessDetailLabel = kikiLabel("Only unfinished checks appear here.", size: 12, color: KikiPalette.secondaryText)
    private let readinessCard = KikiCardView()
    private let microphoneReadinessRow = GuidedWorkbenchReadinessRow(title: "Microphone", identifier: "microphone")
    private let accessibilityReadinessRow = GuidedWorkbenchReadinessRow(title: "Accessibility", identifier: "accessibility")
    private let modelReadinessRow = GuidedWorkbenchReadinessRow(title: "Local model", identifier: "model")
    private let shortcutReadinessRow = GuidedWorkbenchReadinessRow(title: "Dictation shortcut", identifier: "shortcut")
    private let firstDictationReadinessRow = GuidedWorkbenchReadinessRow(title: "First dictation", identifier: "first-dictation")
    private lazy var dictationCapability = GuidedWorkbenchCapabilityCard(
        symbol: "waveform",
        title: "Dictate anywhere",
        detail: "Speak into any Mac app. Kiki transcribes and inserts your words locally.",
        actionTitle: "Try Dictation",
        buttonKind: .primary,
        identifier: "dictation",
        target: self,
        action: #selector(startDictation)
    )
    private lazy var meetingCapability = GuidedWorkbenchCapabilityCard(
        symbol: "person.2.wave.2",
        title: "Capture a meeting",
        detail: "Record microphone and Mac audio, then review, edit, and export the result.",
        actionTitle: "Capture Meeting",
        identifier: "meeting",
        target: self,
        action: #selector(openMeeting)
    )
    private lazy var audioCapability = GuidedWorkbenchCapabilityCard(
        symbol: "waveform.badge.plus",
        title: "Transcribe a recording",
        detail: "Open an audio file, refine its local transcript, and export clean text.",
        actionTitle: "Transcribe Audio",
        identifier: "audio",
        target: self,
        action: #selector(openAudioFile)
    )
    private lazy var voiceCapability = GuidedWorkbenchCapabilityCard(
        symbol: "waveform.badge.mic",
        title: "Create in your voice",
        detail: "Record a private voice sample and turn written text into speech on this Mac.",
        actionTitle: "Open Voice Studio",
        identifier: "voice",
        target: self,
        action: #selector(openVoiceStudio)
    )
    private var wideHeroConstraints: [NSLayoutConstraint] = []
    private var compactHeroConstraint: NSLayoutConstraint?
    private var usesCompactHero: Bool?

    init() {
        super.init(frame: .zero)
        buildContent()
        microphoneReadinessRow.onActivate = { [weak self] in self?.onOpenCheckup?() }
        accessibilityReadinessRow.onActivate = { [weak self] in self?.onOpenCheckup?() }
        modelReadinessRow.onActivate = { [weak self] in self?.onOpenModels?() }
        shortcutReadinessRow.onActivate = { [weak self] in self?.onOpenCheckup?() }
        firstDictationReadinessRow.onActivate = { [weak self] in self?.onStartDictation?() }
        update(snapshot: KikiCheckupSnapshot(
            microphoneAuthorized: false,
            inputResponding: false,
            accessibilityAuthorized: false,
            modelStatus: .unavailable(model: Settings.transcriptionModel),
            shortcutVerified: false,
            firstDictationCompleted: false
        ))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func setFrameSize(_ newSize: NSSize) {
        // Switch constraints from the proposed width, before AppKit resolves the
        // current wide layout back into the window's minimum fitting width.
        if !wideHeroConstraints.isEmpty {
            updateHeroLayout(compact: newSize.width < 940)
        }
        super.setFrameSize(newSize)
    }

    func prepareForAvailableWidth(_ width: CGFloat) {
        updateHeroLayout(compact: width < 940)
    }

    func update(snapshot: KikiCheckupSnapshot) {
        shortcutHelpLabel.stringValue = "In any text field: \(Settings.activationMode.configuredInstruction(for: Settings.dictationShortcut))"
        readinessCard.isHidden = snapshot.isReady

        let microphoneReady = snapshot.microphoneAuthorized && snapshot.inputResponding
        microphoneReadinessRow.isHidden = microphoneReady
        accessibilityReadinessRow.isHidden = snapshot.accessibilityAuthorized
        modelReadinessRow.isHidden = snapshot.modelStatus.isReady
        shortcutReadinessRow.isHidden = snapshot.shortcutVerified
        firstDictationReadinessRow.isHidden = snapshot.firstDictationCompleted

        dictationCapability.updateStatus(
            snapshot.isReady ? "Ready · \(Settings.dictationShortcut.displayString)" : "Checkup incomplete",
            ready: snapshot.isReady
        )
        meetingCapability.updateStatus(
            microphoneReady ? "Microphone ready" : "Microphone setup needed",
            ready: microphoneReady
        )
        audioCapability.updateStatus(
            snapshot.modelStatus.isReady ? "Local model ready" : "Choose a local model",
            ready: snapshot.modelStatus.isReady
        )
        voiceCapability.updateStatus("Private and fully local", ready: true)

        microphoneReadinessRow.update(
            passed: microphoneReady,
            value: !snapshot.microphoneAuthorized
                ? "Permission needed"
                : snapshot.inputResponding ? "Ready" : "Test input",
            actionTitle: snapshot.microphoneAuthorized ? "Test" : "Fix"
        )
        accessibilityReadinessRow.update(
            passed: snapshot.accessibilityAuthorized,
            value: snapshot.accessibilityAuthorized ? "Ready" : "Permission needed",
            actionTitle: "Fix"
        )
        modelReadinessRow.update(
            passed: snapshot.modelStatus.isReady,
            value: snapshot.modelStatus.isReady ? "Ready" : snapshot.modelStatus.checkupDetail,
            actionTitle: "Models"
        )
        shortcutReadinessRow.update(
            passed: snapshot.shortcutVerified,
            value: snapshot.shortcutVerified ? Settings.dictationShortcut.displayString : "Needs test",
            actionTitle: "Test"
        )
        firstDictationReadinessRow.update(
            passed: snapshot.firstDictationCompleted,
            value: snapshot.firstDictationCompleted ? "Completed" : "Not completed",
            actionTitle: "Try",
            showsAction: false
        )
    }

    override func layout() {
        updateHeroLayout(compact: bounds.width < 940)
        super.layout()
    }

    private func buildContent() {
        let backdrop = KikiBackdropView()
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        addSubview(backdrop)

        let eyebrow = kikiLabel("KIKI · FULLY LOCAL", size: 10, weight: .bold, color: KikiPalette.accentText)
        homeTitleLabel.identifier = NSUserInterfaceItemIdentifier("kiki.workbench.home.title")
        shortcutHelpLabel.identifier = NSUserInterfaceItemIdentifier("kiki.workbench.home.shortcut-help")
        shortcutHelpLabel.maximumNumberOfLines = 0
        let intro = kikiLabel("Choose a workflow. Kiki keeps your voice, recordings, and words on this Mac.", size: 14, color: KikiPalette.secondaryText)
        intro.maximumNumberOfLines = 0
        let copy = NSStackView(views: [eyebrow, homeTitleLabel, intro, shortcutHelpLabel])
        copy.orientation = .vertical
        copy.alignment = .leading
        copy.spacing = 7

        let heroArtwork = KikiDecorativeImageView()
        if let url = Bundle.main.url(forResource: "VoiceStudioHero", withExtension: "png") {
            heroArtwork.image = NSImage(contentsOf: url)
        }
        heroArtwork.imageScaling = .scaleProportionallyUpOrDown
        // The source artwork is intentionally high resolution. Its intrinsic pixel
        // width must never become the minimum width of the application window.
        heroArtwork.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        heroArtwork.setContentHuggingPriority(.defaultLow, for: .horizontal)
        heroArtwork.identifier = NSUserInterfaceItemIdentifier("kiki.workbench.home.hero")
        heroArtworkView = heroArtwork

        let hero = KikiCardView()
        hero.layer?.masksToBounds = true
        copy.translatesAutoresizingMaskIntoConstraints = false
        heroArtwork.translatesAutoresizingMaskIntoConstraints = false
        hero.addSubview(copy)
        hero.addSubview(heroArtwork)
        let wideCopyConstraint = copy.trailingAnchor.constraint(lessThanOrEqualTo: hero.centerXAnchor, constant: -10)
        // This is a presentation preference, not a minimum window width. AppKit
        // must be free to break it while transitioning into the compact layout.
        wideCopyConstraint.priority = NSLayoutConstraint.Priority(249)
        let artworkConstraints = [
            heroArtwork.leadingAnchor.constraint(equalTo: hero.centerXAnchor, constant: 8),
            heroArtwork.trailingAnchor.constraint(equalTo: hero.trailingAnchor),
            heroArtwork.topAnchor.constraint(equalTo: hero.topAnchor),
            heroArtwork.bottomAnchor.constraint(equalTo: hero.bottomAnchor),
        ]
        wideHeroConstraints = [wideCopyConstraint] + artworkConstraints
        compactHeroConstraint = copy.trailingAnchor.constraint(lessThanOrEqualTo: hero.trailingAnchor, constant: -24)
        NSLayoutConstraint.activate([
            copy.leadingAnchor.constraint(equalTo: hero.leadingAnchor, constant: 24),
            copy.centerYAnchor.constraint(equalTo: hero.centerYAnchor),
        ] + wideHeroConstraints)

        let topCapabilities = NSStackView(views: [dictationCapability, meetingCapability])
        let bottomCapabilities = NSStackView(views: [audioCapability, voiceCapability])
        for row in [topCapabilities, bottomCapabilities] {
            row.orientation = .horizontal
            row.alignment = .top
            row.distribution = .fillEqually
            row.spacing = 14
        }
        let capabilities = NSStackView(views: [topCapabilities, bottomCapabilities])
        capabilities.identifier = NSUserInterfaceItemIdentifier("kiki.workbench.home.capabilities")
        capabilities.orientation = .vertical
        capabilities.alignment = .leading
        capabilities.spacing = 14
        topCapabilities.widthAnchor.constraint(equalTo: capabilities.widthAnchor).isActive = true
        bottomCapabilities.widthAnchor.constraint(equalTo: capabilities.widthAnchor).isActive = true
        [dictationCapability, meetingCapability, audioCapability, voiceCapability].forEach {
            $0.heightAnchor.constraint(equalToConstant: 148).isActive = true
        }

        makeReadinessCard()

        let stack = NSStackView(views: [hero, capabilities, readinessCard])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        let responsiveWidth = stack.widthAnchor.constraint(equalTo: widthAnchor, constant: -48)
        responsiveWidth.priority = .defaultHigh
        NSLayoutConstraint.activate([
            backdrop.leadingAnchor.constraint(equalTo: leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: trailingAnchor),
            backdrop.topAnchor.constraint(equalTo: topAnchor),
            backdrop.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24),
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.widthAnchor.constraint(lessThanOrEqualToConstant: 1_180),
            responsiveWidth,
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -24),
            hero.widthAnchor.constraint(equalTo: stack.widthAnchor),
            hero.heightAnchor.constraint(equalToConstant: 176),
            capabilities.widthAnchor.constraint(equalTo: stack.widthAnchor),
            readinessCard.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
        // Start from the narrow-safe constraint set so AppKit's initial fitting
        // pass cannot turn the wide presentation into a larger minimum window.
        updateHeroLayout(compact: true)
    }

    private func updateHeroLayout(compact: Bool) {
        if usesCompactHero != compact {
            usesCompactHero = compact
            if compact {
                NSLayoutConstraint.deactivate(wideHeroConstraints)
                compactHeroConstraint?.isActive = true
            } else {
                compactHeroConstraint?.isActive = false
                NSLayoutConstraint.activate(wideHeroConstraints)
            }
            heroArtworkView?.isHidden = compact
        }

    }

    private func makeReadinessCard() {
        let title = kikiLabel("Finish setup", size: 16, weight: .semibold)
        let rows: [NSView] = [
            microphoneReadinessRow,
            accessibilityReadinessRow,
            modelReadinessRow,
            shortcutReadinessRow,
            firstDictationReadinessRow,
        ]
        readinessDetailLabel.maximumNumberOfLines = 0

        let copy = NSStackView(views: [title, readinessDetailLabel])
        copy.identifier = NSUserInterfaceItemIdentifier("kiki.workbench.home.readiness-copy")
        copy.orientation = .vertical
        copy.alignment = .leading
        copy.spacing = 5

        let list = NSStackView(views: rows)
        list.identifier = NSUserInterfaceItemIdentifier("kiki.workbench.home.readiness-list")
        list.orientation = .vertical
        list.alignment = .leading
        list.spacing = 4
        rows.forEach { $0.widthAnchor.constraint(equalTo: list.widthAnchor).isActive = true }

        copy.translatesAutoresizingMaskIntoConstraints = false
        list.translatesAutoresizingMaskIntoConstraints = false
        readinessCard.identifier = NSUserInterfaceItemIdentifier("kiki.workbench.home.readiness-card")
        readinessCard.addSubview(copy)
        readinessCard.addSubview(list)

        NSLayoutConstraint.activate([
            copy.leadingAnchor.constraint(equalTo: readinessCard.leadingAnchor, constant: 18),
            copy.trailingAnchor.constraint(lessThanOrEqualTo: readinessCard.trailingAnchor, constant: -18),
            copy.topAnchor.constraint(equalTo: readinessCard.topAnchor, constant: 16),
            list.leadingAnchor.constraint(equalTo: copy.leadingAnchor),
            list.trailingAnchor.constraint(lessThanOrEqualTo: readinessCard.trailingAnchor, constant: -18),
            list.widthAnchor.constraint(equalToConstant: 376),
            list.topAnchor.constraint(equalTo: copy.bottomAnchor, constant: 10),
            list.bottomAnchor.constraint(equalTo: readinessCard.bottomAnchor, constant: -14),
        ])
    }

    @objc private func startDictation() { onStartDictation?() }
    @objc private func openMeeting() { onOpenMeeting?() }
    @objc private func openVoiceStudio() { onOpenVoiceStudio?() }
    @objc private func openAudioFile() { onOpenAudioFile?() }
    @objc private func openCheckup() { onOpenCheckup?() }
}

@MainActor
private final class GuidedWorkbenchCapabilityCard: KikiCardView {
    private let statusLabel = kikiLabel("", size: 10.5, weight: .semibold, color: KikiPalette.secondaryText)
    private let statusDot = NSView()
    let actionButton: KikiActionButton

    init(
        symbol: String,
        title: String,
        detail: String,
        actionTitle: String,
        buttonKind: KikiActionButton.Kind = .hardware,
        identifier: String,
        target: AnyObject,
        action: Selector
    ) {
        actionButton = KikiActionButton(actionTitle, kind: buttonKind, target: target, action: action)
        super.init(frame: .zero)
        self.identifier = NSUserInterfaceItemIdentifier("kiki.workbench.home.capability.\(identifier)")
        actionButton.identifier = NSUserInterfaceItemIdentifier("kiki.workbench.home.\(identifier)")
        actionButton.font = .systemFont(ofSize: 12.5, weight: .semibold)
        actionButton.heightAnchor.constraint(equalToConstant: KikiMetrics.compactControlHeight).isActive = true

        let icon = NSImageView(image: NSImage(systemSymbolName: symbol, accessibilityDescription: nil) ?? NSImage())
        icon.contentTintColor = KikiPalette.accentText
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 17, weight: .medium)
        icon.setAccessibilityElement(false)
        let titleLabel = kikiLabel(title, size: 15.5, weight: .semibold)
        let heading = NSStackView(views: [icon, titleLabel])
        heading.orientation = .horizontal
        heading.alignment = .centerY
        heading.spacing = 9

        let detailLabel = kikiLabel(detail, size: 11.5, color: KikiPalette.secondaryText)
        detailLabel.maximumNumberOfLines = 2
        detailLabel.lineBreakMode = .byWordWrapping
        statusDot.identifier = NSUserInterfaceItemIdentifier("kiki.workbench.home.capability.\(identifier).status-dot")
        statusDot.wantsLayer = true
        statusDot.layer?.cornerRadius = 3
        statusDot.layer?.backgroundColor = KikiPalette.accentText.cgColor
        statusDot.setAccessibilityElement(false)
        statusDot.widthAnchor.constraint(equalToConstant: 6).isActive = true
        statusDot.heightAnchor.constraint(equalToConstant: 6).isActive = true
        statusLabel.identifier = NSUserInterfaceItemIdentifier("kiki.workbench.home.capability.\(identifier).status")
        let status = NSStackView(views: [statusDot, statusLabel])
        status.orientation = .horizontal
        status.alignment = .centerY
        status.spacing = 7
        let footer = NSStackView(views: [status, NSView(), actionButton])
        footer.orientation = .horizontal
        footer.alignment = .centerY
        footer.spacing = 8

        let stack = NSStackView(views: [heading, detailLabel, footer])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 15),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -14),
            detailLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            footer.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func updateStatus(_ text: String, ready: Bool) {
        statusLabel.stringValue = text
        statusLabel.textColor = ready ? KikiPalette.accentText : KikiPalette.khaki
        statusDot.layer?.backgroundColor = (ready ? KikiPalette.accentText : KikiPalette.khaki).cgColor
    }
}

@MainActor
private final class GuidedWorkbenchReadinessRow: NSStackView {
    var onActivate: (() -> Void)?
    private let dot = NSView()
    private let valueLabel = kikiLabel("Not checked", size: 11.5, color: KikiPalette.secondaryText)
    private lazy var actionButton = KikiActionButton("Open", kind: .hardware, target: self, action: #selector(activate))

    init(title: String, identifier: String) {
        super.init(frame: .zero)
        self.identifier = NSUserInterfaceItemIdentifier("kiki.workbench.home.readiness.\(identifier)")
        valueLabel.identifier = NSUserInterfaceItemIdentifier("kiki.workbench.home.readiness.\(identifier).value")
        actionButton.identifier = NSUserInterfaceItemIdentifier("kiki.workbench.home.readiness.\(identifier).action")
        dot.wantsLayer = true
        dot.layer?.cornerRadius = 4
        dot.setAccessibilityElement(false)
        let titleLabel = kikiLabel(title, size: 12.5, weight: .medium)
        titleLabel.identifier = NSUserInterfaceItemIdentifier("kiki.workbench.home.readiness.\(identifier).title")
        valueLabel.alignment = .left
        valueLabel.lineBreakMode = .byTruncatingTail
        valueLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        addArrangedSubview(dot)
        addArrangedSubview(titleLabel)
        addArrangedSubview(valueLabel)
        let actionContainer = NSView()
        actionButton.translatesAutoresizingMaskIntoConstraints = false
        actionContainer.addSubview(actionButton)
        addArrangedSubview(actionContainer)
        orientation = .horizontal
        alignment = .centerY
        spacing = 8
        dot.widthAnchor.constraint(equalToConstant: 8).isActive = true
        dot.heightAnchor.constraint(equalToConstant: 8).isActive = true
        titleLabel.widthAnchor.constraint(equalToConstant: 132).isActive = true
        valueLabel.widthAnchor.constraint(equalToConstant: 108).isActive = true
        actionContainer.widthAnchor.constraint(equalToConstant: 104).isActive = true
        actionContainer.heightAnchor.constraint(equalToConstant: 30).isActive = true
        NSLayoutConstraint.activate([
            actionButton.leadingAnchor.constraint(equalTo: actionContainer.leadingAnchor),
            actionButton.trailingAnchor.constraint(equalTo: actionContainer.trailingAnchor),
            actionButton.topAnchor.constraint(equalTo: actionContainer.topAnchor),
            actionButton.bottomAnchor.constraint(equalTo: actionContainer.bottomAnchor),
        ])
        heightAnchor.constraint(equalToConstant: 32).isActive = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(passed: Bool, value: String, actionTitle: String, showsAction: Bool? = nil) {
        dot.layer?.backgroundColor = (passed ? KikiPalette.accentText : KikiPalette.khaki).cgColor
        valueLabel.stringValue = value
        actionButton.title = actionTitle
        actionButton.isHidden = !(showsAction ?? !passed)
    }

    @objc private func activate() { onActivate?() }
}

@MainActor
final class GuidedWorkbenchDictationView: NSView {
    var onToggleDictation: (() -> Void)?
    var onUndo: (() -> Void)?
    var onRetry: (() -> Void)?
    var onPrivateSession: (() -> Void)?

    private let stateLabel = kikiLabel("READY", size: 10, weight: .bold, color: KikiPalette.accentText)
    private let configuredShortcutLabel = kikiLabel("", size: 14, weight: .semibold, color: KikiPalette.khaki)
    private let handsFreeShortcutLabel = kikiLabel(DictationShortcutGuidance.handsFreeInstruction, size: 12.5, color: KikiPalette.secondaryText)
    private lazy var toggleButton = KikiActionButton("Try Dictation", kind: .primary, target: self, action: #selector(toggle))
    private lazy var undoButton = KikiActionButton("Undo Last Dictation", kind: .hardware, target: self, action: #selector(undo))
    private lazy var retryButton = KikiActionButton("Retry Last Dictation", kind: .hardware, target: self, action: #selector(retry))
    private lazy var privateButton = KikiActionButton("Start Private Session", kind: .hardware, target: self, action: #selector(togglePrivate))

    init() {
        super.init(frame: .zero)
        buildContent()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(state: DictationState, canUndo: Bool, canRetry: Bool) {
        configuredShortcutLabel.stringValue = "Configured shortcut: \(Settings.activationMode.configuredInstruction(for: Settings.dictationShortcut))"
        handsFreeShortcutLabel.stringValue = DictationShortcutGuidance.handsFreeInstruction
        undoButton.isEnabled = canUndo
        retryButton.isEnabled = canRetry
        privateButton.title = PrivateSessionController.shared.isActive ? "End Private Session" : "Start Private Session"
        switch state {
        case .noModel:
            stateLabel.stringValue = "MODEL UNAVAILABLE"
            toggleButton.title = "Open Models"
            toggleButton.isEnabled = false
        case .loadingModel:
            stateLabel.stringValue = "LOADING MODEL"
            toggleButton.title = "Loading…"
            toggleButton.isEnabled = false
        case .idle:
            stateLabel.stringValue = "READY"
            toggleButton.title = "Try Dictation"
        case .recording:
            stateLabel.stringValue = "LISTENING"
            toggleButton.title = "Stop & Insert"
        case .transcribing:
            stateLabel.stringValue = "TRANSCRIBING"
            toggleButton.title = Settings.enableZeroWaitChaining ? "Try Another Dictation" : "Transcribing…"
            toggleButton.isEnabled = Settings.enableZeroWaitChaining
        }
        if state == .idle || state == .recording { toggleButton.isEnabled = true }
    }

    private func buildContent() {
        let backdrop = KikiBackdropView()
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        addSubview(backdrop)
        let eyebrow = kikiLabel("DICTATE ANYWHERE", size: 10, weight: .bold, color: KikiPalette.accentText)
        let title = kikiLabel("Speak. Review. Insert.", size: 31, weight: .bold)
        let detail = kikiLabel("Use your shortcut in any text field. Kiki listens locally, shows live feedback, then inserts the finished text.", size: 14, color: KikiPalette.secondaryText)
        detail.maximumNumberOfLines = 0
        configuredShortcutLabel.identifier = NSUserInterfaceItemIdentifier("kiki.workbench.dictation.configured-shortcut")
        configuredShortcutLabel.maximumNumberOfLines = 0
        handsFreeShortcutLabel.identifier = NSUserInterfaceItemIdentifier("kiki.workbench.dictation.hands-free-shortcut")
        handsFreeShortcutLabel.maximumNumberOfLines = 0
        let heading = NSStackView(views: [eyebrow, title, detail, configuredShortcutLabel, handsFreeShortcutLabel, toggleButton])
        heading.orientation = .vertical
        heading.alignment = .leading
        heading.spacing = 8
        heading.setCustomSpacing(16, after: detail)
        heading.setCustomSpacing(18, after: handsFreeShortcutLabel)
        let hero = KikiCardView()
        install(heading, in: hero)

        let behaviorTitle = kikiLabel("Current behavior", size: 18, weight: .semibold)
        let behavior = NSStackView(views: [behaviorTitle, row("Listening display", "\(Settings.listeningDisplayMode.title)"), row("Position", Settings.listeningDisplayPosition.title), row("Speech style", Settings.speechProfile.title), row("Mac audio", Settings.silenceSystemAudioWhileRecording ? "Muted" : "Not muted")])
        behavior.orientation = .vertical
        behavior.alignment = .leading
        behavior.spacing = 11
        let behaviorCard = KikiCardView()
        install(behavior, in: behaviorCard)

        let recoveryTitle = kikiLabel("Recovery & privacy", size: 18, weight: .semibold)
        let recoveryDetail = kikiLabel("These actions operate on Kiki’s exact last insertion.", size: 12, color: KikiPalette.secondaryText)
        let recovery = NSStackView(views: [recoveryTitle, recoveryDetail, undoButton, retryButton, privateButton])
        recovery.orientation = .vertical
        recovery.alignment = .leading
        recovery.spacing = 9
        for button in [undoButton, retryButton, privateButton] {
            button.widthAnchor.constraint(equalToConstant: 190).isActive = true
        }
        let recoveryCard = KikiCardView()
        install(recovery, in: recoveryCard)

        let columns = NSStackView(views: [behaviorCard, recoveryCard])
        columns.orientation = .horizontal
        columns.alignment = .top
        columns.distribution = .fillEqually
        columns.spacing = 14
        behaviorCard.widthAnchor.constraint(equalTo: recoveryCard.widthAnchor).isActive = true

        let stack = NSStackView(views: [hero, columns])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            backdrop.leadingAnchor.constraint(equalTo: leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: trailingAnchor),
            backdrop.topAnchor.constraint(equalTo: topAnchor),
            backdrop.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 24),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -24),
            hero.widthAnchor.constraint(equalTo: stack.widthAnchor),
            hero.heightAnchor.constraint(equalToConstant: 255),
            columns.widthAnchor.constraint(equalTo: stack.widthAnchor),
            behaviorCard.heightAnchor.constraint(equalToConstant: 245),
            recoveryCard.heightAnchor.constraint(equalToConstant: 245),
        ])
        update(state: .idle, canUndo: false, canRetry: false)
    }

    private func row(_ title: String, _ value: String) -> NSView {
        let left = kikiLabel(title, size: 12.5, weight: .medium)
        let right = kikiLabel(value, size: 11.5, color: KikiPalette.secondaryText)
        let row = NSStackView(views: [left, NSView(), right])
        row.orientation = .horizontal
        row.alignment = .centerY
        return row
    }

    private func install(_ stack: NSStackView, in card: NSView) {
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 22),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -22),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: card.bottomAnchor, constant: -20),
        ])
    }

    @objc private func toggle() { onToggleDictation?() }
    @objc private func undo() { onUndo?() }
    @objc private func retry() { onRetry?() }
    @objc private func togglePrivate() { onPrivateSession?() }
}

@MainActor
final class GuidedWorkbenchSupportView: NSView {
    var onCreateBundle: (() -> Void)?
    var onOpenModels: (() -> Void)?
    var onCheckUpdates: (() -> Void)?

    init() {
        super.init(frame: .zero)
        let backdrop = KikiBackdropView()
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        addSubview(backdrop)
        let header = headerView(eyebrow: "SUPPORT", title: "Diagnostics without guesswork.", detail: "Create a private support bundle or inspect the local files Kiki manages.")
        let bundle = card(symbol: "shippingbox", title: "Support Bundle", detail: "Collect logs and configuration without transcript text or recordings.", button: "Create Support Bundle", action: #selector(createBundle))
        let models = card(symbol: "folder", title: "Models Folder", detail: "Reveal downloaded transcription and voice-engine files in Finder.", button: "Open Models Folder", action: #selector(openModels))
        let updates = card(symbol: "arrow.triangle.2.circlepath", title: "Signed Updates", detail: "Check Kiki’s verified Sparkle release feed.", button: "Check for Updates", action: #selector(checkUpdates))
        let cards = NSStackView(views: [bundle, models, updates])
        cards.orientation = .horizontal
        cards.alignment = .top
        cards.distribution = .fillEqually
        cards.spacing = 14
        let stack = NSStackView(views: [header, cards])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 22
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            backdrop.leadingAnchor.constraint(equalTo: leadingAnchor), backdrop.trailingAnchor.constraint(equalTo: trailingAnchor), backdrop.topAnchor.constraint(equalTo: topAnchor), backdrop.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 28), stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -28), stack.topAnchor.constraint(equalTo: topAnchor, constant: 30),
            cards.widthAnchor.constraint(equalTo: stack.widthAnchor), bundle.heightAnchor.constraint(equalToConstant: 260), models.heightAnchor.constraint(equalTo: bundle.heightAnchor), updates.heightAnchor.constraint(equalTo: bundle.heightAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func headerView(eyebrow: String, title: String, detail: String) -> NSView {
        let eyebrowLabel = kikiLabel(eyebrow, size: 10, weight: .bold, color: KikiPalette.accentText)
        let titleLabel = kikiLabel(title, size: 29, weight: .bold)
        let detailLabel = kikiLabel(detail, size: 14, color: KikiPalette.secondaryText)
        let stack = NSStackView(views: [eyebrowLabel, titleLabel, detailLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        return stack
    }

    private func card(symbol: String, title: String, detail: String, button: String, action: Selector) -> KikiCardView {
        let card = KikiCardView()
        let image = NSImageView(image: NSImage(systemSymbolName: symbol, accessibilityDescription: title) ?? NSImage())
        image.contentTintColor = KikiPalette.accentText
        let titleLabel = kikiLabel(title, size: 18, weight: .semibold)
        let detailLabel = kikiLabel(detail, size: 12.5, color: KikiPalette.secondaryText)
        detailLabel.maximumNumberOfLines = 0
        let actionButton = KikiActionButton(button, kind: .hardware, target: self, action: action)
        let stack = NSStackView(views: [image, titleLabel, detailLabel, NSView(), actionButton])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            image.widthAnchor.constraint(equalToConstant: 28), image.heightAnchor.constraint(equalToConstant: 28),
            actionButton.leadingAnchor.constraint(equalTo: stack.leadingAnchor),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18), stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18), stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 18), stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),
        ])
        return card
    }

    @objc private func createBundle() { onCreateBundle?() }
    @objc private func openModels() { onOpenModels?() }
    @objc private func checkUpdates() { onCheckUpdates?() }
}

@MainActor
final class GuidedWorkbenchAboutView: NSView {
    var onRunCheckup: (() -> Void)?
    var onCheckUpdates: (() -> Void)?

    init() {
        super.init(frame: .zero)
        let backdrop = KikiBackdropView()
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        addSubview(backdrop)
        let image = KikiCircularPortraitView()
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        let eyebrow = kikiLabel("ABOUT KIKI", size: 10, weight: .bold, color: KikiPalette.accentText)
        let title = kikiLabel("Voice intelligence that stays yours.", size: 30, weight: .bold)
        let detail = kikiLabel("Private dictation, meeting intelligence, local voice creation, and personal adaptation for macOS.", size: 14, color: KikiPalette.secondaryText)
        detail.maximumNumberOfLines = 0
        let versionLabel = kikiLabel("Version \(version) · Build \(build) · Fully local", size: 12, weight: .semibold, color: KikiPalette.khaki)
        let checkup = KikiActionButton("Run Kiki Checkup", kind: .primary, target: self, action: #selector(runCheckup))
        checkup.identifier = NSUserInterfaceItemIdentifier("kiki.workbench.about.checkup")
        let checkUpdates = KikiActionButton("Check for Updates", kind: .secondary, target: self, action: #selector(checkUpdates))
        checkUpdates.identifier = NSUserInterfaceItemIdentifier("kiki.workbench.about.check-updates")
        let actions = NSStackView(views: [checkup, checkUpdates])
        actions.orientation = .horizontal
        actions.alignment = .centerY
        actions.spacing = 10
        NSLayoutConstraint.activate([
            checkup.widthAnchor.constraint(equalToConstant: 150),
            checkUpdates.widthAnchor.constraint(equalTo: checkup.widthAnchor),
            checkUpdates.heightAnchor.constraint(equalTo: checkup.heightAnchor),
        ])
        let copy = NSStackView(views: [eyebrow, title, detail, versionLabel, actions])
        copy.orientation = .vertical
        copy.alignment = .leading
        copy.spacing = 8
        copy.setCustomSpacing(17, after: versionLabel)
        let hero = KikiCardView()
        image.translatesAutoresizingMaskIntoConstraints = false
        copy.translatesAutoresizingMaskIntoConstraints = false
        hero.addSubview(image)
        hero.addSubview(copy)
        NSLayoutConstraint.activate([
            image.leadingAnchor.constraint(equalTo: hero.leadingAnchor, constant: 28), image.centerYAnchor.constraint(equalTo: hero.centerYAnchor), image.widthAnchor.constraint(equalToConstant: 180), image.heightAnchor.constraint(equalToConstant: 180),
            copy.leadingAnchor.constraint(equalTo: image.trailingAnchor, constant: 32), copy.trailingAnchor.constraint(equalTo: hero.trailingAnchor, constant: -28), copy.centerYAnchor.constraint(equalTo: hero.centerYAnchor),
        ])
        let changes = KikiCardView()
        let changesTitle = kikiLabel("Built for the real world", size: 18, weight: .semibold)
        let changesCopy = kikiLabel("One guided workbench now brings every management surface together. Menu-bar dictation remains available from any app, while Checkup, reversible dictation, private Pawprints, meetings, personalization, models, and Voice Studio stay close at hand.", size: 13, color: KikiPalette.secondaryText)
        changesCopy.maximumNumberOfLines = 0
        let changeStack = NSStackView(views: [changesTitle, changesCopy])
        changeStack.orientation = .vertical
        changeStack.alignment = .leading
        changeStack.spacing = 8
        changeStack.translatesAutoresizingMaskIntoConstraints = false
        changes.addSubview(changeStack)
        NSLayoutConstraint.activate([
            changeStack.leadingAnchor.constraint(equalTo: changes.leadingAnchor, constant: 20), changeStack.trailingAnchor.constraint(equalTo: changes.trailingAnchor, constant: -20), changeStack.topAnchor.constraint(equalTo: changes.topAnchor, constant: 18), changeStack.bottomAnchor.constraint(equalTo: changes.bottomAnchor, constant: -18),
        ])
        let templetonFooter = TempletonTechnologiesProductFooterView()
        let templetonFooterContainer = NSView()
        templetonFooterContainer.translatesAutoresizingMaskIntoConstraints = false
        templetonFooter.translatesAutoresizingMaskIntoConstraints = false
        templetonFooterContainer.addSubview(templetonFooter)
        let stack = NSStackView(views: [hero, changes, templetonFooterContainer])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        let responsiveFooterWidth = templetonFooter.widthAnchor.constraint(
            equalTo: templetonFooterContainer.widthAnchor,
            multiplier: 0.52
        )
        responsiveFooterWidth.priority = .init(998)
        let minimumReadableFooterWidth = templetonFooter.widthAnchor.constraint(greaterThanOrEqualToConstant: 420)
        minimumReadableFooterWidth.priority = .init(999)
        NSLayoutConstraint.activate([
            backdrop.leadingAnchor.constraint(equalTo: leadingAnchor), backdrop.trailingAnchor.constraint(equalTo: trailingAnchor), backdrop.topAnchor.constraint(equalTo: topAnchor), backdrop.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 28), stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -28), stack.topAnchor.constraint(equalTo: topAnchor, constant: 28),
            hero.widthAnchor.constraint(equalTo: stack.widthAnchor), hero.heightAnchor.constraint(equalToConstant: 260), changes.widthAnchor.constraint(equalTo: stack.widthAnchor), changes.heightAnchor.constraint(equalToConstant: 150),
            templetonFooterContainer.widthAnchor.constraint(equalTo: stack.widthAnchor),
            templetonFooter.topAnchor.constraint(equalTo: templetonFooterContainer.topAnchor),
            templetonFooter.bottomAnchor.constraint(equalTo: templetonFooterContainer.bottomAnchor),
            templetonFooter.centerXAnchor.constraint(equalTo: templetonFooterContainer.centerXAnchor),
            responsiveFooterWidth,
            minimumReadableFooterWidth,
            templetonFooter.widthAnchor.constraint(lessThanOrEqualTo: templetonFooterContainer.widthAnchor),
            templetonFooter.heightAnchor.constraint(equalTo: templetonFooter.widthAnchor, multiplier: 318.0 / 698.0),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    @objc private func runCheckup() { onRunCheckup?() }
    @objc private func checkUpdates() { onCheckUpdates?() }
}

@MainActor
private final class TempletonTechnologiesProductFooterView: NSView {
    init() {
        super.init(frame: .zero)
        identifier = NSUserInterfaceItemIdentifier("kiki.workbench.about.templeton-footer")
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        let productLabel = kikiLabel(
            "A Templeton Technologies Product",
            size: 16,
            weight: .regular,
            color: KikiPalette.secondaryText
        )
        productLabel.identifier = NSUserInterfaceItemIdentifier("kiki.workbench.about.templeton-product-label")
        productLabel.alignment = .center
        productLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(productLabel)

        let logoView = NSImageView()
        logoView.identifier = NSUserInterfaceItemIdentifier("kiki.workbench.about.templeton-logo")
        logoView.imageScaling = .scaleProportionallyUpOrDown
        logoView.imageAlignment = .alignCenter
        logoView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        logoView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        logoView.translatesAutoresizingMaskIntoConstraints = false
        if let url = Bundle.main.url(forResource: "TempletonTechnologies", withExtension: "png") {
            logoView.image = NSImage(contentsOf: url)
        }
        logoView.setAccessibilityElement(true)
        logoView.setAccessibilityLabel("Templeton Technologies")
        addSubview(logoView)

        let labelTopGuide = NSLayoutGuide()
        let logoTopGuide = NSLayoutGuide()
        addLayoutGuide(labelTopGuide)
        addLayoutGuide(logoTopGuide)

        NSLayoutConstraint.activate([
            labelTopGuide.topAnchor.constraint(equalTo: topAnchor),
            labelTopGuide.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 23.0 / 318.0),
            productLabel.topAnchor.constraint(equalTo: labelTopGuide.bottomAnchor),
            productLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            productLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            productLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24),
            logoTopGuide.topAnchor.constraint(equalTo: topAnchor),
            logoTopGuide.heightAnchor.constraint(equalTo: heightAnchor, multiplier: 70.0 / 318.0),
            logoView.topAnchor.constraint(equalTo: logoTopGuide.bottomAnchor),
            logoView.centerXAnchor.constraint(equalTo: centerXAnchor),
            logoView.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 600.0 / 698.0),
            logoView.heightAnchor.constraint(equalTo: logoView.widthAnchor, multiplier: 2_178.0 / 5_000.0),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
