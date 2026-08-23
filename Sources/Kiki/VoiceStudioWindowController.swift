import AppKit
@preconcurrency import AVFoundation
import UniformTypeIdentifiers

@MainActor
final class VoiceStudioWindowController: NSWindowController, NSWindowDelegate {
    var onCaptureStateChange: ((Bool) -> Void)?

    private let synthesisEngine = LocalVoiceSynthesisEngine()
    private let recorder = AudioRecorder()
    private var recordingSamples: [Float]?
    private var recordingStartedAt: Date?
    private var recordingEnrollmentMode: VoiceEnrollmentMode?
    private var selectedEnrollmentMode: VoiceEnrollmentMode = .quick
    private var recordingTimer: Timer?
    private var synthesisTask: Task<Void, Never>?
    private var downloadTask: Task<Void, Never>?
    private var audioPlayer: AVAudioPlayer?
    private var playbackTimer: Timer?
    private var generatedAudioURL: URL?
    private var profile = VoiceProfileStore.load()
    private var voiceFeedback: String?
    private var modelFeedback: String?
    private var generationFeedback: String?

    private let profileStatusLabel = NSTextField(wrappingLabelWithString: "")
    private let voiceNameField = NSTextField(string: "My Voice")
    private let enrollmentModeDetailLabel = NSTextField(wrappingLabelWithString: "")
    private let scriptView = NSTextView()
    private let consentCheckbox = NSButton(checkboxWithTitle: "I’m using my own voice and want Kiki to keep this recording private on this Mac.", target: nil, action: nil)
    private lazy var recordButton = KikiActionButton("Start Recording", kind: .primary, target: self, action: #selector(toggleRecording))
    private lazy var saveVoiceButton = KikiActionButton("Save Voice", kind: .primary, target: self, action: #selector(saveVoice))
    private lazy var playReferenceButton = KikiActionButton("Play Preview", kind: .secondary, target: self, action: #selector(playReference))
    private lazy var deleteVoiceButton = KikiActionButton("Delete Voice", kind: .secondary, target: self, action: #selector(deleteVoice))
    private let recordingTimeLabel = NSTextField(labelWithString: "00:00")
    private let recordingMeter = NSProgressIndicator()
    private let qualityLabel = NSTextField(wrappingLabelWithString: "Read all three sentences exactly as written in a quiet room.")

    private let modelStatusLabel = NSTextField(wrappingLabelWithString: "")
    private lazy var modelButton = KikiActionButton("Install Voice Engine (2 GB)", kind: .secondary, target: self, action: #selector(toggleModelDownload))
    private let modelProgress = NSProgressIndicator()

    private let editor = NSTextView()
    private let setupStatusLabel = NSTextField(wrappingLabelWithString: "")
    private let characterCountLabel = NSTextField(labelWithString: "0 characters")
    private lazy var generateButton = KikiActionButton("Generate in My Voice", kind: .primary, target: self, action: #selector(generateSpeech))
    private lazy var cancelButton = KikiActionButton("Cancel", kind: .secondary, target: self, action: #selector(cancelGeneration))
    private let generationProgress = NSProgressIndicator()
    private let generationStatusLabel = NSTextField(wrappingLabelWithString: "Type or paste anything for Kiki to read in your voice.")

    private lazy var playOutputButton = KikiActionButton("Play", kind: .secondary, target: self, action: #selector(toggleOutputPlayback))
    private lazy var exportButton = KikiActionButton("Export Audio", kind: .primary, target: self, action: #selector(exportAudio))
    private lazy var revealButton = KikiActionButton("Show in Finder", kind: .quiet, target: self, action: #selector(revealAudio))
    private let playbackLabel = NSTextField(labelWithString: "No audio generated yet")
    private let playbackProgress = NSProgressIndicator()
    private let exportFormatPopup = NSPopUpButton()
    private let workflowRail = VoiceStudioWorkflowRail()

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1080, height: 930),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Kiki Voice Studio"
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = false
        window.minSize = NSSize(width: 1020, height: 930)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        selectedEnrollmentMode = .quick
        window.delegate = self
        buildContent()
        refreshState()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show(prefilledText: String? = nil) {
        prepareForEmbeddedDisplay(prefilledText: prefilledText)
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func prepareForEmbeddedDisplay(prefilledText: String? = nil) {
        profile = VoiceProfileStore.load()
        selectedEnrollmentMode = .quick
        updateEnrollmentModePresentation()
        if let prefilledText { prefillEditor(prefilledText) }
        refreshState()
    }

    var preventsWorkbenchClose: Bool { recordingStartedAt != nil }

    func prefillForDiagnostics(_ text: String) {
        prefillEditor(text)
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if recordingStartedAt != nil {
            qualityLabel.stringValue = "Stop the voice recording before closing Voice Studio."
            return false
        }
        return true
    }

    private func buildContent() {
        guard let content = window?.contentView else { return }
        let backdrop = KikiBackdropView()
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(backdrop)
        NSLayoutConstraint.activate([
            backdrop.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            backdrop.topAnchor.constraint(equalTo: content.topAnchor),
            backdrop.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])

        let artwork = KikiDecorativeImageView()
        artwork.identifier = NSUserInterfaceItemIdentifier("kiki.voice.studio-hero-artwork")
        if let url = Bundle.main.url(forResource: "VoiceStudioHero", withExtension: "png") {
            artwork.image = NSImage(contentsOf: url)
        }
        artwork.imageScaling = .scaleProportionallyUpOrDown
        artwork.imageAlignment = .alignTopRight
        artwork.translatesAutoresizingMaskIntoConstraints = false
        let eyebrow = kikiLabel("VOICE STUDIO · FULLY LOCAL", size: 10, weight: .bold, color: KikiPalette.accentText)
        let title = kikiLabel("Record, shape, and create", size: 27, weight: .bold)
        let subtitle = kikiLabel("Professional voice recording with local intelligence. Everything stays on this Mac.", size: 13, color: KikiPalette.secondaryText)
        let headerText = NSStackView(views: [eyebrow, title, subtitle])
        headerText.identifier = NSUserInterfaceItemIdentifier("kiki.voice.studio-hero-copy")
        headerText.orientation = .vertical
        headerText.alignment = .leading
        headerText.spacing = 7
        headerText.translatesAutoresizingMaskIntoConstraints = false
        let header = KikiCardView()
        header.identifier = NSUserInterfaceItemIdentifier("kiki.voice.studio-hero")
        header.layer?.masksToBounds = true
        header.addSubview(artwork)
        header.addSubview(headerText)
        NSLayoutConstraint.activate([
            artwork.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -24),
            artwork.topAnchor.constraint(equalTo: header.topAnchor),
            artwork.widthAnchor.constraint(equalToConstant: 430),
            artwork.heightAnchor.constraint(equalToConstant: 158),
            headerText.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 24),
            headerText.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            subtitle.widthAnchor.constraint(equalToConstant: 310),
        ])

        let voiceCard = makeVoiceCard()
        let modelCard = makeModelCard()
        let generationCard = makeGenerationCard()
        let rightColumn = NSStackView(views: [modelCard, generationCard])
        rightColumn.orientation = .vertical
        rightColumn.alignment = .leading
        rightColumn.spacing = 14
        let columns = NSStackView(views: [voiceCard, rightColumn])
        columns.orientation = .horizontal
        columns.alignment = .top
        columns.distribution = .fillEqually
        columns.spacing = 18

        workflowRail.identifier = NSUserInterfaceItemIdentifier("kiki.voice.workflow")
        let root = NSStackView(views: [header, workflowRail, columns])
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = KikiMetrics.space3
        root.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(root)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: KikiMetrics.space5),
            root.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -KikiMetrics.space5),
            root.topAnchor.constraint(equalTo: content.topAnchor, constant: KikiMetrics.space6),
            root.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -KikiMetrics.space5),
            header.widthAnchor.constraint(equalTo: root.widthAnchor),
            header.heightAnchor.constraint(equalToConstant: 150),
            workflowRail.widthAnchor.constraint(equalTo: root.widthAnchor),
            workflowRail.heightAnchor.constraint(equalToConstant: 72),
            columns.widthAnchor.constraint(equalTo: root.widthAnchor),
            columns.heightAnchor.constraint(equalTo: root.heightAnchor, constant: -246),
            voiceCard.widthAnchor.constraint(equalTo: rightColumn.widthAnchor),
            voiceCard.heightAnchor.constraint(equalTo: columns.heightAnchor),
            rightColumn.heightAnchor.constraint(equalTo: columns.heightAnchor),
            modelCard.widthAnchor.constraint(equalTo: rightColumn.widthAnchor),
            modelCard.heightAnchor.constraint(equalToConstant: 144),
            generationCard.widthAnchor.constraint(equalTo: rightColumn.widthAnchor),
        ])
    }

    private func makeVoiceCard() -> NSView {
        let card = KikiCardView()
        let sectionTitle = kikiLabel("1. Record your voice", size: 18, weight: .bold)
        let sectionDetail = kikiLabel("Read the short passage once. Kiki keeps this reference recording private on this Mac.", size: 12, color: KikiPalette.secondaryText)
        sectionDetail.maximumNumberOfLines = 2
        profileStatusLabel.font = .systemFont(ofSize: 12.5)
        profileStatusLabel.textColor = KikiPalette.secondaryText
        profileStatusLabel.maximumNumberOfLines = 3

        voiceNameField.placeholderString = "Voice name"
        voiceNameField.font = .systemFont(ofSize: 13.5, weight: .medium)
        voiceNameField.bezelStyle = .roundedBezel

        enrollmentModeDetailLabel.identifier = NSUserInterfaceItemIdentifier("kiki.voice.enrollment-explanation")
        enrollmentModeDetailLabel.font = .systemFont(ofSize: 11.5, weight: .medium)
        enrollmentModeDetailLabel.textColor = KikiPalette.secondaryText
        enrollmentModeDetailLabel.maximumNumberOfLines = 3

        scriptView.identifier = NSUserInterfaceItemIdentifier("kiki.voice.enrollment-script")
        scriptView.isEditable = false
        scriptView.isSelectable = true
        scriptView.drawsBackground = false
        scriptView.textContainerInset = NSSize(width: 12, height: 10)
        scriptView.isVerticallyResizable = true
        scriptView.isHorizontallyResizable = false
        scriptView.autoresizingMask = [.width]
        scriptView.textContainer?.widthTracksTextView = true
        scriptView.setAccessibilityLabel("Voice enrollment passage")

        let scriptScroll = KikiScrollView()
        scriptScroll.fillsBackground = false
        scriptScroll.drawsBackground = false
        scriptScroll.borderType = .noBorder
        scriptScroll.hasVerticalScroller = true
        scriptScroll.autohidesScrollers = true
        scriptScroll.documentView = scriptView
        let scriptPanel = KikiInsetPanelView()
        scriptPanel.identifier = NSUserInterfaceItemIdentifier("kiki.voice.enrollment-panel")
        scriptScroll.translatesAutoresizingMaskIntoConstraints = false
        scriptPanel.addSubview(scriptScroll)
        NSLayoutConstraint.activate([
            scriptScroll.leadingAnchor.constraint(equalTo: scriptPanel.leadingAnchor),
            scriptScroll.trailingAnchor.constraint(equalTo: scriptPanel.trailingAnchor),
            scriptScroll.topAnchor.constraint(equalTo: scriptPanel.topAnchor),
            scriptScroll.bottomAnchor.constraint(equalTo: scriptPanel.bottomAnchor),
        ])
        updateEnrollmentModePresentation()

        consentCheckbox.target = self
        consentCheckbox.action = #selector(consentChanged)
        consentCheckbox.identifier = NSUserInterfaceItemIdentifier("kiki.voice.consent")
        consentCheckbox.font = .systemFont(ofSize: 11.5)
        consentCheckbox.contentTintColor = KikiPalette.accentText
        consentCheckbox.lineBreakMode = .byWordWrapping
        consentCheckbox.cell?.wraps = true
        consentCheckbox.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        recordingTimeLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .semibold)
        recordingTimeLabel.textColor = KikiPalette.secondaryText
        recordingMeter.style = .bar
        recordingMeter.minValue = 0
        recordingMeter.maxValue = 1
        recordingMeter.doubleValue = 0
        recordingMeter.controlSize = .small
        let meterRow = NSStackView(views: [recordingTimeLabel, recordingMeter])
        meterRow.orientation = .horizontal
        meterRow.alignment = .centerY
        meterRow.spacing = 10
        qualityLabel.font = .systemFont(ofSize: 11.5)
        qualityLabel.textColor = KikiPalette.secondaryText
        qualityLabel.maximumNumberOfLines = 2

        saveVoiceButton.isHidden = true
        playReferenceButton.isHidden = true
        let recordingReviewActions = NSStackView(views: [saveVoiceButton, playReferenceButton, deleteVoiceButton, NSView()])
        recordingReviewActions.orientation = .horizontal
        recordingReviewActions.alignment = .centerY
        recordingReviewActions.spacing = 8
        let recordingActions = NSStackView(views: [recordButton, recordingReviewActions])
        recordingActions.orientation = .vertical
        recordingActions.alignment = .leading
        recordingActions.spacing = 8
        recordButton.setContentHuggingPriority(.defaultLow, for: .horizontal)
        recordingReviewActions.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let stack = NSStackView(views: [
            sectionTitle, sectionDetail, profileStatusLabel, voiceNameField,
            enrollmentModeDetailLabel, scriptPanel, consentCheckbox,
            meterRow, qualityLabel, recordingActions,
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),
            sectionDetail.widthAnchor.constraint(equalTo: stack.widthAnchor),
            profileStatusLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            voiceNameField.widthAnchor.constraint(equalTo: stack.widthAnchor),
            enrollmentModeDetailLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            scriptPanel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            scriptPanel.heightAnchor.constraint(equalToConstant: 126),
            consentCheckbox.widthAnchor.constraint(equalTo: stack.widthAnchor),
            meterRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            recordingMeter.widthAnchor.constraint(greaterThanOrEqualToConstant: 220),
            qualityLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            recordingActions.widthAnchor.constraint(equalTo: stack.widthAnchor),
            recordButton.widthAnchor.constraint(equalTo: recordingActions.widthAnchor),
            recordingReviewActions.widthAnchor.constraint(equalTo: recordingActions.widthAnchor),
        ])
        return card
    }

    private func makeModelCard() -> NSView {
        let card = KikiCardView()
        card.identifier = NSUserInterfaceItemIdentifier("kiki.voice.engine-card")
        let title = kikiLabel("2. Install the voice engine", size: 16, weight: .semibold)
        modelStatusLabel.font = .systemFont(ofSize: 11.5)
        modelStatusLabel.textColor = KikiPalette.secondaryText
        modelStatusLabel.maximumNumberOfLines = 2
        modelProgress.style = .bar
        modelProgress.minValue = 0
        modelProgress.maxValue = 1
        modelProgress.isHidden = true
        modelProgress.controlSize = .small
        let actions = NSStackView(views: [modelButton, NSView()])
        actions.orientation = .horizontal
        actions.alignment = .centerY
        actions.spacing = 8
        let stack = NSStackView(views: [title, modelStatusLabel, modelProgress, actions])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 7
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: card.bottomAnchor, constant: -14),
            modelStatusLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            modelProgress.widthAnchor.constraint(equalTo: stack.widthAnchor),
            actions.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
        return card
    }

