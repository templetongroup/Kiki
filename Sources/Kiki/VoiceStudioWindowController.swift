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
    private lazy var enrollmentModeControl = NSSegmentedControl(
        labels: VoiceEnrollmentMode.allCases.map(\.displayName),
        trackingMode: .selectOne,
        target: self,
        action: #selector(enrollmentModeChanged)
    )
    private let enrollmentModeDetailLabel = NSTextField(wrappingLabelWithString: "")
    private let scriptView = NSTextView()
    private let consentCheckbox = NSButton(checkboxWithTitle: "I’m using my own voice and want Kiki to keep this recording private on this Mac.", target: nil, action: nil)
    private lazy var recordButton = KikiActionButton("Start Recording", kind: .primary, target: self, action: #selector(toggleRecording))
    private lazy var saveVoiceButton = KikiActionButton("Save Voice", kind: .primary, target: self, action: #selector(saveVoice))
    private lazy var playReferenceButton = KikiActionButton("Play Preview", kind: .secondary, target: self, action: #selector(playReference))
    private lazy var deleteVoiceButton = KikiActionButton("Delete Voice", kind: .quiet, target: self, action: #selector(deleteVoice))
    private let recordingTimeLabel = NSTextField(labelWithString: "00:00")
    private let recordingMeter = NSProgressIndicator()
    private let qualityLabel = NSTextField(wrappingLabelWithString: "Read naturally in a quiet room. Aim for 30–60 seconds.")

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
        selectedEnrollmentMode = profile?.enrollmentMode ?? .quick
        window.delegate = self
        buildContent()
        refreshState()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show() {
        profile = VoiceProfileStore.load()
        selectedEnrollmentMode = profile?.enrollmentMode ?? selectedEnrollmentMode
        updateEnrollmentModePresentation()
        refreshState()
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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

        let artwork = NSImageView()
        artwork.identifier = NSUserInterfaceItemIdentifier("kiki.voice.studio-hero-artwork")
        if let url = Bundle.main.url(forResource: "VoiceStudioHero", withExtension: "png") {
            artwork.image = NSImage(contentsOf: url)
        }
        artwork.imageScaling = .scaleProportionallyUpOrDown
        artwork.imageAlignment = .alignTopRight
        artwork.translatesAutoresizingMaskIntoConstraints = false
        let eyebrow = kikiLabel("VOICE STUDIO · FULLY LOCAL", size: 10, weight: .bold, color: KikiPalette.accentText)
        let title = kikiLabel("Kiki is ready", size: 30, weight: .bold)
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
            artwork.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -35),
            artwork.topAnchor.constraint(equalTo: header.topAnchor, constant: 2),
            artwork.widthAnchor.constraint(equalToConstant: 615),
            artwork.heightAnchor.constraint(equalToConstant: 228),
            headerText.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 28),
            headerText.centerYAnchor.constraint(equalTo: header.centerYAnchor),
            subtitle.widthAnchor.constraint(equalToConstant: 310),
        ])

        let leftCard = makeVoiceCard()
        let rightCard = makeGenerationCard()
        let columns = NSStackView(views: [leftCard, rightCard])
        columns.orientation = .horizontal
        columns.alignment = .top
        columns.distribution = .fill
        columns.spacing = 18

        let root = NSStackView(views: [header, columns])
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 16
        root.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(root)

        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 30),
            root.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -30),
            root.topAnchor.constraint(equalTo: content.topAnchor, constant: 46),
            root.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -26),
            header.widthAnchor.constraint(equalTo: root.widthAnchor),
            header.heightAnchor.constraint(equalToConstant: 230),
            columns.widthAnchor.constraint(equalTo: root.widthAnchor),
            columns.heightAnchor.constraint(equalTo: root.heightAnchor, constant: -246),
            leftCard.widthAnchor.constraint(equalToConstant: 450),
            rightCard.widthAnchor.constraint(greaterThanOrEqualToConstant: 480),
            rightCard.heightAnchor.constraint(equalTo: columns.heightAnchor),
            leftCard.heightAnchor.constraint(equalTo: columns.heightAnchor),
        ])
    }

    private func makeVoiceCard() -> NSView {
        let card = KikiCardView()
        card.showsFasteners = true
        let sectionTitle = kikiLabel("1. Record your voice", size: 18, weight: .bold)
        profileStatusLabel.font = .systemFont(ofSize: 12.5)
        profileStatusLabel.textColor = KikiPalette.secondaryText
        profileStatusLabel.maximumNumberOfLines = 3

        voiceNameField.placeholderString = "Voice name"
        voiceNameField.font = .systemFont(ofSize: 13.5, weight: .medium)
        voiceNameField.bezelStyle = .roundedBezel

        enrollmentModeControl.identifier = NSUserInterfaceItemIdentifier("kiki.voice.enrollment-mode")
        enrollmentModeControl.setAccessibilityLabel("Voice setup length")
        enrollmentModeControl.segmentStyle = .rounded
        enrollmentModeControl.selectedSegmentBezelColor = KikiPalette.accent
        enrollmentModeControl.setContentHuggingPriority(.required, for: .horizontal)

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
        scriptScroll.drawsBackground = false
        scriptScroll.borderType = .noBorder
        scriptScroll.hasVerticalScroller = true
        scriptScroll.autohidesScrollers = true
        scriptScroll.documentView = scriptView
        let scriptPanel = NSView()
        scriptPanel.wantsLayer = true
        scriptPanel.layer?.cornerRadius = 12
        scriptPanel.layer?.cornerCurve = .continuous
        scriptPanel.layer?.backgroundColor = KikiPalette.canvas.withAlphaComponent(0.52).cgColor
        scriptPanel.layer?.borderWidth = 1
        scriptPanel.layer?.borderColor = KikiPalette.stroke.cgColor
        scriptPanel.layer?.masksToBounds = true
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
        consentCheckbox.contentTintColor = KikiPalette.accent
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

        let divider = NSBox()
        divider.boxType = .separator
        let modelTitle = kikiLabel("2. Install the voice engine", size: 13.5, weight: .semibold)
        modelStatusLabel.font = .systemFont(ofSize: 11.5)
        modelStatusLabel.textColor = KikiPalette.secondaryText
        modelStatusLabel.maximumNumberOfLines = 2
        modelProgress.style = .bar
        modelProgress.minValue = 0
        modelProgress.maxValue = 1
        modelProgress.isHidden = true
        modelProgress.controlSize = .small
        let modelActions = NSStackView(views: [modelButton, NSView()])
        modelActions.orientation = .horizontal
        modelActions.alignment = .centerY
        modelActions.spacing = 8

        let stack = NSStackView(views: [
            sectionTitle, profileStatusLabel, voiceNameField, enrollmentModeControl,
            enrollmentModeDetailLabel, scriptPanel, consentCheckbox,
            meterRow, qualityLabel, recordingActions, divider,
            modelTitle, modelStatusLabel, modelProgress, modelActions,
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
            stack.bottomAnchor.constraint(lessThanOrEqualTo: card.bottomAnchor, constant: -18),
            profileStatusLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            voiceNameField.widthAnchor.constraint(equalTo: stack.widthAnchor),
            enrollmentModeDetailLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            scriptPanel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            scriptPanel.heightAnchor.constraint(equalToConstant: 190),
            consentCheckbox.widthAnchor.constraint(equalTo: stack.widthAnchor),
            meterRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            recordingMeter.widthAnchor.constraint(greaterThanOrEqualToConstant: 220),
            qualityLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            recordingActions.widthAnchor.constraint(equalTo: stack.widthAnchor),
            recordButton.widthAnchor.constraint(equalTo: recordingActions.widthAnchor),
            recordingReviewActions.widthAnchor.constraint(equalTo: recordingActions.widthAnchor),
            divider.widthAnchor.constraint(equalTo: stack.widthAnchor),
            modelStatusLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            modelProgress.widthAnchor.constraint(equalTo: stack.widthAnchor),
            modelActions.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
        return card
    }

    private func updateEnrollmentModePresentation() {
        enrollmentModeControl.selectedSegment = VoiceEnrollmentMode.allCases.firstIndex(of: selectedEnrollmentMode) ?? 0
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
        card.showsFasteners = true
        let sectionTitle = kikiLabel("3. Create audio", size: 18, weight: .bold)
        let sectionDetail = kikiLabel("Write, paste, or edit a script. Longer text is generated in natural sections.", size: 12, color: KikiPalette.secondaryText)

        setupStatusLabel.font = .systemFont(ofSize: 12.5, weight: .semibold)
        setupStatusLabel.maximumNumberOfLines = 2

        editor.isEditable = true
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
        let outputTitle = kikiLabel("Generated audio", size: 13.5, weight: .semibold)
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
            editorScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 210),
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
        if let profile {
            let mode = profile.enrollmentMode?.displayName ?? "Quick"
            profileStatusLabel.stringValue = "✓ \(profile.name) is saved and ready · \(mode) setup · \(Int(profile.duration.rounded())) seconds · \(profile.createdAt.formatted(date: .abbreviated, time: .omitted))"
            voiceNameField.stringValue = profile.name
            qualityLabel.stringValue = voiceFeedback ?? (VoiceModelStore.isInstalled
                ? "Ready. Type on the right, then choose Generate in My Voice."
                : "Next: install the voice engine below. Kiki handles the downloaded files automatically.")
            consentCheckbox.state = .on
        } else {
            profileStatusLabel.stringValue = "Choose Quick for faster setup or Full for better accuracy. Either way, your recording stays private on this Mac."
            if recordingSamples == nil && recordingStartedAt == nil {
                qualityLabel.stringValue = voiceFeedback ?? selectedEnrollmentMode.explanation
            }
        }
        profileStatusLabel.textColor = hasProfile ? KikiPalette.accentText : KikiPalette.secondaryText
        qualityLabel.textColor = voiceFeedback == nil ? KikiPalette.secondaryText : KikiPalette.accentText
        voiceNameField.isEnabled = !hasProfile
        enrollmentModeControl.isEnabled = recordingStartedAt == nil && recordingSamples == nil
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
        let ready = hasProfile && isInstalled && !isGenerating
        generateButton.isEnabled = ready && hasText
        if !isGenerating {
            if !hasProfile {
                setupStatusLabel.stringValue = "Setup needed · Record and save your voice in step 1."
                setupStatusLabel.textColor = KikiPalette.secondaryText
                generateButton.title = "Save Your Voice First"
                generationStatusLabel.stringValue = generationFeedback ?? "Your text is safe here. Generate unlocks as soon as your voice is saved."
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

    @objc private func consentChanged() {
        recordButton.isEnabled = consentCheckbox.state == .on || profile != nil
    }

    @objc private func enrollmentModeChanged() {
        guard VoiceEnrollmentMode.allCases.indices.contains(enrollmentModeControl.selectedSegment) else { return }
        selectedEnrollmentMode = VoiceEnrollmentMode.allCases[enrollmentModeControl.selectedSegment]
        voiceFeedback = nil
        updateEnrollmentModePresentation()
        refreshState()
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
        enrollmentModeControl.isEnabled = false
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
            qualityLabel.stringValue = "Recording \(selectedEnrollmentMode.displayName.lowercased()) setup locally… read the complete passage at your normal pace."
            recordingTimeLabel.textColor = .systemRed
            onCaptureStateChange?(true)
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.updateRecordingTimer() }
            }
            updateRecordingTimer()
        } catch {
            recorder.setSamplesHandler(nil)
            recordingEnrollmentMode = nil
            enrollmentModeControl.isEnabled = true
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
            enrollmentModeControl.isEnabled = true
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
                    self.modelStatusLabel.stringValue = "Installing locally… \(percent)% · \(fileName)"
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
                let url = try await synthesisEngine.synthesize(text: text, profile: profile) { [weak self] progress in
                    guard let self else { return }
                    self.generationProgress.doubleValue = progress.fraction
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
