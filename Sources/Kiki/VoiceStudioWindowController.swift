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
    private var recordingTimer: Timer?
    private var synthesisTask: Task<Void, Never>?
    private var downloadTask: Task<Void, Never>?
    private var audioPlayer: AVAudioPlayer?
    private var playbackTimer: Timer?
    private var generatedAudioURL: URL?
    private var profile = VoiceProfileStore.load()

    private let profileStatusLabel = NSTextField(wrappingLabelWithString: "")
    private let voiceNameField = NSTextField(string: "My Voice")
    private let scriptTextView = NSTextView()
    private let consentCheckbox = NSButton(checkboxWithTitle: "This is my voice, and I consent to creating a private local voice model.", target: nil, action: nil)
    private lazy var recordButton = KikiActionButton("Start Voice Recording", kind: .primary, target: self, action: #selector(toggleRecording))
    private lazy var saveVoiceButton = KikiActionButton("Save My Voice", kind: .primary, target: self, action: #selector(saveVoice))
    private lazy var playReferenceButton = KikiActionButton("Play Recording", kind: .secondary, target: self, action: #selector(playReference))
    private lazy var deleteVoiceButton = KikiActionButton("Delete Voice", kind: .quiet, target: self, action: #selector(deleteVoice))
    private let recordingTimeLabel = NSTextField(labelWithString: "00:00")
    private let recordingMeter = NSProgressIndicator()
    private let qualityLabel = NSTextField(wrappingLabelWithString: "Read naturally in a quiet room. Aim for 30–60 seconds.")

    private let modelStatusLabel = NSTextField(wrappingLabelWithString: "")
    private lazy var modelButton = KikiActionButton("Download Local Model", kind: .secondary, target: self, action: #selector(toggleModelDownload))
    private let modelProgress = NSProgressIndicator()

    private let editor = NSTextView()
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
            contentRect: NSRect(x: 0, y: 0, width: 1080, height: 760),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Kiki Voice Studio"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.minSize = NSSize(width: 940, height: 760)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        buildContent()
        refreshState()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show() {
        profile = VoiceProfileStore.load()
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

        let icon = NSImageView()
        if let url = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png") {
            icon.image = NSImage(contentsOf: url)
        }
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.wantsLayer = true
        icon.layer?.cornerRadius = 11
        icon.layer?.masksToBounds = true
        let eyebrow = kikiLabel("VOICE STUDIO · FULLY LOCAL", size: 10, weight: .bold, color: KikiPalette.accentText)
        let title = kikiLabel("Your words. Your voice. Your Mac.", size: 28, weight: .bold)
        let subtitle = kikiLabel("Create a private voice once, turn any text into natural speech, and export the result. Nothing is uploaded.", size: 12.5, color: KikiPalette.secondaryText)
        let headerText = NSStackView(views: [eyebrow, title, subtitle])
        headerText.orientation = .vertical
        headerText.alignment = .leading
        headerText.spacing = 5
        let header = NSStackView(views: [icon, headerText])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 14

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
        root.spacing = 20
        root.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(root)

        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 48),
            icon.heightAnchor.constraint(equalToConstant: 48),
            subtitle.widthAnchor.constraint(lessThanOrEqualToConstant: 820),
            root.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 30),
            root.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -30),
            root.topAnchor.constraint(equalTo: content.topAnchor, constant: 46),
            root.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -26),
            header.widthAnchor.constraint(equalTo: root.widthAnchor),
            columns.widthAnchor.constraint(equalTo: root.widthAnchor),
            columns.heightAnchor.constraint(equalTo: root.heightAnchor, constant: -92),
            leftCard.widthAnchor.constraint(equalToConstant: 390),
            rightCard.widthAnchor.constraint(greaterThanOrEqualToConstant: 480),
            rightCard.heightAnchor.constraint(equalTo: columns.heightAnchor),
            leftCard.heightAnchor.constraint(equalTo: columns.heightAnchor),
        ])
    }

    private func makeVoiceCard() -> NSView {
        let card = KikiCardView()
        let sectionTitle = kikiLabel("My Voice", size: 18, weight: .bold)
        profileStatusLabel.font = .systemFont(ofSize: 12.5)
        profileStatusLabel.textColor = KikiPalette.secondaryText
        profileStatusLabel.maximumNumberOfLines = 3

        voiceNameField.placeholderString = "Voice name"
        voiceNameField.font = .systemFont(ofSize: 13.5, weight: .medium)
        voiceNameField.bezelStyle = .roundedBezel

        scriptTextView.isEditable = false
        scriptTextView.isSelectable = true
        scriptTextView.isRichText = false
        scriptTextView.string = VoiceProfileStore.enrollmentScript
        scriptTextView.font = .systemFont(ofSize: 13.5)
        scriptTextView.textColor = KikiPalette.primaryText
        scriptTextView.backgroundColor = KikiPalette.canvas.withAlphaComponent(0.52)
        scriptTextView.textContainerInset = NSSize(width: 13, height: 12)
        let scriptScroll = KikiScrollView()
        scriptScroll.documentView = scriptTextView
        scriptScroll.hasVerticalScroller = true
        scriptScroll.wantsLayer = true
        scriptScroll.layer?.backgroundColor = KikiPalette.canvas.withAlphaComponent(0.52).cgColor
        scriptScroll.layer?.borderWidth = 1
        scriptScroll.layer?.borderColor = KikiPalette.stroke.cgColor

        consentCheckbox.target = self
        consentCheckbox.action = #selector(consentChanged)
        consentCheckbox.font = .systemFont(ofSize: 11.5)
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
        let recordingActions = NSStackView(views: [recordButton, saveVoiceButton, playReferenceButton, NSView()])
        recordingActions.orientation = .horizontal
        recordingActions.alignment = .centerY
        recordingActions.spacing = 8

        let divider = NSBox()
        divider.boxType = .separator
        let modelTitle = kikiLabel("Local voice engine", size: 13.5, weight: .semibold)
        modelStatusLabel.font = .systemFont(ofSize: 11.5)
        modelStatusLabel.textColor = KikiPalette.secondaryText
        modelStatusLabel.maximumNumberOfLines = 2
        modelProgress.style = .bar
        modelProgress.minValue = 0
        modelProgress.maxValue = 1
        modelProgress.isHidden = true
        modelProgress.controlSize = .small
        let modelActions = NSStackView(views: [modelButton, deleteVoiceButton, NSView()])
        modelActions.orientation = .horizontal
        modelActions.alignment = .centerY
        modelActions.spacing = 8

        let stack = NSStackView(views: [
            sectionTitle, profileStatusLabel, voiceNameField, scriptScroll, consentCheckbox,
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
            scriptScroll.widthAnchor.constraint(equalTo: stack.widthAnchor),
            scriptScroll.heightAnchor.constraint(equalToConstant: 140),
            consentCheckbox.widthAnchor.constraint(equalTo: stack.widthAnchor),
            meterRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            recordingMeter.widthAnchor.constraint(greaterThanOrEqualToConstant: 220),
            qualityLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            recordingActions.widthAnchor.constraint(equalTo: stack.widthAnchor),
            divider.widthAnchor.constraint(equalTo: stack.widthAnchor),
            modelStatusLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            modelProgress.widthAnchor.constraint(equalTo: stack.widthAnchor),
            modelActions.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
        return card
    }

    private func makeGenerationCard() -> NSView {
        let card = KikiCardView()
        let sectionTitle = kikiLabel("Create Audio", size: 18, weight: .bold)
        let sectionDetail = kikiLabel("Write, paste, or edit a script. Longer text is generated in natural sections.", size: 12, color: KikiPalette.secondaryText)

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
            sectionTitle, sectionDetail, editorScroll, generationActions,
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
            profileStatusLabel.stringValue = "\(profile.name) is ready · recorded \(profile.createdAt.formatted(date: .abbreviated, time: .omitted)) · \(Int(profile.duration.rounded())) seconds"
            voiceNameField.stringValue = profile.name
            qualityLabel.stringValue = "Your reference recording is stored only in Kiki’s Application Support folder."
            consentCheckbox.state = .on
        } else {
            profileStatusLabel.stringValue = "Read the passage below once. Kiki uses the recording as a private reference—there is no cloud training."
            qualityLabel.stringValue = "Read naturally in a quiet room. Aim for 30–60 seconds."
        }
        voiceNameField.isEnabled = !hasProfile
        scriptTextView.alphaValue = hasProfile ? 0.55 : 1
        consentCheckbox.isEnabled = !hasProfile
        recordButton.title = hasProfile ? "Record Again" : "Start Voice Recording"
        recordButton.isEnabled = hasProfile || consentCheckbox.state == .on
        saveVoiceButton.isHidden = recordingSamples == nil
        playReferenceButton.isHidden = !hasProfile && recordingSamples == nil
        deleteVoiceButton.isHidden = !hasProfile

        if VoiceModelStore.isInstalled {
            modelStatusLabel.stringValue = "Installed · 2.0 GB · optimized for Apple silicon · no network used during generation"
            modelButton.title = "Remove Model"
            modelButton.isEnabled = downloadTask == nil && synthesisTask == nil
        } else {
            modelStatusLabel.stringValue = "Optional 2.0 GB download. After installation, generation is completely offline."
            modelButton.title = downloadTask == nil ? "Download Local Model" : "Cancel Download"
            modelButton.isEnabled = true
        }

        let ready = hasProfile && VoiceModelStore.isInstalled && synthesisTask == nil
        generateButton.isEnabled = ready && !editor.string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        playOutputButton.isEnabled = generatedAudioURL != nil
        exportButton.isEnabled = generatedAudioURL != nil
        revealButton.isEnabled = generatedAudioURL != nil
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
        audioPlayer?.stop()
        recordingSamples = nil
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
            qualityLabel.stringValue = "Recording locally… read the complete passage at your normal pace."
            recordingTimeLabel.textColor = .systemRed
            onCaptureStateChange?(true)
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.updateRecordingTimer() }
            }
            updateRecordingTimer()
        } catch {
            recorder.setSamplesHandler(nil)
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

        let quality = VoiceProfileStore.recordingQuality(samples: samples)
        qualityLabel.stringValue = quality.message
        recordingSamples = quality.canSave ? samples : nil
        saveVoiceButton.isHidden = !quality.canSave
        playReferenceButton.isHidden = !quality.canSave && profile == nil
        if quality.canSave {
            recordingSamples = samples
            saveVoiceButton.isEnabled = true
        }
    }

    private func updateRecordingTimer() {
        let elapsed = max(0, Int(Date().timeIntervalSince(recordingStartedAt ?? Date())))
        recordingTimeLabel.stringValue = String(format: "%02d:%02d", elapsed / 60, elapsed % 60)
        if elapsed >= 90 { stopRecording() }
    }

    @objc private func saveVoice() {
        guard let recordingSamples else { return }
        do {
            profile = try VoiceProfileStore.save(samples: recordingSamples, name: voiceNameField.stringValue)
            self.recordingSamples = nil
            Task { await synthesisEngine.unload() }
            refreshState()
        } catch {
            qualityLabel.stringValue = "Could not save your voice: \(error.localizedDescription)"
        }
    }

    @objc private func playReference() {
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
        alert.addButton(withTitle: "Delete Voice")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        do {
            audioPlayer?.stop()
            try VoiceProfileStore.delete()
            profile = nil
            recordingSamples = nil
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
            alert.addButton(withTitle: "Remove Model")
            alert.addButton(withTitle: "Cancel")
            alert.alertStyle = .warning
            guard alert.runModal() == .alertFirstButtonReturn else { return }
            Task { [weak self] in
                guard let self else { return }
                await synthesisEngine.unload()
                do {
                    try VoiceModelStore.delete()
                    modelStatusLabel.stringValue = "Local voice engine removed."
                } catch {
                    modelStatusLabel.stringValue = "Could not remove the model: \(error.localizedDescription)"
                }
                refreshState()
            }
            return
        }
        if let downloadTask {
            downloadTask.cancel()
            self.downloadTask = nil
            modelProgress.isHidden = true
            modelStatusLabel.stringValue = "Download cancelled. Any completed model files will be reused next time."
            refreshState()
            return
        }
        modelProgress.doubleValue = Double(VoiceModelStore.installedSize) / Double(VoiceModelStore.downloadSize)
        modelProgress.isHidden = false
        modelButton.title = "Cancel Download"
        downloadTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await VoiceModelStore.download { [weak self] progress in
                    guard let self else { return }
                    self.modelProgress.doubleValue = progress.fraction
                    let percent = Int((progress.fraction * 100).rounded())
                    self.modelStatusLabel.stringValue = "Downloading locally… \(percent)% · \(progress.currentFile)"
                }
                self.downloadTask = nil
                self.modelProgress.isHidden = true
                self.refreshState()
            } catch is CancellationError {
                self.downloadTask = nil
                self.modelProgress.isHidden = true
                self.modelStatusLabel.stringValue = "Download cancelled. Completed files will be reused."
                self.refreshState()
            } catch {
                self.downloadTask = nil
                self.modelProgress.isHidden = true
                self.modelStatusLabel.stringValue = "Download failed: \(error.localizedDescription)"
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
        audioPlayer?.stop()
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
                generationStatusLabel.stringValue = "Ready · generated entirely on this Mac"
                loadOutputAudio(url)
                playAudio(url: url, isOutput: true)
            } catch is CancellationError {
                generationStatusLabel.stringValue = "Generation cancelled."
            } catch {
                generationStatusLabel.stringValue = "Could not generate speech: \(error.localizedDescription)"
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
        if isOutput { playOutputButton.title = "Pause" }
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
        guard isOutput else { return }
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let player = self.audioPlayer, player.duration > 0 else { return }
                self.playbackProgress.doubleValue = player.currentTime / player.duration
                if !player.isPlaying && player.currentTime >= player.duration - 0.05 {
                    self.playbackTimer?.invalidate()
                    self.playbackTimer = nil
                    self.playOutputButton.title = "Play"
                    self.playbackProgress.doubleValue = 1
                }
            }
        }
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
        refreshState()
    }
}
