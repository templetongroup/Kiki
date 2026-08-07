import AppKit
import UniformTypeIdentifiers

@MainActor
final class FileTranscriptionWindowController: NSWindowController {
    var onTranscribe: (@MainActor (URL) async throws -> String)?

    private let dropView = FileDropView()
    private let statusLabel = NSTextField(labelWithString: "Drop an audio file or choose one below")
    private let progressIndicator = NSProgressIndicator()
    private let textView = NSTextView()
    private let copyButton = NSButton(title: "Copy", target: nil, action: nil)
    private let saveButton = NSButton(title: "Save Text…", target: nil, action: nil)

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 600),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Transcribe a File with Kiki"
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

    private func buildContent() {
        let title = NSTextField(labelWithString: "Local File Transcription")
        title.font = .systemFont(ofSize: 22, weight: .semibold)
        let detail = NSTextField(wrappingLabelWithString: "Audio is processed by your selected model entirely on this Mac. Custom dictionary replacements and text-only history apply automatically.")
        detail.textColor = .secondaryLabelColor

        dropView.onFile = { [weak self] url in self?.startTranscription(url) }
        let chooseButton = NSButton(title: "Choose Audio File…", target: self, action: #selector(chooseFile))

        progressIndicator.style = .spinning
        progressIndicator.controlSize = .small
        progressIndicator.isDisplayedWhenStopped = false
        statusLabel.textColor = .secondaryLabelColor
        let statusRow = NSStackView(views: [progressIndicator, statusLabel, NSView(), chooseButton])
        statusRow.spacing = 10

        textView.isEditable = true
        textView.isRichText = false
        textView.font = .systemFont(ofSize: 14)
        textView.textContainerInset = NSSize(width: 12, height: 12)
        let outputScroll = NSScrollView()
        outputScroll.documentView = textView
        outputScroll.hasVerticalScroller = true
        outputScroll.borderType = .bezelBorder

        copyButton.target = self
        copyButton.action = #selector(copyText)
        saveButton.target = self
        saveButton.action = #selector(saveText)
        copyButton.isEnabled = false
        saveButton.isEnabled = false
        let privacy = NSTextField(labelWithString: "Local proof: no network used for transcription")
        privacy.textColor = .secondaryLabelColor
        let actions = NSStackView(views: [privacy, NSView(), copyButton, saveButton])
        actions.spacing = 10

        let stack = NSStackView(views: [title, detail, dropView, statusRow, outputScroll, actions])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        guard let content = window?.contentView else { return }
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 22),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -22),
            detail.widthAnchor.constraint(equalTo: stack.widthAnchor),
            dropView.widthAnchor.constraint(equalTo: stack.widthAnchor),
            dropView.heightAnchor.constraint(equalToConstant: 116),
            statusRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            outputScroll.widthAnchor.constraint(equalTo: stack.widthAnchor),
            outputScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 280),
            actions.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
    }

    @objc private func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose an audio file to transcribe locally with Kiki."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        startTranscription(url)
    }

    private func startTranscription(_ url: URL) {
        guard let onTranscribe else { return }
        statusLabel.stringValue = "Transcribing \(url.lastPathComponent)…"
        progressIndicator.startAnimation(nil)
        copyButton.isEnabled = false
        saveButton.isEnabled = false
        textView.string = ""
        Task { [weak self] in
            do {
                let text = try await onTranscribe(url)
                guard let self else { return }
                self.textView.string = text
                self.statusLabel.stringValue = text.isEmpty
                    ? "No speech detected in \(url.lastPathComponent)"
                    : "Finished \(url.lastPathComponent) • \(Settings.transcriptionModel.displayName)"
                self.copyButton.isEnabled = !text.isEmpty
                self.saveButton.isEnabled = !text.isEmpty
                self.progressIndicator.stopAnimation(nil)
            } catch {
                guard let self else { return }
                self.statusLabel.stringValue = "Could not transcribe: \(error.localizedDescription)"
                self.progressIndicator.stopAnimation(nil)
            }
        }
    }

    @objc private func copyText() {
        guard !textView.string.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(textView.string, forType: .string)
    }

    @objc private func saveText() {
        guard !textView.string.isEmpty else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "Kiki Transcription.txt"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try textView.string.write(to: url, atomically: true, encoding: .utf8)
            statusLabel.stringValue = "Saved \(url.lastPathComponent)"
        } catch {
            statusLabel.stringValue = "Could not save: \(error.localizedDescription)"
        }
    }
}

final class FileDropView: NSView {
    var onFile: ((URL) -> Void)?
    private let label = NSTextField(labelWithString: "Drop an audio file here")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
        wantsLayer = true
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .secondaryLabelColor
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
        Settings.accentColor.color.withAlphaComponent(0.75).setStroke()
        Settings.accentColor.color.withAlphaComponent(0.06).setFill()
        path.fill()
        path.stroke()
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        fileURL(from: sender) == nil ? [] : .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
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
