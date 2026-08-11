import AppKit

@MainActor
final class HistoryWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    private let tableView = NSTableView()
    private let textView = NSTextView()
    private let countLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")
    private lazy var copyButton = KikiActionButton("Copy", kind: .primary, target: self, action: #selector(copySelected))
    private lazy var deleteButton = KikiActionButton("Delete Selected", kind: .hardware, target: self, action: #selector(deleteSelected))
    private lazy var clearButton = KikiActionButton("Clear All", kind: .danger, target: self, action: #selector(clearAll))
    private var tableSurface: KikiDataSurfaceView?
    private let detailEmptyState = KikiEmptyStateView(
        symbol: "text.alignleft",
        title: "Choose a transcription",
        detail: "Select a row to read the complete local transcript and model details."
    )
    private var observer: NSObjectProtocol?

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 920, height: 620),
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
        updateActionAvailability()
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

    func prepareForEmbeddedDisplay() { reload() }

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
        tableView.identifier = NSUserInterfaceItemIdentifier("kiki.history.table")
        tableView.delegate = self
        tableView.dataSource = self
        tableView.headerView = NSTableHeaderView()
        tableView.allowsMultipleSelection = false
        tableView.backgroundColor = KikiPalette.canvas.withAlphaComponent(0.62)
        tableView.usesAlternatingRowBackgroundColors = true
        let historySurface = KikiDataSurfaceView(
            table: tableView,
            emptySymbol: "clock.arrow.circlepath",
            emptyTitle: "No local history yet",
            emptyDetail: "When text-only history is enabled, completed dictations appear here. Microphone audio is never stored."
        )
        tableSurface = historySurface

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

        let detailCard = KikiCardView()
        detailCard.usesHardwareDepth = false
        textScroll.translatesAutoresizingMaskIntoConstraints = false
        detailEmptyState.translatesAutoresizingMaskIntoConstraints = false
        detailCard.addSubview(textScroll)
        detailCard.addSubview(detailEmptyState)
        NSLayoutConstraint.activate([
            textScroll.leadingAnchor.constraint(equalTo: detailCard.leadingAnchor, constant: 1),
            textScroll.trailingAnchor.constraint(equalTo: detailCard.trailingAnchor, constant: -1),
            textScroll.topAnchor.constraint(equalTo: detailCard.topAnchor, constant: 1),
            textScroll.bottomAnchor.constraint(equalTo: detailCard.bottomAnchor, constant: -1),
            detailEmptyState.leadingAnchor.constraint(equalTo: detailCard.leadingAnchor),
            detailEmptyState.trailingAnchor.constraint(equalTo: detailCard.trailingAnchor),
            detailEmptyState.topAnchor.constraint(equalTo: detailCard.topAnchor),
            detailEmptyState.bottomAnchor.constraint(equalTo: detailCard.bottomAnchor),
        ])

        let split = NSSplitView()
        split.isVertical = true
        split.dividerStyle = .thin
        split.addArrangedSubview(historySurface)
        split.addArrangedSubview(detailCard)

        let eyebrow = kikiLabel("LOCAL LIBRARY", size: 10, weight: .bold, color: KikiPalette.accentText)
        let title = kikiLabel("History", size: 28, weight: .bold)
        let subtitle = kikiLabel("Review, copy, or remove the transcript text Kiki stores on this Mac.", size: 13, color: KikiPalette.secondaryText)
        let header = NSStackView(views: [eyebrow, title, subtitle])
        header.orientation = .vertical
        header.alignment = .leading
        header.spacing = 5

        let privacy = NSTextField(labelWithString: "Text only · stored locally · no microphone audio saved")
        privacy.textColor = KikiPalette.secondaryText
        let footer = NSStackView(views: [countLabel, privacy, NSView(), copyButton, deleteButton, clearButton])
        footer.spacing = 10
        statusLabel.textColor = KikiPalette.secondaryText
        statusLabel.font = .systemFont(ofSize: 11.5)
        statusLabel.setAccessibilityLabel("History status")
        copyButton.identifier = NSUserInterfaceItemIdentifier("kiki.history.copy")
        deleteButton.identifier = NSUserInterfaceItemIdentifier("kiki.history.delete")
        clearButton.identifier = NSUserInterfaceItemIdentifier("kiki.history.clear")

        let stack = NSStackView(views: [header, split, footer, statusLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -18),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 46),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -18),
            subtitle.widthAnchor.constraint(equalTo: stack.widthAnchor),
            split.widthAnchor.constraint(equalTo: stack.widthAnchor),
            split.heightAnchor.constraint(greaterThanOrEqualToConstant: 390),
            historySurface.widthAnchor.constraint(greaterThanOrEqualToConstant: 470),
            footer.widthAnchor.constraint(equalTo: stack.widthAnchor),
            statusLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
    }

    private func reload() {
        tableView.reloadData()
        let count = TranscriptionHistoryStore.shared.records.count
        countLabel.stringValue = "\(count) \(count == 1 ? "transcription" : "transcriptions")"
        tableSurface?.isEmpty = count == 0
        clearButton.isEnabled = count > 0
        if count == 0 {
            textView.string = ""
            detailEmptyState.isHidden = false
        }
        updateActionAvailability()
    }

    private var selectedRecord: TranscriptionRecord? {
        let row = tableView.selectedRow
        guard row >= 0, row < TranscriptionHistoryStore.shared.records.count else { return nil }
        return TranscriptionHistoryStore.shared.records[row]
    }

    @objc private func copySelected() {
        guard let record = selectedRecord else {
            statusLabel.stringValue = "Choose a transcription before copying."
            return
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(record.text, forType: .string)
        statusLabel.stringValue = "Transcript copied."
    }

    @objc private func deleteSelected() {
        guard let record = selectedRecord else {
            statusLabel.stringValue = "Choose a transcription before deleting."
            return
        }
        TranscriptionHistoryStore.shared.remove(id: record.id)
        textView.string = ""
        detailEmptyState.isHidden = false
        statusLabel.stringValue = "Transcript deleted from this Mac."
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
        detailEmptyState.isHidden = false
        statusLabel.stringValue = "Local transcription history cleared."
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        TranscriptionHistoryStore.shared.records.count
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard let record = selectedRecord else {
            textView.string = ""
            detailEmptyState.isHidden = false
            updateActionAvailability()
            return
        }
        detailEmptyState.isHidden = true
        textView.string = "\(record.text)\n\n— \(record.modelName) • \(String(format: "%.1f", record.duration))s • Local"
        updateActionAvailability()
    }

    private func updateActionAvailability() {
        let hasSelection = selectedRecord != nil
        copyButton.isEnabled = hasSelection
        deleteButton.isEnabled = hasSelection
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
