import AppKit

/// The orientation surface Kiki opens to. It explains the product before
/// asking a new user to navigate into transcripts or settings.
@MainActor
final class GuidedWorkbenchHomeView: NSView {
    var onRunSetup: (() -> Void)?
    var onStartDictation: (() -> Void)?
    var onOpenMeeting: (() -> Void)?
    var onOpenAudioFile: (() -> Void)?

    private let setupStatus = kikiLabel("Checking setup…", size: 12.5, weight: .semibold, color: KikiPalette.khaki)
    private lazy var setupButton = KikiActionButton("Run Guided Setup", kind: .primary, target: self, action: #selector(runSetup))

    init() {
        super.init(frame: .zero)
        buildContent()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(snapshot: KikiCheckupSnapshot) {
        let checks = [
            snapshot.microphoneAuthorized,
            snapshot.inputResponding,
            snapshot.accessibilityAuthorized,
            snapshot.modelStatus.isReady,
            snapshot.shortcutVerified,
            snapshot.firstDictationCompleted,
        ]
        let remaining = checks.filter { !$0 }.count
        if remaining == 0 {
            setupStatus.stringValue = "Setup complete · Kiki is ready to dictate"
            setupStatus.textColor = KikiPalette.accentText
            setupButton.title = "Review Setup"
        } else {
            setupStatus.stringValue = "\(remaining) setup check\(remaining == 1 ? "" : "s") remaining"
            setupStatus.textColor = KikiPalette.khaki
            setupButton.title = "Run Guided Setup"
        }
    }

    private func buildContent() {
        let backdrop = KikiBackdropView()
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        addSubview(backdrop)

        let eyebrow = kikiLabel("WELCOME · FULLY LOCAL", size: 10, weight: .bold, color: KikiPalette.accentText)
        let title = kikiLabel("Turn your voice into text.", size: 31, weight: .bold)
        title.identifier = NSUserInterfaceItemIdentifier("kiki.workbench.home.title")
        let intro = kikiLabel(
            "Kiki lives in your menu bar and works in any Mac text field. Finish the short setup once, then use your shortcut whenever you want to dictate.",
            size: 14,
            color: KikiPalette.secondaryText
        )
        intro.maximumNumberOfLines = 0
        let shortcut = kikiLabel(
            "Your shortcut: \(Settings.activationMode.configuredInstruction(for: Settings.dictationShortcut))",
            size: 12.5,
            weight: .semibold,
            color: KikiPalette.primaryText
        )
        shortcut.identifier = NSUserInterfaceItemIdentifier("kiki.workbench.home.shortcut")
        shortcut.maximumNumberOfLines = 0
        setupStatus.identifier = NSUserInterfaceItemIdentifier("kiki.workbench.home.setup-status")
        setupButton.identifier = NSUserInterfaceItemIdentifier("kiki.workbench.home.setup")
        setupButton.widthAnchor.constraint(equalToConstant: 164).isActive = true
        setupButton.heightAnchor.constraint(equalToConstant: 40).isActive = true

        let heroCopy = NSStackView(views: [eyebrow, title, intro, shortcut, setupStatus, setupButton])
        heroCopy.orientation = .vertical
        heroCopy.alignment = .leading
        heroCopy.spacing = 7
        heroCopy.setCustomSpacing(15, after: intro)
        heroCopy.setCustomSpacing(14, after: setupStatus)
        heroCopy.translatesAutoresizingMaskIntoConstraints = false

        let hero = KikiCardView()
        hero.identifier = NSUserInterfaceItemIdentifier("kiki.workbench.home.hero")
        hero.addSubview(heroCopy)
        NSLayoutConstraint.activate([
            heroCopy.leadingAnchor.constraint(equalTo: hero.leadingAnchor, constant: 24),
            heroCopy.trailingAnchor.constraint(lessThanOrEqualTo: hero.trailingAnchor, constant: -24),
            heroCopy.topAnchor.constraint(equalTo: hero.topAnchor, constant: 22),
            heroCopy.bottomAnchor.constraint(equalTo: hero.bottomAnchor, constant: -22),
        ])

        let guide = KikiCardView()
        guide.identifier = NSUserInterfaceItemIdentifier("kiki.workbench.home.guide")
        let guideTitle = kikiLabel("Start here", size: 18, weight: .semibold)
        let guideDetail = kikiLabel("Three steps take Kiki from a fresh install to your first finished dictation.", size: 12.5, color: KikiPalette.secondaryText)
        guideDetail.maximumNumberOfLines = 0
        let steps = NSStackView(views: [
            setupStep(1, title: "Allow microphone and Accessibility", detail: "Kiki needs microphone access to hear you and Accessibility access to insert text into other apps."),
            setupStep(2, title: "Prepare a local speech model", detail: "The model downloads once and transcription stays on this Mac."),
            setupStep(3, title: "Test your shortcut and first dictation", detail: "The guided field confirms that starting, stopping, transcription, and insertion all work."),
        ])
        steps.orientation = .vertical
        steps.alignment = .leading
        steps.spacing = 12
        let guideStack = NSStackView(views: [guideTitle, guideDetail, steps])
        guideStack.orientation = .vertical
        guideStack.alignment = .leading
        guideStack.spacing = 8
        guideStack.translatesAutoresizingMaskIntoConstraints = false
        guide.addSubview(guideStack)
        NSLayoutConstraint.activate([
            guideStack.leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: 20),
            guideStack.trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -20),
            guideStack.topAnchor.constraint(equalTo: guide.topAnchor, constant: 18),
            guideStack.bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -18),
            steps.widthAnchor.constraint(equalTo: guideStack.widthAnchor),
        ])

