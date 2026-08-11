import AppKit

@MainActor
final class CustomDictionaryWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
    private let tableView = NSTableView()
    private let spokenField = NSTextField()
    private let replacementField = NSTextField()
    private let countLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")
    private lazy var addButton = KikiActionButton("Add or Replace", kind: .primary, target: self, action: #selector(addEntry))
    private lazy var deleteButton = KikiActionButton("Delete Selected", kind: .hardware, target: self, action: #selector(deleteSelected))
    private var tableSurface: KikiDataSurfaceView?

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 540),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Kiki Dictionary"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = false
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildContent()
        updateActionAvailability()
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
        tableView.identifier = NSUserInterfaceItemIdentifier("kiki.dictionary.table")
        tableView.headerView = NSTableHeaderView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.allowsMultipleSelection = false
        tableView.backgroundColor = KikiPalette.canvas.withAlphaComponent(0.62)
        tableView.usesAlternatingRowBackgroundColors = true
        let surface = KikiDataSurfaceView(
            table: tableView,
            emptySymbol: "text.book.closed",
            emptyTitle: "No dictionary entries yet",
            emptyDetail: "Add what the model hears and the exact replacement Kiki should insert."
        )
        tableSurface = surface

        spokenField.placeholderString = "What the model hears"
        replacementField.placeholderString = "Exact replacement"
        spokenField.delegate = self
        replacementField.delegate = self
        spokenField.setAccessibilityLabel("What the model hears")
        replacementField.setAccessibilityLabel("Exact replacement")
        addButton.identifier = NSUserInterfaceItemIdentifier("kiki.dictionary.add")
        deleteButton.identifier = NSUserInterfaceItemIdentifier("kiki.dictionary.delete")
        let spokenGroup = kikiFieldGroup("What the model hears", control: spokenField)
        let replacementGroup = kikiFieldGroup("Exact replacement", control: replacementField)
        let entryRow = NSStackView(views: [spokenGroup, replacementGroup, addButton])
        entryRow.spacing = 10
        let footer = NSStackView(views: [countLabel, NSView(), deleteButton])
        footer.spacing = 10
        statusLabel.textColor = KikiPalette.secondaryText
        statusLabel.font = .systemFont(ofSize: 11.5)
        statusLabel.setAccessibilityLabel("Dictionary status")

        let stack = NSStackView(views: [eyebrow, title, detail, entryRow, surface, footer, statusLabel])
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
            spokenGroup.widthAnchor.constraint(equalTo: entryRow.widthAnchor, multiplier: 0.33),
            replacementGroup.widthAnchor.constraint(equalTo: entryRow.widthAnchor, multiplier: 0.40),
            surface.widthAnchor.constraint(equalTo: stack.widthAnchor),
            surface.heightAnchor.constraint(greaterThanOrEqualToConstant: 260),
            footer.widthAnchor.constraint(equalTo: stack.widthAnchor),
            statusLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
    }

    private func reload() {
        tableView.reloadData()
        let count = CustomDictionaryStore.shared.entries.count
        countLabel.stringValue = "\(count) custom \(count == 1 ? "entry" : "entries")"
        tableSurface?.isEmpty = count == 0
        updateActionAvailability()
    }

    @objc private func addEntry() {
        let spoken = spokenField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let replacement = replacementField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !spoken.isEmpty, !replacement.isEmpty else {
            statusLabel.stringValue = "Enter both what the model hears and the exact replacement."
            return
        }
        CustomDictionaryStore.shared.add(
            spoken: spoken,
            replacement: replacement
        )
        spokenField.stringValue = ""
        replacementField.stringValue = ""
        statusLabel.stringValue = "Saved “\(spoken)” → “\(replacement)”."
        reload()
    }

    @objc private func deleteSelected() {
        let row = tableView.selectedRow
        guard row >= 0, row < CustomDictionaryStore.shared.entries.count else {
            statusLabel.stringValue = "Choose an entry before deleting it."
            return
        }
        CustomDictionaryStore.shared.remove(id: CustomDictionaryStore.shared.entries[row].id)
        statusLabel.stringValue = "Dictionary entry deleted."
        reload()
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateActionAvailability()
    }

    func controlTextDidChange(_ obj: Notification) {
        updateActionAvailability()
    }

    private func updateActionAvailability() {
        addButton.isEnabled = !spokenField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !replacementField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        deleteButton.isEnabled = tableView.selectedRow >= 0
            && tableView.selectedRow < CustomDictionaryStore.shared.entries.count
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