    private func updateEnrollmentModePresentation() {
        selectedEnrollmentMode = .quick
        enrollmentModeDetailLabel.stringValue = selectedEnrollmentMode.explanation

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3
        paragraph.paragraphSpacing = 8
        paragraph.lineBreakMode = .byWordWrapping
        scriptView.textStorage?.setAttributedString(NSAttributedString(
            string: selectedEnrollmentMode.script,
            attributes: [
                .font: NSFont.systemFont(ofSize: 15, weight: .regular),
                .foregroundColor: KikiPalette.primaryText,
                .paragraphStyle: paragraph,
            ]
        ))
        scriptView.scrollToBeginningOfDocument(nil)
    }

    private func makeGenerationCard() -> NSView {
        let card = KikiCardView()
        let sectionTitle = kikiLabel("3. Write and generate", size: 18, weight: .bold)
        let sectionDetail = kikiLabel("Write, paste, or edit a script. Kiki keeps normal-length text in one continuous take.", size: 12, color: KikiPalette.secondaryText)

        setupStatusLabel.font = .systemFont(ofSize: 12.5, weight: .semibold)
        setupStatusLabel.maximumNumberOfLines = 2

        editor.isEditable = true
        editor.identifier = NSUserInterfaceItemIdentifier("kiki.voice.generation-editor")
        editor.isRichText = false
        editor.isAutomaticQuoteSubstitutionEnabled = true
        editor.isAutomaticDashSubstitutionEnabled = true
        editor.font = .systemFont(ofSize: 15)
        editor.textColor = KikiPalette.primaryText
        editor.insertionPointColor = KikiPalette.accentText
        editor.backgroundColor = KikiPalette.canvas.withAlphaComponent(0.52)
        editor.textContainerInset = NSSize(width: 16, height: 16)
        editor.delegate = self
        let editorScroll = KikiScrollView()
        editorScroll.documentView = editor
        editorScroll.hasVerticalScroller = true
        editorScroll.wantsLayer = true
        editorScroll.layer?.backgroundColor = KikiPalette.canvas.withAlphaComponent(0.52).cgColor
        editorScroll.layer?.borderWidth = 1
        editorScroll.layer?.borderColor = KikiPalette.stroke.cgColor

        characterCountLabel.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        characterCountLabel.textColor = KikiPalette.tertiaryText
        generationProgress.style = .bar
        generationProgress.minValue = 0
        generationProgress.maxValue = 1
        generationProgress.isHidden = true
        generationStatusLabel.font = .systemFont(ofSize: 12)
        generationStatusLabel.textColor = KikiPalette.secondaryText
        generationStatusLabel.maximumNumberOfLines = 2
        cancelButton.isHidden = true
        let generationActions = NSStackView(views: [generateButton, cancelButton, NSView(), characterCountLabel])
        generationActions.orientation = .horizontal
        generationActions.alignment = .centerY
        generationActions.spacing = 8

        let outputCard = KikiCardView()
        let outputTitle = kikiLabel("4. Review and export", size: 13.5, weight: .semibold)
        playbackLabel.font = .systemFont(ofSize: 11.5)
        playbackLabel.textColor = KikiPalette.secondaryText
        playbackProgress.style = .bar
        playbackProgress.minValue = 0
        playbackProgress.maxValue = 1
        playbackProgress.doubleValue = 0
        exportFormatPopup.addItems(withTitles: ["WAV", "M4A"])
        exportFormatPopup.controlSize = .large
        let outputActions = NSStackView(views: [playOutputButton, exportButton, exportFormatPopup, revealButton, NSView()])
        outputActions.orientation = .horizontal
        outputActions.alignment = .centerY
        outputActions.spacing = 8
        let outputStack = NSStackView(views: [outputTitle, playbackLabel, playbackProgress, outputActions])
        outputStack.orientation = .vertical
        outputStack.alignment = .leading
        outputStack.spacing = 9
        outputStack.translatesAutoresizingMaskIntoConstraints = false
        outputCard.addSubview(outputStack)
        NSLayoutConstraint.activate([
            outputStack.leadingAnchor.constraint(equalTo: outputCard.leadingAnchor, constant: 16),
            outputStack.trailingAnchor.constraint(equalTo: outputCard.trailingAnchor, constant: -16),
            outputStack.topAnchor.constraint(equalTo: outputCard.topAnchor, constant: 14),
            outputStack.bottomAnchor.constraint(equalTo: outputCard.bottomAnchor, constant: -14),
            playbackProgress.widthAnchor.constraint(equalTo: outputStack.widthAnchor),
            outputActions.widthAnchor.constraint(equalTo: outputStack.widthAnchor),
        ])

        let privacy = kikiLabel("Private by design · Voice, text, and generated audio stay on this Mac.", size: 11, color: KikiPalette.tertiaryText)
        let stack = NSStackView(views: [
            sectionTitle, sectionDetail, setupStatusLabel, editorScroll, generationActions,
            generationProgress, generationStatusLabel, outputCard, privacy,
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 9
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 20),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -18),
            sectionDetail.widthAnchor.constraint(equalTo: stack.widthAnchor),
            setupStatusLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            editorScroll.widthAnchor.constraint(equalTo: stack.widthAnchor),
            editorScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 132),
            generationActions.widthAnchor.constraint(equalTo: stack.widthAnchor),
            generationProgress.widthAnchor.constraint(equalTo: stack.widthAnchor),
            generationStatusLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            outputCard.widthAnchor.constraint(equalTo: stack.widthAnchor),
            outputCard.heightAnchor.constraint(equalToConstant: 130),
        ])
        return card
    }

    private func refreshState() {
        let hasProfile = profile != nil
        let hasUsableProfile = profile?.isGenerationCompatible == true
        if let profile {
            if hasUsableProfile {
                profileStatusLabel.stringValue = "✓ \(profile.name) is saved and ready · \(Int(profile.duration.rounded())) seconds · \(profile.createdAt.formatted(date: .abbreviated, time: .omitted))"
            } else {
                profileStatusLabel.stringValue = "New voice sample needed · the older recording can repeat its setup script."
            }
            voiceNameField.stringValue = profile.name
            qualityLabel.stringValue = voiceFeedback ?? (hasUsableProfile
                ? (VoiceModelStore.isInstalled
                    ? "Ready. Type on the right, then choose Generate in My Voice."
                    : "Next: install the voice engine below. Kiki handles the downloaded files automatically.")
                : "Choose Record Again and read the three short sentences exactly as written.")
            consentCheckbox.state = .on
        } else {
            profileStatusLabel.stringValue = "Record one short, three-sentence sample. It stays private on this Mac."
            if recordingSamples == nil && recordingStartedAt == nil {
                qualityLabel.stringValue = voiceFeedback ?? selectedEnrollmentMode.explanation
            }
        }
        profileStatusLabel.textColor = hasUsableProfile ? KikiPalette.accentText : KikiPalette.secondaryText
        qualityLabel.textColor = voiceFeedback == nil ? KikiPalette.secondaryText : KikiPalette.accentText
        voiceNameField.isEnabled = !hasProfile
        enrollmentModeDetailLabel.alphaValue = hasProfile ? 0.7 : 1
        scriptView.alphaValue = hasProfile ? 0.7 : 1
        consentCheckbox.isEnabled = !hasProfile
        if recordingStartedAt == nil {
            recordButton.title = hasProfile || recordingSamples != nil ? "Record Again" : "Start Recording"
        }
        recordButton.isEnabled = hasProfile || consentCheckbox.state == .on
        saveVoiceButton.isHidden = recordingSamples == nil
        playReferenceButton.isHidden = !hasProfile && recordingSamples == nil
        deleteVoiceButton.isHidden = !hasProfile || recordingSamples != nil

        if VoiceModelStore.isInstalled {
            modelStatusLabel.stringValue = modelFeedback ?? "✓ Installed and ready. Nothing else to open—Kiki uses the engine automatically and stays offline."
            modelButton.title = "Remove Voice Engine…"
            modelButton.isEnabled = downloadTask == nil && synthesisTask == nil
        } else if downloadTask != nil {
            modelButton.title = "Cancel Installation"
            modelButton.isEnabled = true
        } else {
            modelStatusLabel.stringValue = modelFeedback ?? "One-time 2.0 GB download. Kiki installs it here automatically; there is no file you need to open."
            modelButton.title = "Install Voice Engine (2 GB)"
            modelButton.isEnabled = true
        }

        let hasText = !editor.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let isInstalled = VoiceModelStore.isInstalled
        let isGenerating = synthesisTask != nil
        let ready = hasUsableProfile && isInstalled && !isGenerating
        workflowRail.update(
            hasVoice: hasUsableProfile,
            hasEngine: isInstalled,
            isGenerating: isGenerating,
            hasOutput: generatedAudioURL != nil
        )
        generateButton.isEnabled = ready && hasText
        if !isGenerating {
            if !hasUsableProfile {
                setupStatusLabel.stringValue = hasProfile
                    ? "Setup needed · Replace the older recording with the short sample in step 1."
                    : "Setup needed · Record and save your voice in step 1."
                setupStatusLabel.textColor = KikiPalette.secondaryText
                generateButton.title = hasProfile ? "Record New Sample First" : "Save Your Voice First"
                generationStatusLabel.stringValue = generationFeedback ?? "Your text is safe here. Generate unlocks after the short voice sample is saved."
            } else if !isInstalled {
                setupStatusLabel.stringValue = downloadTask == nil
                    ? "Setup needed · Install the voice engine in step 2."
                    : "Installing the voice engine… Generate will unlock automatically."
                setupStatusLabel.textColor = KikiPalette.secondaryText
                generateButton.title = downloadTask == nil ? "Install Voice Engine First" : "Installing Voice Engine…"
                generationStatusLabel.stringValue = generationFeedback ?? "This one-time setup keeps every future generation fully local."
            } else if !hasText {
                setupStatusLabel.stringValue = "✓ My Voice and the local engine are ready."
                setupStatusLabel.textColor = KikiPalette.accentText
                generateButton.title = "Enter Text to Generate"
                generationStatusLabel.stringValue = generationFeedback ?? "Type or paste anything above."
            } else {
                setupStatusLabel.stringValue = "✓ Ready to generate privately on this Mac."
                setupStatusLabel.textColor = KikiPalette.accentText
                generateButton.title = "Generate in My Voice"
                generationStatusLabel.stringValue = generationFeedback ?? "Your audio will appear below when it is ready."
            }
        }
        playOutputButton.isEnabled = generatedAudioURL != nil
        exportButton.isEnabled = generatedAudioURL != nil
        revealButton.isEnabled = generatedAudioURL != nil
    }

    private func prefillEditor(_ text: String) {
        editor.string = text
        editor.setSelectedRange(NSRange(location: 0, length: 0))
        editor.scrollToBeginningOfDocument(nil)
        characterCountLabel.stringValue = "\(text.count.formatted()) characters"
        generationFeedback = "Selection added. Review or edit it, then choose Generate in My Voice."
    }

    @objc private func consentChanged() {
        recordButton.isEnabled = consentCheckbox.state == .on || profile != nil
    }

    @objc private func toggleRecording() {
        if recordingStartedAt != nil { stopRecording() } else { startRecording() }
    }

    private func startRecording() {
        guard consentCheckbox.state == .on else {
            qualityLabel.stringValue = "Confirm that this is your voice before recording."
            return
        }
        stopAnyPlayback()
        voiceFeedback = nil
        recordingSamples = nil
        recordingEnrollmentMode = selectedEnrollmentMode
        saveVoiceButton.isHidden = true
        playReferenceButton.isHidden = true
        recordingMeter.doubleValue = 0
        do {
            recorder.setSamplesHandler { [weak self] samples in
                guard !samples.isEmpty else { return }
                let rms = sqrt(samples.reduce(0.0) { $0 + Double($1 * $1) } / Double(samples.count))
                Task { @MainActor [weak self] in
                    self?.recordingMeter.doubleValue = min(1, rms * 12)
                }
            }
            try recorder.start()
            recordingStartedAt = Date()
            recordButton.title = "Stop Recording"
            qualityLabel.stringValue = "Recording locally… read all three sentences exactly as written, then stop."
            recordingTimeLabel.textColor = .systemRed
            onCaptureStateChange?(true)
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.updateRecordingTimer() }
            }
            updateRecordingTimer()
        } catch {
            recorder.setSamplesHandler(nil)
            recordingEnrollmentMode = nil
            qualityLabel.stringValue = "Could not record: \(error.localizedDescription)"
            onCaptureStateChange?(false)
        }
    }

    private func stopRecording() {
        recorder.setSamplesHandler(nil)
        let samples = recorder.stop()
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingStartedAt = nil
        recordingTimeLabel.textColor = KikiPalette.secondaryText
        recordingMeter.doubleValue = 0
        recordButton.title = profile == nil ? "Record Again" : "Replace Recording"
        onCaptureStateChange?(false)

        let mode = recordingEnrollmentMode ?? selectedEnrollmentMode
        let quality = VoiceProfileStore.recordingQuality(
            samples: samples,
            minimumDuration: mode.minimumDuration,
            maximumDuration: mode.maximumDuration
        )
        qualityLabel.stringValue = quality.message
        recordingSamples = quality.canSave ? samples : nil
        saveVoiceButton.isHidden = !quality.canSave
        playReferenceButton.isHidden = !quality.canSave && profile == nil
        if quality.canSave {
            recordingSamples = samples
            saveVoiceButton.isEnabled = true
        } else {
            recordingEnrollmentMode = nil
        }
    }

    private func updateRecordingTimer() {
        let elapsed = max(0, Int(Date().timeIntervalSince(recordingStartedAt ?? Date())))
        recordingTimeLabel.stringValue = String(format: "%02d:%02d", elapsed / 60, elapsed % 60)
        let maximumDuration = recordingEnrollmentMode?.maximumDuration ?? selectedEnrollmentMode.maximumDuration
        if TimeInterval(elapsed) >= maximumDuration { stopRecording() }
    }

    @objc private func saveVoice() {
        guard let recordingSamples else { return }
        do {
            stopAnyPlayback()
            let mode = recordingEnrollmentMode ?? selectedEnrollmentMode
            profile = try VoiceProfileStore.save(
                samples: recordingSamples,
                name: voiceNameField.stringValue,
                enrollmentMode: mode
            )
            self.recordingSamples = nil
            recordingEnrollmentMode = nil
            voiceFeedback = VoiceModelStore.isInstalled
                ? "✓ Saved. Your voice is ready—type on the right and generate audio."
                : "✓ Saved. Next, install the voice engine below once; Kiki handles the files for you."
            Task { await synthesisEngine.unload() }
            refreshState()
        } catch {
            qualityLabel.stringValue = "Could not save your voice: \(error.localizedDescription)"
        }
    }

    @objc private func playReference() {
        if playReferenceButton.title == "Stop Preview" {
            stopAnyPlayback()
            return
        }
        let url: URL
        if let recordingSamples {
            do {
                url = try VoiceProfileStore.writePreview(samples: recordingSamples)
            } catch {
                qualityLabel.stringValue = "Could not play the recording: \(error.localizedDescription)"
                return
            }
        } else {
            url = VoiceProfileStore.referenceAudioURL
        }
        playAudio(url: url, isOutput: false)
    }

    @objc private func deleteVoice() {
        let alert = NSAlert()
        alert.messageText = "Delete your Kiki voice?"
        alert.informativeText = "The reference recording and local voice profile will be permanently removed from this Mac. Generated audio is kept."
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Delete Voice")
        alert.alertStyle = .warning
        guard alert.runModal() == .alertSecondButtonReturn else { return }
        do {
            stopAnyPlayback()
            try VoiceProfileStore.delete()
            profile = nil
            recordingSamples = nil
            voiceFeedback = nil
            Task { await synthesisEngine.unload() }
            refreshState()
        } catch {
            qualityLabel.stringValue = "Could not delete your voice: \(error.localizedDescription)"
        }
    }

    @objc private func toggleModelDownload() {
        if VoiceModelStore.isInstalled {
            let alert = NSAlert()
            alert.messageText = "Remove the local voice engine?"
            alert.informativeText = "This frees approximately 2.0 GB. Your voice recording and generated audio will remain on this Mac."
            alert.addButton(withTitle: "Cancel")
            alert.addButton(withTitle: "Remove Model")
            alert.alertStyle = .warning
            guard alert.runModal() == .alertSecondButtonReturn else { return }
            Task { [weak self] in
                guard let self else { return }
                await synthesisEngine.unload()
                do {
                    try VoiceModelStore.delete()
                    modelFeedback = "Voice engine removed. Install it again whenever you want to create audio."
                } catch {
                    modelFeedback = "Could not remove the voice engine: \(error.localizedDescription)"
                }
                refreshState()
            }
            return
        }
        if let downloadTask {
            downloadTask.cancel()
            self.downloadTask = nil
            modelProgress.isHidden = true
            modelFeedback = "Installation paused. Kiki will reuse completed files when you resume."
            refreshState()
            return
        }
        modelFeedback = nil
        modelProgress.doubleValue = Double(VoiceModelStore.installedSize) / Double(VoiceModelStore.downloadSize)
        modelProgress.isHidden = false
        modelStatusLabel.stringValue = "Preparing the private voice engine…"
        modelButton.title = "Cancel Installation"
        downloadTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await VoiceModelStore.download { [weak self] progress in
                    guard let self else { return }
                    self.modelProgress.doubleValue = progress.fraction
                    let percent = progress.currentFile == "Complete"
                        ? 100
                        : min(99, Int(floor(progress.fraction * 100)))
                    let fileName = progress.currentFile == "Complete"
                        ? "Finalizing installation"
                        : progress.currentFile.split(separator: "/").last.map(String.init) ?? progress.currentFile
                    if progress.currentFile == "Complete" {
                        self.modelStatusLabel.stringValue = "Finalizing local voice engine…"
                    } else if progress.isDownloading {
                        self.modelStatusLabel.stringValue = "Downloading local voice engine… \(percent)% · \(fileName)"
                    } else {
                        self.modelStatusLabel.stringValue = "Verifying local voice engine… · \(fileName)"
                    }
                }
                self.downloadTask = nil
                self.modelProgress.isHidden = true
                self.modelFeedback = "✓ Voice engine installed. Nothing else to open—Create Audio is ready."
                if self.profile != nil {
                    self.voiceFeedback = "✓ Saved. Your voice is ready—type on the right and generate audio."
                }
                self.refreshState()
            } catch is CancellationError {
                self.downloadTask = nil
                self.modelProgress.isHidden = true
                self.modelFeedback = "Installation paused. Kiki will reuse completed files when you resume."
                self.refreshState()
            } catch {
                self.downloadTask = nil
                self.modelProgress.isHidden = true
                self.modelFeedback = "Installation failed: \(error.localizedDescription)"
                self.refreshState()
            }
        }
    }

    @objc private func generateSpeech() {
        guard let profile else {
            generationStatusLabel.stringValue = "Create your voice first."
            return
        }
        let text = editor.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        stopAnyPlayback()
        generationFeedback = nil
        generatedAudioURL = nil
        generationProgress.doubleValue = 0
        generationProgress.isHidden = false
        generationStatusLabel.stringValue = "Loading the private local voice engine…"
        generateButton.isEnabled = false
        cancelButton.isHidden = false
        editor.isEditable = false

        let task = Task { [weak self] in
            guard let self else { return }
            do {
                self.generationStatusLabel.stringValue = "Verifying the private local voice engine…"
                try await VoiceModelStore.download { [weak self] progress in
                    guard let self else { return }
                    if progress.isDownloading {
                        self.generationProgress.doubleValue = progress.fraction * 0.15
                        let percent = Int((progress.fraction * 100).rounded())
                        self.generationStatusLabel.stringValue = "Repairing local voice engine · \(percent)%"
                    } else if progress.currentFile != "Complete" {
                        self.generationStatusLabel.stringValue = "Verifying the private local voice engine…"
                    }
                }
                try Task.checkCancellation()
                let url = try await synthesisEngine.synthesize(text: text, profile: profile) { [weak self] progress in
                    guard let self else { return }
                    self.generationProgress.doubleValue = 0.15 + progress.fraction * 0.85
                    let current = min(progress.totalChunks, progress.completedChunks + 1)
                    self.generationStatusLabel.stringValue = "Generating locally · section \(current) of \(progress.totalChunks)"
                }
                generatedAudioURL = url
                generationProgress.doubleValue = 1
                generationFeedback = "✓ Audio ready · generated entirely on this Mac. Play it below or export WAV/M4A."
                generationStatusLabel.stringValue = generationFeedback ?? "Audio ready."
                loadOutputAudio(url)
                playAudio(url: url, isOutput: true)
            } catch is CancellationError {
                generationFeedback = "Generation cancelled. Your text is still here."
                generationStatusLabel.stringValue = generationFeedback ?? "Generation cancelled."
            } catch {
                generationFeedback = "Could not generate speech: \(error.localizedDescription)"
                generationStatusLabel.stringValue = generationFeedback ?? "Could not generate speech."
            }
            synthesisTask = nil
            generationProgress.isHidden = true
            cancelButton.isHidden = true
            editor.isEditable = true
            refreshState()
        }
        synthesisTask = task
        refreshState()
    }

    @objc private func cancelGeneration() {
        synthesisTask?.cancel()
        generationStatusLabel.stringValue = "Cancelling local generation…"
    }

    private func loadOutputAudio(_ url: URL) {
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            audioPlayer = player
            playbackLabel.stringValue = "\(url.lastPathComponent) · \(Self.durationString(player.duration))"
            playbackProgress.doubleValue = 0
        } catch {
            generationStatusLabel.stringValue = "Audio generated, but playback could not start: \(error.localizedDescription)"
        }
    }

    private func playAudio(url: URL, isOutput: Bool) {
        stopAnyPlayback()
        if isOutput, audioPlayer != nil {
            audioPlayer?.currentTime = 0
        } else {
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                audioPlayer = player
            } catch {
                qualityLabel.stringValue = "Could not play audio: \(error.localizedDescription)"
                return
            }
        }
        audioPlayer?.play()
        if isOutput {
            playOutputButton.title = "Pause"
        } else {
            playReferenceButton.title = "Stop Preview"
        }
        startPlaybackTimer(isOutput: isOutput)
    }

    @objc private func toggleOutputPlayback() {
        guard let url = generatedAudioURL else { return }
        if audioPlayer == nil || audioPlayer?.url != url { loadOutputAudio(url) }
        guard let audioPlayer else { return }
        if audioPlayer.isPlaying {
            audioPlayer.pause()
            playOutputButton.title = "Play"
        } else {
            if audioPlayer.currentTime >= audioPlayer.duration { audioPlayer.currentTime = 0 }
            audioPlayer.play()
            playOutputButton.title = "Pause"
            startPlaybackTimer(isOutput: true)
        }
    }

    private func startPlaybackTimer(isOutput: Bool) {
        playbackTimer?.invalidate()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let player = self.audioPlayer, player.duration > 0 else { return }
                if isOutput {
                    self.playbackProgress.doubleValue = player.currentTime / player.duration
                }
                if !player.isPlaying {
                    self.playbackTimer?.invalidate()
                    self.playbackTimer = nil
                    if isOutput {
                        self.playOutputButton.title = "Play"
                        if player.currentTime >= player.duration - 0.05 {
                            self.playbackProgress.doubleValue = 1
                        }
                    } else {
                        self.playReferenceButton.title = "Play Preview"
                    }
                }
            }
        }
    }

    private func stopAnyPlayback() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        playbackTimer?.invalidate()
        playbackTimer = nil
        playReferenceButton.title = "Play Preview"
        playOutputButton.title = "Play"
    }

    @objc private func exportAudio() {
        guard let source = generatedAudioURL else { return }
        let isM4A = exportFormatPopup.indexOfSelectedItem == 1
        let panel = NSSavePanel()
        panel.allowedContentTypes = isM4A ? [.mpeg4Audio] : [.wav]
        panel.nameFieldStringValue = isM4A ? "Kiki Voice.m4a" : "Kiki Voice.wav"
        panel.message = "Export audio generated locally by Kiki."
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                if isM4A {
                    try await Self.exportM4A(source: source, destination: destination)
                } else {
                    try? FileManager.default.removeItem(at: destination)
                    try FileManager.default.copyItem(at: source, to: destination)
                }
                generationStatusLabel.stringValue = "Exported \(destination.lastPathComponent)"
            } catch {
                generationStatusLabel.stringValue = "Could not export audio: \(error.localizedDescription)"
            }
        }
    }

    @objc private func revealAudio() {
        guard let generatedAudioURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([generatedAudioURL])
    }

    private static func exportM4A(source: URL, destination: URL) async throws {
        try? FileManager.default.removeItem(at: destination)
        let asset = AVURLAsset(url: source)
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw KikiError("Kiki could not prepare M4A export.")
        }
        session.outputURL = destination
        session.outputFileType = .m4a
        let provenance = AVMutableMetadataItem()
        provenance.identifier = .commonIdentifierDescription
        provenance.value = "AI-generated speech created locally with Kiki Voice Studio" as NSString
        session.metadata = [provenance]
        let box = SendableAudioExportSession(session)
        try await withCheckedThrowingContinuation { continuation in
            box.session.exportAsynchronously {
                switch box.session.status {
                case .completed: continuation.resume()
                case .cancelled: continuation.resume(throwing: CancellationError())
                default: continuation.resume(throwing: box.session.error ?? KikiError("M4A export failed."))
                }
            }
        }
    }

    private static func durationString(_ duration: TimeInterval) -> String {
        let total = max(0, Int(duration.rounded()))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

@MainActor
private final class VoiceStudioWorkflowRail: NSStackView {
    private let voiceStep = VoiceStudioWorkflowStep(number: 1, title: "Record voice", identifier: "record")
    private let engineStep = VoiceStudioWorkflowStep(number: 2, title: "Install engine", identifier: "engine")
    private let createStep = VoiceStudioWorkflowStep(number: 3, title: "Create audio", identifier: "create")
    private let outputStep = VoiceStudioWorkflowStep(number: 4, title: "Review & export", identifier: "output")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        orientation = .horizontal
        alignment = .centerY
        distribution = .fillEqually
        spacing = 10
        for step in [voiceStep, engineStep, createStep, outputStep] {
            addArrangedSubview(step)
            step.heightAnchor.constraint(equalTo: heightAnchor).isActive = true
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(hasVoice: Bool, hasEngine: Bool, isGenerating: Bool, hasOutput: Bool) {
        voiceStep.update(state: hasVoice ? .complete : .current, status: hasVoice ? "Saved" : "Start here")
        engineStep.update(
            state: hasEngine ? .complete : hasVoice ? .current : .upcoming,
            status: hasEngine ? "Installed" : hasVoice ? "Next" : "After voice"
        )
        let createState: VoiceStudioWorkflowStep.State = if isGenerating {
            .current
        } else if hasOutput {
            .complete
        } else if hasVoice && hasEngine {
            .current
        } else {
            .upcoming
        }
        createStep.update(
            state: createState,
            status: isGenerating ? "Generating" : hasOutput ? "Generated" : hasVoice && hasEngine ? "Ready" : "Locked"
        )
        outputStep.update(
            state: hasOutput && !isGenerating ? .current : .upcoming,
            status: isGenerating ? "Updating" : hasOutput ? "Audio ready" : "Waiting"
        )
    }
}

@MainActor
private final class VoiceStudioWorkflowStep: KikiCardView {
    enum State { case complete, current, upcoming }

    private let numberLabel: NSTextField
    private let titleLabel: NSTextField
    private let statusLabel = kikiLabel("", size: 10.5, weight: .semibold, color: KikiPalette.tertiaryText)
    private let stepNumber: Int

    init(number: Int, title: String, identifier: String) {
        stepNumber = number
        numberLabel = kikiLabel(String(number), size: 11, weight: .bold, color: KikiPalette.accentText)
        titleLabel = kikiLabel(title, size: 12.5, weight: .semibold)
        super.init(frame: .zero)
        self.identifier = NSUserInterfaceItemIdentifier("kiki.voice.workflow.\(identifier)")
        usesHardwareDepth = true
        cardCornerRadius = 8

        numberLabel.alignment = .center
        numberLabel.wantsLayer = true
        numberLabel.layer?.cornerRadius = 11
        numberLabel.layer?.borderWidth = 1
        numberLabel.layer?.borderColor = KikiPalette.strongStroke.cgColor
        numberLabel.layer?.backgroundColor = KikiPalette.elevatedSurface.cgColor
        numberLabel.widthAnchor.constraint(equalToConstant: 22).isActive = true
        numberLabel.heightAnchor.constraint(equalToConstant: 22).isActive = true
        titleLabel.lineBreakMode = .byTruncatingTail
        let copy = NSStackView(views: [titleLabel, statusLabel])
        copy.orientation = .vertical
        copy.alignment = .leading
        copy.spacing = 2
        let row = NSStackView(views: [numberLabel, copy])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 9
        row.translatesAutoresizingMaskIntoConstraints = false
        addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            row.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -10),
            row.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        setAccessibilityLabel("Step \(number), \(title)")
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(state: State, status: String) {
        statusLabel.stringValue = status
        switch state {
        case .complete:
            selected = false
            numberLabel.stringValue = "✓"
            numberLabel.textColor = KikiPalette.accentText
            numberLabel.layer?.backgroundColor = KikiPalette.elevatedSurface.cgColor
            statusLabel.textColor = KikiPalette.accentText
        case .current:
            selected = true
            numberLabel.stringValue = String(stepNumber)
            numberLabel.textColor = KikiPalette.onAccentText
            numberLabel.layer?.backgroundColor = KikiPalette.accent.cgColor
            statusLabel.textColor = KikiPalette.khaki
        case .upcoming:
            selected = false
            numberLabel.stringValue = String(stepNumber)
            numberLabel.textColor = KikiPalette.tertiaryText
            numberLabel.layer?.backgroundColor = KikiPalette.elevatedSurface.cgColor
            statusLabel.textColor = KikiPalette.tertiaryText
        }
        setAccessibilityValue(status)
    }
}

private final class SendableAudioExportSession: @unchecked Sendable {
    let session: AVAssetExportSession
    init(_ session: AVAssetExportSession) { self.session = session }
}

extension VoiceStudioWindowController: NSTextViewDelegate {
    func textDidChange(_ notification: Notification) {
        characterCountLabel.stringValue = "\(editor.string.count.formatted()) characters"
        generationFeedback = nil
        refreshState()
    }
}
