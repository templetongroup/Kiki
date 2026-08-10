import AppKit

@MainActor
final class HistoryWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    private let tableView = NSTableView()
    private let textView = NSTextView()
    private let countLabel = NSTextField(labelWithString: "")
    private var observer: NSObjectProtocol?

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 540),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Kiki History"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = false
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildContent()
        observer = NotificationCenter.default.addObserver(
            forName: TranscriptionHistoryStore.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.reload() }
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
    }

    func show() {
        reload()
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
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

        let dateColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("date"))
        dateColumn.title = "Date"
        dateColumn.width = 145
        let contextColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("context"))
        contextColumn.title = "App / Source"
        contextColumn.width = 135
        let previewColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("preview"))
        previewColumn.title = "Transcript"
        previewColumn.width = 290
        tableView.addTableColumn(dateColumn)
        tableView.addTableColumn(contextColumn)
        tableView.addTableColumn(previewColumn)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.headerView = NSTableHeaderView()
        tableView.allowsMultipleSelection = false
        tableView.backgroundColor = KikiPalette.canvas.withAlphaComponent(0.62)
        tableView.usesAlternatingRowBackgroundColors = true

        let tableScroll = NSScrollView()
        tableScroll.documentView = tableView
        tableScroll.hasVerticalScroller = true
        tableScroll.borderType = .noBorder

        textView.isEditable = false
        textView.isSelectable = true
        textView.font = .systemFont(ofSize: 14)
        textView.backgroundColor = KikiPalette.canvas.withAlphaComponent(0.62)
        textView.textColor = KikiPalette.primaryText
        textView.textContainerInset = NSSize(width: 10, height: 10)
        let textScroll = NSScrollView()
        textScroll.documentView = textView
        textScroll.hasVerticalScroller = true
        textScroll.borderType = .noBorder

        let split = NSSplitView()
        split.isVertical = true
        split.dividerStyle = .thin
        split.addArrangedSubview(tableScroll)
        split.addArrangedSubview(textScroll)

        let privacy = NSTextField(labelWithString: "Text only • stored locally • no microphone audio saved")
        privacy.textColor = KikiPalette.secondaryText
        let copyButton = KikiActionButton("Copy", kind: .primary, target: self, action: #selector(copySelected))
        let deleteButton = KikiActionButton("Delete", kind: .secondary, target: self, action: #selector(deleteSelected))
        let clearButton = KikiActionButton("Clear All", kind: .danger, target: self, action: #selector(clearAll))
        let footer = NSStackView(views: [countLabel, privacy, NSView(), copyButton, deleteButton, clearButton])
        footer.spacing = 10

        let stack = NSStackView(views: [split, footer])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -18),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 44),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -18),
            split.widthAnchor.constraint(equalTo: stack.widthAnchor),
            split.heightAnchor.constraint(greaterThanOrEqualToConstant: 420),
            tableScroll.widthAnchor.constraint(greaterThanOrEqualToConstant: 430),
            footer.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
    }

    private func reload() {
        tableView.reloadData()
        let count = TranscriptionHistoryStore.shared.records.count
        countLabel.stringValue = "\(count) \(count == 1 ? "transcription" : "transcriptions")"
        if count == 0 { textView.string = "" }
    }

    private var selectedRecord: TranscriptionRecord? {
        let row = tableView.selectedRow
        guard row >= 0, row < TranscriptionHistoryStore.shared.records.count else { return nil }
        return TranscriptionHistoryStore.shared.records[row]
    }

    @objc private func copySelected() {
        guard let record = selectedRecord else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(record.text, forType: .string)
    }

    @objc private func deleteSelected() {
        guard let record = selectedRecord else { return }
        TranscriptionHistoryStore.shared.remove(id: record.id)
        textView.string = ""
    }

    @objc private func clearAll() {
        let alert = NSAlert()
        alert.messageText = "Clear transcription history?"
        alert.informativeText = "This permanently deletes Kiki's locally stored transcript text."
        alert.addButton(withTitle: "Clear History")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        TranscriptionHistoryStore.shared.clear()
        textView.string = ""
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        TranscriptionHistoryStore.shared.records.count
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let record = selectedRecord else {
            textView.string = ""
            return
        }
        textView.string = "\(record.text)\n\n— \(record.modelName) • \(String(format: "%.1f", record.duration))s • Local"
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let record = TranscriptionHistoryStore.shared.records[row]
        let text: String
        switch tableColumn?.identifier.rawValue {
        case "date": text = Self.dateFormatter.string(from: record.createdAt)
        case "context": text = record.context ?? record.source.rawValue.capitalized
        default: text = record.text.replacingOccurrences(of: "\n", with: " ")
        }
        let field = NSTextField(labelWithString: text)
        field.textColor = KikiPalette.primaryText
        field.lineBreakMode = .byTruncatingTail
        return field
    }
}
