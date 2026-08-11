import AppKit

@MainActor
final class GuidedWorkbenchHomeView: NSView {
    var onStartDictation: (() -> Void)?
    var onOpenMeeting: (() -> Void)?
    var onOpenVoiceStudio: (() -> Void)?
    var onOpenAudioFile: (() -> Void)?
    var onOpenPersonalization: (() -> Void)?
    var onOpenCheckup: (() -> Void)?

    init() {
        super.init(frame: .zero)
        buildContent()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildContent() {
        let backdrop = KikiBackdropView()
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        addSubview(backdrop)

        let eyebrow = kikiLabel("TODAY · FULLY LOCAL", size: 10, weight: .bold, color: KikiPalette.accentText)
        let title = kikiLabel("Good morning, Tony.", size: 31, weight: .bold)
        let intro = kikiLabel("Kiki is ready to dictate, capture a meeting, create audio, or work with a recording.", size: 14, color: KikiPalette.secondaryText)
        intro.maximumNumberOfLines = 0
        let start = KikiActionButton("Start Dictation", kind: .primary, target: self, action: #selector(startDictation))
        let meeting = KikiActionButton("Capture Meeting", kind: .hardware, target: self, action: #selector(openMeeting))
        let voice = KikiActionButton("Open Voice Studio", kind: .hardware, target: self, action: #selector(openVoiceStudio))
        let audio = KikiActionButton("Transcribe Audio", kind: .hardware, target: self, action: #selector(openAudioFile))
        start.identifier = NSUserInterfaceItemIdentifier("kiki.workbench.home.dictation")
        meeting.identifier = NSUserInterfaceItemIdentifier("kiki.workbench.home.meeting")
        voice.identifier = NSUserInterfaceItemIdentifier("kiki.workbench.home.voice")
        audio.identifier = NSUserInterfaceItemIdentifier("kiki.workbench.home.audio")
        let actions = NSStackView(views: [start, meeting, voice, audio])
        actions.orientation = .horizontal
        actions.alignment = .centerY
        actions.spacing = 8
        let copy = NSStackView(views: [eyebrow, title, intro, actions])
        copy.orientation = .vertical
        copy.alignment = .leading
        copy.spacing = 7
        copy.setCustomSpacing(16, after: intro)

        let heroArtwork = NSImageView()
        if let url = Bundle.main.url(forResource: "VoiceStudioHero", withExtension: "png") {
            heroArtwork.image = NSImage(contentsOf: url)
        }
        heroArtwork.imageScaling = .scaleProportionallyUpOrDown
        // The source artwork is intentionally high resolution. Its intrinsic pixel
        // width must never become the minimum width of the application window.
        heroArtwork.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        heroArtwork.setContentHuggingPriority(.defaultLow, for: .horizontal)
        heroArtwork.identifier = NSUserInterfaceItemIdentifier("kiki.workbench.home.hero")

        let hero = KikiCardView()
        hero.layer?.masksToBounds = true
        copy.translatesAutoresizingMaskIntoConstraints = false
        heroArtwork.translatesAutoresizingMaskIntoConstraints = false
        hero.addSubview(copy)
        hero.addSubview(heroArtwork)
        NSLayoutConstraint.activate([
            copy.leadingAnchor.constraint(equalTo: hero.leadingAnchor, constant: 24),
            copy.centerYAnchor.constraint(equalTo: hero.centerYAnchor),
            copy.trailingAnchor.constraint(lessThanOrEqualTo: hero.centerXAnchor, constant: -10),
            heroArtwork.leadingAnchor.constraint(equalTo: hero.centerXAnchor, constant: 8),
            heroArtwork.trailingAnchor.constraint(equalTo: hero.trailingAnchor),
            heroArtwork.topAnchor.constraint(equalTo: hero.topAnchor),
            heroArtwork.bottomAnchor.constraint(equalTo: hero.bottomAnchor),
        ])

        let attention = makeAttentionCard()
        let readiness = makeReadinessCard()
        let body = NSStackView(views: [attention, readiness])
        body.orientation = .horizontal
        body.alignment = .top
        body.distribution = .fillEqually
        body.spacing = 14
        attention.widthAnchor.constraint(equalTo: readiness.widthAnchor).isActive = true

        let stack = NSStackView(views: [hero, body])
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
            hero.heightAnchor.constraint(equalToConstant: 235),
            body.widthAnchor.constraint(equalTo: stack.widthAnchor),
            attention.heightAnchor.constraint(equalToConstant: 260),
            readiness.heightAnchor.constraint(equalToConstant: 260),
        ])
    }

    private func makeAttentionCard() -> KikiCardView {
        let card = KikiCardView()
        let title = kikiLabel("Needs your attention", size: 18, weight: .semibold)
        let detail = kikiLabel("Only unfinished work appears here.", size: 12, color: KikiPalette.secondaryText)
        let personalize = KikiActionButton("Review Corrections", kind: .hardware, target: self, action: #selector(openPersonalization))
        let checkup = KikiActionButton("Finish Kiki Checkup", kind: .hardware, target: self, action: #selector(openCheckup))
        let stack = NSStackView(views: [title, detail, separator(), personalize, checkup])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        personalize.widthAnchor.constraint(equalToConstant: 180).isActive = true
        checkup.widthAnchor.constraint(equalTo: personalize.widthAnchor).isActive = true
        install(stack, in: card)
        return card
    }

    private func makeReadinessCard() -> KikiCardView {
        let card = KikiCardView()
        let title = kikiLabel("System readiness", size: 18, weight: .semibold)
        let detail = kikiLabel("Everything required for private local speech.", size: 12, color: KikiPalette.secondaryText)
        let rows = [
            readinessRow("Microphone", value: "Allowed"),
            readinessRow("Accessibility", value: "Allowed"),
            readinessRow("Local model", value: Settings.transcriptionModel.displayName),
            readinessRow("Privacy", value: "On this Mac"),
        ]
        let stack = NSStackView(views: [title, detail, separator()] + rows)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        install(stack, in: card)
        return card
    }

    private func readinessRow(_ title: String, value: String) -> NSView {
        let dot = NSView()
        dot.wantsLayer = true
        dot.layer?.cornerRadius = 4
        dot.layer?.backgroundColor = KikiPalette.accentText.cgColor
        let label = kikiLabel(title, size: 12.5, weight: .medium)
        let valueLabel = kikiLabel(value, size: 11.5, color: KikiPalette.secondaryText)
        let row = NSStackView(views: [dot, label, NSView(), valueLabel])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        dot.widthAnchor.constraint(equalToConstant: 8).isActive = true
        dot.heightAnchor.constraint(equalToConstant: 8).isActive = true
        return row
    }

    private func separator() -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = KikiPalette.stroke.cgColor
        view.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return view
    }

    private func install(_ stack: NSStackView, in card: NSView) {
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: card.bottomAnchor, constant: -18),
        ])
    }

    @objc private func startDictation() { onStartDictation?() }
    @objc private func openMeeting() { onOpenMeeting?() }
    @objc private func openVoiceStudio() { onOpenVoiceStudio?() }
    @objc private func openAudioFile() { onOpenAudioFile?() }
    @objc private func openPersonalization() { onOpenPersonalization?() }
    @objc private func openCheckup() { onOpenCheckup?() }
}

@MainActor
final class GuidedWorkbenchDictationView: NSView {
    var onToggleDictation: (() -> Void)?
    var onUndo: (() -> Void)?
    var onRetry: (() -> Void)?
    var onPrivateSession: (() -> Void)?

