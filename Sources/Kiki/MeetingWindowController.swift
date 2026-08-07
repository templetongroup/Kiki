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
    private let statusLabel = NSTextField(wrappingLabelWithString: "Ready — microphone and system audio stay on this Mac.")
    private let textView = NSTextView()
    private let formatPopup = NSPopUpButton()
    private let saveAudioCheckbox = NSButton(checkboxWithTitle: "Keep local WAV files for this meeting", target: nil, action: nil)
    private var isRecording = false
    private var timer: Timer?
    private var startedAt: Date?
    private var transcript: MeetingTranscript?
    private var liveTranscription: MeetingLiveTranscription?

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
        window.isMovableByWindowBackground = true
        window.minSize = NSSize(width: 820, height: 640)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        buildContent()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show() {
        if titleField.stringValue.isEmpty {
            titleField.stringValue = "Meeting — \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short))"
        }
        saveAudioCheckbox.state = Settings.saveMeetingAudio ? .on : .off
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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
        let eyebrow = kikiLabel("MEETING INTELLIGENCE", size: 10, weight: .bold, color: KikiPalette.cyan)
        let title = kikiLabel("Capture the room. Keep it private.", size: 27, weight: .bold)
        let subtitle = kikiLabel("Separate local audio tracks, source-labelled transcription, chapters, action-item hints, and caption exports. Headphones give the cleanest separation.", size: 12.5, color: KikiPalette.secondaryText)
        let labels = NSStackView(views: [eyebrow, title, subtitle])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 5
        let header = NSStackView(views: [icon, labels])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 14

        titleField.placeholderString = "Meeting title"
        titleField.font = .systemFont(ofSize: 14, weight: .medium)
        timerLabel.font = .monospacedDigitSystemFont(ofSize: 19, weight: .semibold)
        timerLabel.textColor = KikiPalette.secondaryText
        statusLabel.textColor = KikiPalette.secondaryText
        statusLabel.font = .systemFont(ofSize: 12.5)
        saveAudioCheckbox.target = self
        saveAudioCheckbox.action = #selector(saveAudioChanged)

        let controls = NSStackView(views: [recordButton, timerLabel, NSView(), saveAudioCheckbox])
        controls.orientation = .horizontal
        controls.alignment = .centerY
        controls.spacing = 12

        textView.isEditable = true
        textView.isRichText = false
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.backgroundColor = KikiPalette.canvas.withAlphaComponent(0.72)
        textView.textColor = KikiPalette.primaryText
        textView.insertionPointColor = KikiPalette.cyan
        textView.textContainerInset = NSSize(width: 14, height: 14)
        textView.string = "Your local transcript will appear here after capture stops."
        let scroll = KikiScrollView()
        scroll.documentView = textView
        scroll.hasVerticalScroller = true

        formatPopup.addItems(withTitles: ["Markdown", "Plain Text", "SRT Captions", "WebVTT Captions"])
        formatPopup.controlSize = .large
        let export = KikiActionButton("Export", kind: .primary, target: self, action: #selector(exportTranscript))
        let copy = KikiActionButton("Copy", kind: .secondary, target: self, action: #selector(copyTranscript))
        let footer = NSStackView(views: [formatPopup, export, copy, NSView()])
        footer.orientation = .horizontal
        footer.alignment = .centerY
        footer.spacing = 8

        let stack = NSStackView(views: [header, titleField, controls, statusLabel, scroll, footer])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 50),
            icon.heightAnchor.constraint(equalToConstant: 50),
            recordButton.heightAnchor.constraint(equalToConstant: 42),
            recordButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 180),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -32),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 48),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -26),
            titleField.widthAnchor.constraint(equalTo: stack.widthAnchor),
            controls.widthAnchor.constraint(equalTo: stack.widthAnchor),
            statusLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            scroll.widthAnchor.constraint(equalTo: stack.widthAnchor),
            scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 360),
            footer.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
    }

    @objc private func toggleRecording() {
        if isRecording { stopCapture() } else { startCapture() }
    }

    private func startCapture() {
        recordButton.isEnabled = false
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
                textView.string = preview == nil
                    ? "Listening…\n\nLive preview requires a Parakeet model. The complete transcript will appear when capture stops."
                    : "LIVE DRAFT · YOU\n\nListening…"
                statusLabel.stringValue = captureSession.systemAudioWarning
                    ?? "Recording locally — live draft shows You; the final transcript labels You and Others."
                startTimer()
            } catch {
                captureSession.setMicrophoneSamplesHandler(nil)
                let preview = liveTranscription
                liveTranscription = nil
                Task { await preview?.stop() }
                onCaptureStateChange?(false)
                recordButton.isEnabled = true
                statusLabel.stringValue = "Could not start Meeting Mode: \(error.localizedDescription)"
            }
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
                statusLabel.stringValue = "Complete — \(result.segments.count) local source-labelled segments.\(archiveMessage)"
            } catch {
                statusLabel.stringValue = "Meeting transcription failed: \(error.localizedDescription)"
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
        TextInserter.copyOnly(textView.string)
        statusLabel.stringValue = "Transcript copied."
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
        case 1: contents = textView.string
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
