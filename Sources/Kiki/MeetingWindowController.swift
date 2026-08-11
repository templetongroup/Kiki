import AppKit
import UniformTypeIdentifiers

@MainActor
final class MeetingWindowController: NSWindowController, NSWindowDelegate {
    var onCaptureStateChange: ((Bool) -> Void)?
    var onBeginLiveTranscription: (((@escaping @MainActor (String) -> Void)) -> MeetingLiveTranscription?)?
    var onTranscribe: ((MeetingAudioCapture, String) async throws -> MeetingTranscript)?

    private let captureSession = MeetingCaptureSession()
    private let titleField = NSTextField()
    private lazy var recordButton = KikiActionButton("Start Meeting Capture", kind: .primary, target: self, action: #selector(toggleRecording))
    private let timerLabel = NSTextField(labelWithString: "00:00:00")
    private let statusLabel = NSTextField(wrappingLabelWithString: "Ready — Kiki verifies both your microphone and remote meeting audio before recording.")
    private let textView = NSTextView()
    private let formatPopup = NSPopUpButton()
    private lazy var identifySpeakersButton = KikiActionButton("Identify Speakers…", kind: .hardware, target: self, action: #selector(identifySpeakers))
    private lazy var exportButton = KikiActionButton("Export", kind: .primary, target: self, action: #selector(exportTranscript))
    private lazy var copyButton = KikiActionButton("Copy", kind: .hardware, target: self, action: #selector(copyTranscript))
    private let saveAudioCheckbox = NSButton(checkboxWithTitle: "Keep local WAV files for this meeting", target: nil, action: nil)
    private let transcriptEmptyState = KikiEmptyStateView(
        symbol: "person.2.wave.2",
        title: "Ready to capture the room",
        detail: "Name the meeting, confirm whether you want local WAV files, then start capture. The live draft and final transcript appear here."
    )
    private var isRecording = false
    private var timer: Timer?
    private var startedAt: Date?
    private var transcript: MeetingTranscript?
    private var liveTranscription: MeetingLiveTranscription?
    private var speakerEditor: MeetingSpeakerEditorWindowController?

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 740),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Kiki Meeting Mode"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = false
        window.minSize = NSSize(width: 820, height: 600)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        buildContent()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show() {
        prepareForEmbeddedDisplay()
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func prepareForEmbeddedDisplay() {
        if titleField.stringValue.isEmpty {
            titleField.stringValue = "Meeting — \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short))"
        }
        saveAudioCheckbox.state = Settings.saveMeetingAudio ? .on : .off
        if transcript == nil, !isRecording {
            transcriptEmptyState.isHidden = false
            exportButton.isEnabled = false
            copyButton.isEnabled = false
        }
    }

    var preventsWorkbenchClose: Bool { isRecording }

    func showPreview(transcript: MeetingTranscript) {
        self.transcript = transcript
        titleField.stringValue = transcript.title
        textView.string = transcript.markdown
        identifySpeakersButton.isEnabled = !transcript.segments.isEmpty
        transcriptEmptyState.isHidden = true
        exportButton.isEnabled = true
        copyButton.isEnabled = true
        statusLabel.stringValue = "Preview complete — identify speakers before exporting."
        show()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard isRecording else { return true }
        statusLabel.stringValue = "Stop and transcribe the meeting before closing this window."
        return false
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
        icon.layer?.cornerRadius = 12
        icon.layer?.masksToBounds = true
        let eyebrow = kikiLabel("MEETING INTELLIGENCE", size: 10, weight: .bold, color: KikiPalette.accentText)
        let title = kikiLabel("Capture the room. Keep it private.", size: 27, weight: .bold)
        let subtitle = kikiLabel("Separate local audio tracks, source-labelled transcription, chapters, action-item hints, and caption exports. Headphones give the cleanest separation.", size: 12.5, color: KikiPalette.secondaryText)
        subtitle.maximumNumberOfLines = 2
        subtitle.lineBreakMode = .byWordWrapping
        subtitle.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let labels = NSStackView(views: [eyebrow, title, subtitle])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 5
        let header = NSStackView(views: [icon, labels])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 14

        titleField.placeholderString = "Meeting title"
        titleField.setAccessibilityLabel("Meeting title")
        titleField.font = .systemFont(ofSize: 14, weight: .medium)
        timerLabel.font = .monospacedDigitSystemFont(ofSize: 19, weight: .semibold)
        timerLabel.textColor = KikiPalette.secondaryText
        statusLabel.textColor = KikiPalette.secondaryText
        statusLabel.font = .systemFont(ofSize: 12.5)
        statusLabel.setAccessibilityLabel("Meeting capture status")
        saveAudioCheckbox.target = self
        saveAudioCheckbox.action = #selector(saveAudioChanged)
        saveAudioCheckbox.contentTintColor = KikiPalette.accentText

        let controls = NSStackView(views: [recordButton, timerLabel, NSView(), saveAudioCheckbox])
        controls.orientation = .horizontal
        controls.alignment = .centerY
        controls.spacing = 12
        let controlStack = NSStackView(views: [controls, statusLabel])
        controlStack.orientation = .vertical
        controlStack.alignment = .leading
        controlStack.spacing = 9
        controlStack.translatesAutoresizingMaskIntoConstraints = false
        let controlCard = KikiCardView()
        controlCard.addSubview(controlStack)
        NSLayoutConstraint.activate([
            controlStack.leadingAnchor.constraint(equalTo: controlCard.leadingAnchor, constant: 14),
            controlStack.trailingAnchor.constraint(equalTo: controlCard.trailingAnchor, constant: -14),
            controlStack.topAnchor.constraint(equalTo: controlCard.topAnchor, constant: 12),
            controlStack.bottomAnchor.constraint(equalTo: controlCard.bottomAnchor, constant: -12),
            controls.widthAnchor.constraint(equalTo: controlStack.widthAnchor),
            statusLabel.widthAnchor.constraint(equalTo: controlStack.widthAnchor),
        ])

        textView.isEditable = true
        textView.isRichText = false
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.backgroundColor = KikiPalette.canvas.withAlphaComponent(0.72)
        textView.textColor = KikiPalette.primaryText
        textView.insertionPointColor = KikiPalette.accentText
        textView.textContainerInset = NSSize(width: 14, height: 14)
        textView.string = ""
        let scroll = KikiScrollView()
        scroll.documentView = textView
        scroll.hasVerticalScroller = true
        let transcriptCard = KikiCardView()
        transcriptCard.identifier = NSUserInterfaceItemIdentifier("kiki.meeting.transcript")
        transcriptEmptyState.identifier = NSUserInterfaceItemIdentifier("kiki.meeting.empty")
        transcriptCard.usesHardwareDepth = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        transcriptEmptyState.translatesAutoresizingMaskIntoConstraints = false
        transcriptCard.addSubview(scroll)
        transcriptCard.addSubview(transcriptEmptyState)
        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: transcriptCard.leadingAnchor, constant: 1),
            scroll.trailingAnchor.constraint(equalTo: transcriptCard.trailingAnchor, constant: -1),
            scroll.topAnchor.constraint(equalTo: transcriptCard.topAnchor, constant: 1),
            scroll.bottomAnchor.constraint(equalTo: transcriptCard.bottomAnchor, constant: -1),
            transcriptEmptyState.leadingAnchor.constraint(equalTo: transcriptCard.leadingAnchor),
            transcriptEmptyState.trailingAnchor.constraint(equalTo: transcriptCard.trailingAnchor),
            transcriptEmptyState.topAnchor.constraint(equalTo: transcriptCard.topAnchor),
            transcriptEmptyState.bottomAnchor.constraint(equalTo: transcriptCard.bottomAnchor),
        ])

        formatPopup.addItems(withTitles: ["Markdown", "Plain Text", "SRT Captions", "WebVTT Captions"])
        formatPopup.controlSize = .regular
        formatPopup.setAccessibilityLabel("Meeting export format")
        exportButton.isEnabled = false
        copyButton.isEnabled = false
        exportButton.identifier = NSUserInterfaceItemIdentifier("kiki.meeting.export")
        copyButton.identifier = NSUserInterfaceItemIdentifier("kiki.meeting.copy")
        let footer = NSStackView(views: [formatPopup, exportButton, copyButton, NSView()])
        footer.orientation = .horizontal
        footer.alignment = .centerY
        footer.spacing = 8

        identifySpeakersButton.isEnabled = false
        identifySpeakersButton.identifier = NSUserInterfaceItemIdentifier("kiki.meeting.identify-speakers")
        let speakerTools = NSStackView(views: [identifySpeakersButton, kikiLabel("Rename once to update every transcript row and export.", size: 12, color: KikiPalette.secondaryText), NSView()])
        speakerTools.orientation = .horizontal
        speakerTools.alignment = .centerY
        speakerTools.spacing = 10

        let titleGroup = kikiFieldGroup(
            "Meeting title",
            detail: "This name is used for the transcript and every exported file.",
            control: titleField
        )
        let stack = NSStackView(views: [header, titleGroup, controlCard, speakerTools, transcriptCard, footer])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 44),
            icon.heightAnchor.constraint(equalToConstant: 44),
            labels.widthAnchor.constraint(lessThanOrEqualTo: header.widthAnchor, constant: -58),
            recordButton.heightAnchor.constraint(equalToConstant: 40),
            recordButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 180),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 28),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -28),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 28),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -20),
            header.widthAnchor.constraint(equalTo: stack.widthAnchor),
            titleGroup.widthAnchor.constraint(equalTo: stack.widthAnchor),
            controlCard.widthAnchor.constraint(equalTo: stack.widthAnchor),
            speakerTools.widthAnchor.constraint(equalTo: stack.widthAnchor),
            transcriptCard.widthAnchor.constraint(equalTo: stack.widthAnchor),
            transcriptCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 220),
            footer.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
    }

    @objc private func toggleRecording() {
        if isRecording { stopCapture() } else { startCapture() }
    }

    private func startCapture() {
        recordButton.isEnabled = false
        identifySpeakersButton.isEnabled = false
        exportButton.isEnabled = false
        copyButton.isEnabled = false
        statusLabel.stringValue = "Starting local microphone and system-audio capture…"
        onCaptureStateChange?(true)
        Task { [weak self] in
            guard let self else { return }
            do {
                let preview = onBeginLiveTranscription? { [weak self] text in
                    guard let self, self.isRecording else { return }
                    self.textView.string = "LIVE DRAFT · YOU\n\n\(text)"
                }
                liveTranscription = preview
                captureSession.setMicrophoneSamplesHandler { [weak preview] samples in
                    preview?.yield(samples)
                }
                try await captureSession.start()
                isRecording = true
                startedAt = Date()
                recordButton.title = "Stop & Transcribe"
                recordButton.isEnabled = true
                timerLabel.textColor = .systemRed
                transcriptEmptyState.isHidden = true
                textView.string = preview == nil
                    ? "Listening…\n\nLive preview requires a Parakeet model. The complete transcript will appear when capture stops."
                    : "LIVE DRAFT · YOU\n\nListening…"
                statusLabel.stringValue = "Recording locally — remote audio is active. Live draft shows You; identify the other speakers after transcription."
                startTimer()
            } catch {
                captureSession.setMicrophoneSamplesHandler(nil)
                let preview = liveTranscription
                liveTranscription = nil
                Task { await preview?.stop() }
                onCaptureStateChange?(false)
                recordButton.isEnabled = true
                statusLabel.stringValue = "Recording did not start — Kiki could not verify both you and the other speakers."
                transcriptEmptyState.isHidden = false
                textView.string = ""
                presentCaptureStartFailure(error)
            }
        }
    }

    private func presentCaptureStartFailure(_ error: Error) {
        let captureError = error as? MeetingCaptureStartError
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Meeting recording did not start"
        alert.informativeText = "\(error.localizedDescription)\n\nKiki will not record a meeting unless it can capture both your microphone and the other speakers."

        if captureError?.requiresScreenRecordingSettings == true {
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Cancel")
        } else {
            alert.addButton(withTitle: "OK")
        }

        guard let window = textView.window ?? window else { return }
        alert.beginSheetModal(for: window) { response in
            guard response == .alertFirstButtonReturn,
                  captureError?.requiresScreenRecordingSettings == true,
                  let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
            else { return }
            NSWorkspace.shared.open(settingsURL)
        }
    }

    private func stopCapture() {
        guard isRecording else { return }
        isRecording = false
        stopTimer()
        recordButton.title = "Start Meeting Capture"
        recordButton.isEnabled = false
        statusLabel.stringValue = "Finalizing local audio…"
        captureSession.setMicrophoneSamplesHandler(nil)
        let preview = liveTranscription
        liveTranscription = nil
        Task { await preview?.stop() }
        let title = titleField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        Task { [weak self] in
            guard let self else { return }
            defer { onCaptureStateChange?(false) }
            let capture = await captureSession.stop()
            var archiveMessage = ""
            if Settings.saveMeetingAudio {
                do {
                    let folder = try MeetingAudioArchiver.save(capture, title: title)
                    archiveMessage = " Audio saved in \(folder.lastPathComponent)."
                } catch {
                    archiveMessage = " Audio could not be saved: \(error.localizedDescription)"
                }
            }
            statusLabel.stringValue = "Transcribing locally…\(archiveMessage)"
            do {
                guard let onTranscribe else { throw KikiError("Meeting transcription is unavailable.") }
                let result = try await onTranscribe(capture, title.isEmpty ? "Meeting" : title)
                transcript = result
                textView.string = result.markdown
                identifySpeakersButton.isEnabled = !result.segments.isEmpty
                transcriptEmptyState.isHidden = true
                exportButton.isEnabled = !result.segments.isEmpty
                copyButton.isEnabled = !result.segments.isEmpty
                statusLabel.stringValue = "Complete — \(result.segments.count) segments. Identify speakers before exporting.\(archiveMessage)"
            } catch {
                statusLabel.stringValue = "Meeting transcription failed: \(error.localizedDescription)"
                transcriptEmptyState.isHidden = true
                textView.string = "Meeting transcription failed. \(error.localizedDescription)"
                exportButton.isEnabled = false
                copyButton.isEnabled = false
            }
            recordButton.isEnabled = true
        }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateTimer() }
        }
        updateTimer()
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        timerLabel.textColor = KikiPalette.secondaryText
        updateTimer()
    }

    private func updateTimer() {
        let elapsed = max(0, Int(Date().timeIntervalSince(startedAt ?? Date())))
        timerLabel.stringValue = String(format: "%02d:%02d:%02d", elapsed / 3600, (elapsed % 3600) / 60, elapsed % 60)
    }

    @objc private func saveAudioChanged() {
        Settings.saveMeetingAudio = saveAudioCheckbox.state == .on
    }

    @objc private func copyTranscript() {
        guard let transcript else {
            statusLabel.stringValue = "Record and transcribe a meeting before copying."
            return
        }
        TextInserter.copyOnly(transcript.markdown)
        statusLabel.stringValue = "Transcript copied."
    }

    @objc private func identifySpeakers() {
        guard let transcript else {
            statusLabel.stringValue = "Record and transcribe a meeting before identifying speakers."
            return
        }
        let editor = MeetingSpeakerEditorWindowController(transcript: transcript)
        editor.onApply = { [weak self] revised in
            guard let self else { return }
            self.transcript = revised
            self.textView.string = revised.markdown
            self.statusLabel.stringValue = "Speaker names updated everywhere and will be used by every export."
            self.speakerEditor = nil
        }
        speakerEditor = editor
        editor.showWindow(nil)
        editor.window?.center()
        editor.window?.makeKeyAndOrderFront(nil)
    }

    @objc private func exportTranscript() {
        guard let transcript else {
            statusLabel.stringValue = "Record and transcribe a meeting before exporting."
            return
        }
        let index = formatPopup.indexOfSelectedItem
        let ext = ["md", "txt", "srt", "vtt"][max(0, min(index, 3))]
        let contents: String
        switch index {
        case 1: contents = transcript.plainText
        case 2: contents = transcript.srt
        case 3: contents = transcript.vtt
        default: contents = transcript.markdown
        }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(safeFileName(transcript.title)).\(ext)"
        if let type = UTType(filenameExtension: ext) {
            panel.allowedContentTypes = [type]
        }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try contents.write(to: url, atomically: true, encoding: .utf8)
            statusLabel.stringValue = "Saved \(url.lastPathComponent)."
        } catch {
            statusLabel.stringValue = "Export failed: \(error.localizedDescription)"
        }
    }

    private func safeFileName(_ value: String) -> String {
        let cleaned = value.replacingOccurrences(of: "[^A-Za-z0-9._-]+", with: "-", options: .regularExpression)
        let result = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return result.isEmpty ? "Kiki-Meeting" : result
    }
}