    private let stateLabel = kikiLabel("READY", size: 10, weight: .bold, color: KikiPalette.accentText)
    private lazy var toggleButton = KikiActionButton("Start Dictation", kind: .primary, target: self, action: #selector(toggle))
    private lazy var undoButton = KikiActionButton("Undo Last Dictation", kind: .hardware, target: self, action: #selector(undo))
    private lazy var retryButton = KikiActionButton("Retry Last Dictation", kind: .hardware, target: self, action: #selector(retry))
    private lazy var privateButton = KikiActionButton("Start Private Session", kind: .hardware, target: self, action: #selector(togglePrivate))

    init() {
        super.init(frame: .zero)
        buildContent()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(state: DictationState, canUndo: Bool, canRetry: Bool) {
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
            toggleButton.title = "Start Dictation"
        case .recording:
            stateLabel.stringValue = "LISTENING"
            toggleButton.title = "Stop, Transcribe & Insert"
        case .transcribing:
            stateLabel.stringValue = "TRANSCRIBING"
            toggleButton.title = Settings.enableZeroWaitChaining ? "Start Another Dictation" : "Transcribing…"
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
        let shortcut = kikiLabel("⌃ ⌥ D", size: 15, weight: .semibold, color: KikiPalette.khaki)
        let heading = NSStackView(views: [eyebrow, title, detail, shortcut, toggleButton])
        heading.orientation = .vertical
        heading.alignment = .leading
        heading.spacing = 8
        heading.setCustomSpacing(16, after: detail)
        heading.setCustomSpacing(18, after: shortcut)
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
        let copy = NSStackView(views: [eyebrow, title, detail, versionLabel, checkup])
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
        let stack = NSStackView(views: [hero, changes])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            backdrop.leadingAnchor.constraint(equalTo: leadingAnchor), backdrop.trailingAnchor.constraint(equalTo: trailingAnchor), backdrop.topAnchor.constraint(equalTo: topAnchor), backdrop.bottomAnchor.constraint(equalTo: bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 28), stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -28), stack.topAnchor.constraint(equalTo: topAnchor, constant: 28),
            hero.widthAnchor.constraint(equalTo: stack.widthAnchor), hero.heightAnchor.constraint(equalToConstant: 260), changes.widthAnchor.constraint(equalTo: stack.widthAnchor), changes.heightAnchor.constraint(equalToConstant: 150),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    @objc private func runCheckup() { onRunCheckup?() }
}