        let dictation = workflowCard(
            kind: .dictation,
            title: "Dictate anywhere",
            detail: "Click into any text field, use your shortcut, speak, then stop to insert the finished text.",
            actionTitle: "Try Dictation",
            identifier: "dictation",
            action: #selector(startDictation)
        )
        let meeting = workflowCard(
            kind: .meeting,
            title: "Capture a meeting",
            detail: "Record a conversation, then review its transcript, summary, and next steps.",
            actionTitle: "Capture Meeting",
            identifier: "meeting",
            action: #selector(openMeeting)
        )
        let audio = workflowCard(
            kind: .audioFile,
            title: "Transcribe a recording",
            detail: "Choose an audio file and turn it into editable, exportable text on this Mac.",
            actionTitle: "Import Audio",
            identifier: "audio",
            action: #selector(openAudioFile)
        )
        let workflows = NSStackView(views: [dictation, meeting, audio])
        workflows.identifier = NSUserInterfaceItemIdentifier("kiki.workbench.home.workflows")
        workflows.orientation = .horizontal
        workflows.alignment = .top
        workflows.distribution = .fillEqually
        workflows.spacing = 14

        let stack = NSStackView(views: [hero, guide, workflows])
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
            guide.widthAnchor.constraint(equalTo: stack.widthAnchor),
            workflows.widthAnchor.constraint(equalTo: stack.widthAnchor),
            dictation.heightAnchor.constraint(equalToConstant: 178),
            meeting.heightAnchor.constraint(equalTo: dictation.heightAnchor),
            audio.heightAnchor.constraint(equalTo: dictation.heightAnchor),
        ])
    }

    private func setupStep(_ number: Int, title: String, detail: String) -> NSView {
        let badge = NSTextField(labelWithString: "\(number)")
        badge.alignment = .center
        badge.font = .monospacedDigitSystemFont(ofSize: 12, weight: .bold)
        badge.textColor = KikiPalette.accentText
        badge.wantsLayer = true
        badge.layer?.cornerRadius = 13
        badge.layer?.borderWidth = 1
        badge.layer?.borderColor = KikiPalette.accentText.withAlphaComponent(0.55).cgColor
        badge.widthAnchor.constraint(equalToConstant: 26).isActive = true
        badge.heightAnchor.constraint(equalToConstant: 26).isActive = true
        let titleLabel = kikiLabel(title, size: 13, weight: .semibold)
        let detailLabel = kikiLabel(detail, size: 11.5, color: KikiPalette.secondaryText)
        detailLabel.maximumNumberOfLines = 0
        let copy = NSStackView(views: [titleLabel, detailLabel])
        copy.orientation = .vertical
        copy.alignment = .leading
        copy.spacing = 3
        let row = NSStackView(views: [badge, copy])
        row.orientation = .horizontal
        row.alignment = .top
        row.spacing = 11
        return row
    }

    private func workflowCard(
        kind: KikiCapabilityVisualKind,
        title: String,
        detail: String,
        actionTitle: String,
        identifier: String,
        action: Selector
    ) -> KikiCardView {
        let card = KikiCardView()
        card.identifier = NSUserInterfaceItemIdentifier("kiki.workbench.home.workflow.\(identifier)")
        let icon = KikiCapabilityGlyphView(kind: kind)
        let titleLabel = kikiLabel(title, size: 16, weight: .semibold)
        let detailLabel = kikiLabel(detail, size: 11.5, color: KikiPalette.secondaryText)
        detailLabel.maximumNumberOfLines = 0
        let button = KikiActionButton(actionTitle, kind: .hardware, target: self, action: action)
        button.identifier = NSUserInterfaceItemIdentifier("kiki.workbench.home.\(identifier)")
        button.widthAnchor.constraint(equalToConstant: 150).isActive = true
        button.heightAnchor.constraint(equalToConstant: 36).isActive = true
        let heading = NSStackView(views: [icon, titleLabel])
        heading.orientation = .horizontal
        heading.alignment = .centerY
        heading.spacing = 9
        let content = NSStackView(views: [heading, detailLabel, NSView(), button])
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = 9
        content.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            content.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            content.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -16),
            detailLabel.widthAnchor.constraint(equalTo: content.widthAnchor),
        ])
        return card
    }

    @objc private func runSetup() { onRunSetup?() }
    @objc private func startDictation() { onStartDictation?() }
    @objc private func openMeeting() { onOpenMeeting?() }
    @objc private func openAudioFile() { onOpenAudioFile?() }
}
