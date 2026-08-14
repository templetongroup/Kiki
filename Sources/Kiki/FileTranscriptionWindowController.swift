import AppKit
import UniformTypeIdentifiers

@MainActor
final class FileTranscriptionWindowController: NSWindowController {
    var onTranscribe: (@MainActor (URL) async throws -> String)?

    private let dropView = FileDropView()
    private let statusLabel = NSTextField(labelWithString: "Drop an audio file or choose one below")
    private let progressIndicator = NSProgressIndicator()
    private let textView = NSTextView()
    private lazy var chooseButton = KikiActionButton("Choose Audio File", kind: .primary, target: self, action: #selector(chooseFile))
    private let copyButton = KikiActionButton("Copy", kind: .secondary, target: nil, action: nil)
    private let exportFormatPopup = NSPopUpButton()
    private let exportButton = KikiActionButton("Export Transcript", kind: .primary, target: nil, action: nil)
    private let outputEmptyState = KikiEmptyStateView(
        symbol: "waveform.badge.magnifyingglass",
        title: "Your transcript will appear here",
        detail: "Drop a recording above or choose an audio file. Kiki processes it locally with the selected model."
    )
    private var sourceURL: URL?
    private var transcriptionTask: Task<Void, Never>?
    private var activeRequestID: UUID?
    private var requestGate = FileTranscriptionRequestGate()

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 600),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Transcribe a File with Kiki"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = false
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildContent()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show() {
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func showPreview(transcription: String, sourceURL: URL) {
        self.sourceURL = sourceURL
        textView.string = transcription
        statusLabel.stringValue = "Finished \(sourceURL.lastPathComponent) • preview"
        dropView.isHidden = true
        chooseButton.title = "Transcribe Another File"
        outputEmptyState.isHidden = true
        copyButton.isEnabled = true
        exportFormatPopup.isEnabled = true
        exportButton.isEnabled = true
        show()
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
        let eyebrow = kikiLabel("LOCAL TRANSCRIPTION", size: 10, weight: .bold, color: KikiPalette.accentText)
        let title = kikiLabel("Turn any recording into text.", size: 26, weight: .bold)
        let detail = kikiLabel("Your selected model processes the file entirely on this Mac. Vocabulary and text-only history apply automatically.", size: 12.5, color: KikiPalette.secondaryText)

        dropView.onFile = { [weak self] url in self?.startTranscription(url) }
        chooseButton.identifier = NSUserInterfaceItemIdentifier("kiki.file-transcript.choose")

        progressIndicator.style = .spinning
        progressIndicator.controlSize = .small
        progressIndicator.isDisplayedWhenStopped = false
        statusLabel.textColor = KikiPalette.secondaryText
        let statusRow = NSStackView(views: [progressIndicator, statusLabel, NSView(), chooseButton])
        statusRow.spacing = 10

        textView.isEditable = true
        textView.isRichText = false
        textView.font = .systemFont(ofSize: 14)
        textView.backgroundColor = KikiPalette.canvas.withAlphaComponent(0.62)
        textView.textColor = KikiPalette.primaryText
        textView.insertionPointColor = KikiPalette.accentText
        textView.textContainerInset = NSSize(width: 12, height: 12)
        textView.setAccessibilityLabel("Local transcription text")
        let outputScroll = NSScrollView()
        outputScroll.documentView = textView
        outputScroll.hasVerticalScroller = true
        outputScroll.borderType = .noBorder
        outputScroll.wantsLayer = true
        outputScroll.layer?.cornerRadius = 12
        outputScroll.layer?.borderColor = KikiPalette.stroke.cgColor
        outputScroll.layer?.borderWidth = 1
        let outputCard = KikiCardView()
        outputCard.identifier = NSUserInterfaceItemIdentifier("kiki.file-transcript.output")
        outputEmptyState.identifier = NSUserInterfaceItemIdentifier("kiki.file-transcript.empty")
        outputCard.usesHardwareDepth = false
        outputScroll.translatesAutoresizingMaskIntoConstraints = false
        outputEmptyState.translatesAutoresizingMaskIntoConstraints = false
        outputCard.addSubview(outputScroll)
        outputCard.addSubview(outputEmptyState)
        NSLayoutConstraint.activate([
            outputScroll.leadingAnchor.constraint(equalTo: outputCard.leadingAnchor, constant: 1),
            outputScroll.trailingAnchor.constraint(equalTo: outputCard.trailingAnchor, constant: -1),
            outputScroll.topAnchor.constraint(equalTo: outputCard.topAnchor, constant: 1),
            outputScroll.bottomAnchor.constraint(equalTo: outputCard.bottomAnchor, constant: -1),
            outputEmptyState.leadingAnchor.constraint(equalTo: outputCard.leadingAnchor),
            outputEmptyState.trailingAnchor.constraint(equalTo: outputCard.trailingAnchor),
            outputEmptyState.topAnchor.constraint(equalTo: outputCard.topAnchor),
            outputEmptyState.bottomAnchor.constraint(equalTo: outputCard.bottomAnchor),
        ])

        copyButton.target = self
        copyButton.action = #selector(copyText)
        exportFormatPopup.addItems(withTitles: FileTranscriptExportFormat.allCases.map(\.title))
        exportFormatPopup.identifier = NSUserInterfaceItemIdentifier("kiki.file-transcript.export-format")
        exportFormatPopup.controlSize = .large
        exportFormatPopup.font = .systemFont(ofSize: 12.5, weight: .medium)
        exportButton.target = self
        exportButton.action = #selector(exportText)
        exportButton.identifier = NSUserInterfaceItemIdentifier("kiki.file-transcript.export")
        copyButton.isEnabled = false
        exportFormatPopup.isEnabled = false
        exportButton.isEnabled = false
        let privacy = NSTextField(labelWithString: "Local proof: no network used for transcription")
        privacy.textColor = KikiPalette.secondaryText
        let actions = NSStackView(views: [privacy, NSView(), exportFormatPopup, copyButton, exportButton])
        actions.spacing = 10

        let stack = NSStackView(views: [eyebrow, title, detail, dropView, statusRow, outputCard, actions])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 46),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -22),
            detail.widthAnchor.constraint(equalTo: stack.widthAnchor),
            dropView.widthAnchor.constraint(equalTo: stack.widthAnchor),
            dropView.heightAnchor.constraint(equalToConstant: 116),
            statusRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            outputCard.widthAnchor.constraint(equalTo: stack.widthAnchor),
            outputCard.heightAnchor.constraint(greaterThanOrEqualToConstant: 280),
            actions.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
    }

    @objc private func chooseFile() {
        if let transcriptionTask, let activeRequestID {
            guard requestGate.requestCancellation(for: activeRequestID) else { return }
            transcriptionTask.cancel()
            statusLabel.stringValue = "Cancelling local transcription…"
            chooseButton.title = "Cancelling…"
            chooseButton.isEnabled = false
            return
        }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose an audio file to transcribe locally with Kiki."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        startTranscription(url)
    }

    private func startTranscription(_ url: URL) {
        guard let onTranscribe else {
            statusLabel.stringValue = "File transcription is unavailable."
            return
        }
        guard let requestID = requestGate.begin() else {
            statusLabel.stringValue = requestGate.isCancelling
                ? "Wait for cancellation to finish before choosing another file."
                : "Finish the current transcription before choosing another file."
            return
        }
        activeRequestID = requestID
        statusLabel.stringValue = "Transcribing \(url.lastPathComponent)…"
        sourceURL = url
        dropView.isHidden = true
        dropView.isInputEnabled = false
        chooseButton.title = "Cancel Transcription"
        chooseButton.isEnabled = true
        progressIndicator.startAnimation(nil)
        copyButton.isEnabled = false
        exportFormatPopup.isEnabled = false
        exportButton.isEnabled = false
        textView.string = ""
        outputEmptyState.isHidden = false
        transcriptionTask = Task { [weak self] in
            do {
                let text = try await onTranscribe(url)
                try Task.checkCancellation()
                guard let self else { return }
                guard self.finishRequest(requestID) == .accepted else { return }
                self.textView.string = text
                self.outputEmptyState.isHidden = !text.isEmpty
                self.statusLabel.stringValue = text.isEmpty
                    ? "No speech detected in \(url.lastPathComponent)"
                    : "Finished \(url.lastPathComponent) • \(Settings.transcriptionModel.displayName)"
                self.copyButton.isEnabled = !text.isEmpty
                self.exportFormatPopup.isEnabled = !text.isEmpty
                self.exportButton.isEnabled = !text.isEmpty
                self.finishTranscriptionUI(showDropTarget: false)
            } catch is CancellationError {
                guard let self else { return }
                guard self.finishRequest(requestID) != .stale else { return }
                self.sourceURL = nil
                self.textView.string = ""
                self.outputEmptyState.isHidden = false
                self.statusLabel.stringValue = "Transcription cancelled. Choose a file when you’re ready."
                self.finishTranscriptionUI(showDropTarget: true)
            } catch {
                guard let self else { return }
                let completion = self.finishRequest(requestID)
                guard completion != .stale else { return }
                if completion == .cancelled {
                    self.sourceURL = nil
                    self.textView.string = ""
                    self.outputEmptyState.isHidden = false
                    self.statusLabel.stringValue = "Transcription cancelled. Choose a file when you’re ready."
                    self.finishTranscriptionUI(showDropTarget: true)
                    return
                }
                self.statusLabel.stringValue = "Could not transcribe: \(error.localizedDescription)"
                self.outputEmptyState.isHidden = false
                self.finishTranscriptionUI(showDropTarget: false)
            }
        }
    }

    private func finishRequest(_ requestID: UUID) -> FileTranscriptionCompletion {
        let completion = requestGate.complete(requestID)
        guard completion != .stale else { return completion }
        activeRequestID = nil
        transcriptionTask = nil
        return completion
    }

    private func finishTranscriptionUI(showDropTarget: Bool) {
        progressIndicator.stopAnimation(nil)
        dropView.isInputEnabled = true
        dropView.isHidden = !showDropTarget
        chooseButton.title = showDropTarget ? "Choose Audio File" : "Transcribe Another File"
        chooseButton.isEnabled = true
    }

    @objc private func copyText() {
        guard !textView.string.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(textView.string, forType: .string)
        statusLabel.stringValue = "Transcript copied."
    }

    @objc private func exportText() {
        guard !textView.string.isEmpty else { return }
        let formats = FileTranscriptExportFormat.allCases
        let index = exportFormatPopup.indexOfSelectedItem
        guard formats.indices.contains(index) else { return }
        let format = formats[index]
        let panel = NSSavePanel()
        panel.allowedContentTypes = [format.contentType]
        let sourceName = sourceURL?.deletingPathExtension().lastPathComponent ?? "Kiki Transcription"
        panel.nameFieldStringValue = "\(sourceName).\(format.fileExtension)"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try format.data(text: textView.string, sourceName: sourceName)
            try data.write(to: url, options: .atomic)
            statusLabel.stringValue = "Exported \(url.lastPathComponent)"
        } catch {
            statusLabel.stringValue = "Could not export: \(error.localizedDescription)"
        }
    }
}

