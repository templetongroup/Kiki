import AppKit

@MainActor
final class CustomDictionaryWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    private let tableView = NSTableView()
    private let spokenField = NSTextField()
    private let replacementField = NSTextField()
    private let countLabel = NSTextField(labelWithString: "")

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 680, height: 440),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Kiki Dictionary"
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildContent()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show() {
        reload()
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildContent() {
        let title = NSTextField(labelWithString: "Custom Dictionary")
        title.font = .systemFont(ofSize: 22, weight: .semibold)
        let detail = NSTextField(wrappingLabelWithString: "Teach Kiki names, jargon, and exact spellings. Replacements are applied locally to both Parakeet and Whisper results before paste.")
        detail.textColor = .secondaryLabelColor

        let heardColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("heard"))
        heardColumn.title = "Heard as"
        heardColumn.width = 260
        let replacementColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("replacement"))
        replacementColumn.title = "Replace with"
        replacementColumn.width = 320
        tableView.addTableColumn(heardColumn)
        tableView.addTableColumn(replacementColumn)
        tableView.headerView = NSTableHeaderView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.allowsMultipleSelection = false

        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder

        spokenField.placeholderString = "What the model hears"
        replacementField.placeholderString = "Exact replacement"
        let addButton = NSButton(title: "Add or Replace", target: self, action: #selector(addEntry))
        let deleteButton = NSButton(title: "Delete Selected", target: self, action: #selector(deleteSelected))
        let entryRow = NSStackView(views: [spokenField, replacementField, addButton])
        entryRow.spacing = 10
        let footer = NSStackView(views: [countLabel, NSView(), deleteButton])
        footer.spacing = 10

        let stack = NSStackView(views: [title, detail, entryRow, scrollView, footer])
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
            entryRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            spokenField.widthAnchor.constraint(equalTo: entryRow.widthAnchor, multiplier: 0.34),
            replacementField.widthAnchor.constraint(equalTo: entryRow.widthAnchor, multiplier: 0.38),
            scrollView.widthAnchor.constraint(equalTo: stack.widthAnchor),
            scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 220),
            footer.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
    }

    private func reload() {
        tableView.reloadData()
        let count = CustomDictionaryStore.shared.entries.count
        countLabel.stringValue = "\(count) custom \(count == 1 ? "entry" : "entries")"
    }

    @objc private func addEntry() {
        CustomDictionaryStore.shared.add(
            spoken: spokenField.stringValue,
            replacement: replacementField.stringValue
        )
        spokenField.stringValue = ""
        replacementField.stringValue = ""
        reload()
    }

    @objc private func deleteSelected() {
        let row = tableView.selectedRow
        guard row >= 0, row < CustomDictionaryStore.shared.entries.count else { return }
        CustomDictionaryStore.shared.remove(id: CustomDictionaryStore.shared.entries[row].id)
        reload()
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        CustomDictionaryStore.shared.entries.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let entry = CustomDictionaryStore.shared.entries[row]
        let text = tableColumn?.identifier.rawValue == "heard" ? entry.spoken : entry.replacement
        let field = NSTextField(labelWithString: text)
        field.lineBreakMode = .byTruncatingTail
        return field
    }
}
