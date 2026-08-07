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
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Kiki Dictionary"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
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
        let eyebrow = kikiLabel("VOICE VOCABULARY", size: 10, weight: .bold, color: KikiPalette.accentText)
        let title = kikiLabel("Custom Dictionary", size: 26, weight: .bold)
        let detail = kikiLabel("Teach Kiki names, jargon, and exact spellings. Replacements stay local and apply before paste.", size: 12.5, color: KikiPalette.secondaryText)

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
        tableView.backgroundColor = KikiPalette.canvas.withAlphaComponent(0.62)
        tableView.usesAlternatingRowBackgroundColors = true

        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.wantsLayer = true
        scrollView.layer?.cornerRadius = 12
        scrollView.layer?.borderColor = KikiPalette.stroke.cgColor
        scrollView.layer?.borderWidth = 1

        spokenField.placeholderString = "What the model hears"
        replacementField.placeholderString = "Exact replacement"
        let addButton = KikiActionButton("Add or Replace", kind: .primary, target: self, action: #selector(addEntry))
        let deleteButton = KikiActionButton("Delete Selected", kind: .secondary, target: self, action: #selector(deleteSelected))
        let entryRow = NSStackView(views: [spokenField, replacementField, addButton])
        entryRow.spacing = 10
        let footer = NSStackView(views: [countLabel, NSView(), deleteButton])
        footer.spacing = 10

        let stack = NSStackView(views: [eyebrow, title, detail, entryRow, scrollView, footer])
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
        field.textColor = KikiPalette.primaryText
        field.lineBreakMode = .byTruncatingTail
        return field
    }
}