enum FileTranscriptExportFormat: String, CaseIterable {
    case plainText
    case markdown
    case richText
    case pdf

    var title: String {
        switch self {
        case .plainText: "Plain Text (.txt)"
        case .markdown: "Markdown (.md)"
        case .richText: "Rich Text (.rtf)"
        case .pdf: "PDF Document (.pdf)"
        }
    }

    var fileExtension: String {
        switch self {
        case .plainText: "txt"
        case .markdown: "md"
        case .richText: "rtf"
        case .pdf: "pdf"
        }
    }

    var contentType: UTType {
        switch self {
        case .plainText: .plainText
        case .markdown: UTType(filenameExtension: "md") ?? .plainText
        case .richText: .rtf
        case .pdf: .pdf
        }
    }

    @MainActor
    func data(text: String, sourceName: String) throws -> Data {
        switch self {
        case .plainText:
            return Data(text.utf8)
        case .markdown:
            return Data("# \(sourceName)\n\n\(text)\n".utf8)
        case .richText:
            let attributed = NSAttributedString(
                string: text,
                attributes: [.font: NSFont.systemFont(ofSize: 13), .foregroundColor: NSColor.textColor]
            )
            return try attributed.data(
                from: NSRange(location: 0, length: attributed.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            )
        case .pdf:
            let page = NSTextView(frame: NSRect(x: 0, y: 0, width: 540, height: 720))
            page.isVerticallyResizable = true
            page.textContainer?.containerSize = NSSize(width: 476, height: CGFloat.greatestFiniteMagnitude)
            page.textContainer?.widthTracksTextView = true
            page.string = text
            page.font = .systemFont(ofSize: 13)
            page.textContainerInset = NSSize(width: 32, height: 32)
            if let container = page.textContainer, let layoutManager = page.layoutManager {
                layoutManager.ensureLayout(for: container)
                page.frame.size.height = max(720, layoutManager.usedRect(for: container).height + 64)
            }
            return page.dataWithPDF(inside: page.bounds)
        }
    }
}

final class FileDropView: NSView {
    var onFile: ((URL) -> Void)?
    private let label = NSTextField(labelWithString: "Drop an audio file here")
    var isInputEnabled = true {
        didSet {
            label.stringValue = isInputEnabled ? "Drop an audio file here" : "Transcription in progress"
            alphaValue = isInputEnabled ? 1 : 0.55
        }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
        wantsLayer = true
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = KikiPalette.secondaryText
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 14, yRadius: 14)
        path.setLineDash([7, 5], count: 2, phase: 0)
        path.lineWidth = 2
        KikiPalette.accentText.withAlphaComponent(0.72).setStroke()
        KikiPalette.violet.withAlphaComponent(0.10).setFill()
        path.fill()
        path.stroke()
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard isInputEnabled else { return [] }
        return fileURL(from: sender) == nil ? [] : .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard isInputEnabled else { return false }
        guard let url = fileURL(from: sender) else { return false }
        onFile?(url)
        return true
    }

    private func fileURL(from sender: NSDraggingInfo) -> URL? {
        guard let value = sender.draggingPasteboard.string(forType: .fileURL),
              let url = URL(string: value),
              (try? url.resourceValues(forKeys: [.contentTypeKey]).contentType?.conforms(to: .audio)) == true
        else { return nil }
        return url
    }
}
