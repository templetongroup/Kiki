import AppKit
import UniformTypeIdentifiers

@MainActor
final class PersonalizationWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
    private let host = NSView()
    private let statusLabel = NSTextField(labelWithString: "")
    private let pageTitleLabel = kikiLabel("Replacements", size: 27, weight: .bold)
    private let pageSubtitleLabel = kikiLabel("Save the exact spelling you want Kiki to insert.", size: 13.5, color: KikiPalette.secondaryText)
    private var navButtons: [KikiNavButton] = []
    private let pageMetadata: [(String, String, String)] = [
        ("Replacements", "Save the exact spelling you want Kiki to insert.", "textformat.abc"),
        ("Vocabulary", "Give distinctive names and terms the spelling they deserve.", "textformat.abc"),
        ("Snippets", "Turn a spoken trigger into a complete reusable response.", "quote.bubble"),
        ("Private Apps", "Choose where Kiki should leave no memory behind.", "hand.raised.fill"),
    ]
    private let correctionsTable = NSTableView()
    private let vocabularyTable = NSTableView()
    private let snippetsTable = NSTableView()
    private let privateAppsTable = NSTableView()
    private let manualTermField = NSTextField()
    private let snippetTriggerField = NSTextField()
    private let snippetTemplateField = NSTextField()
    private let replacementHeardField = NSTextField()
    private let replacementTextField = NSTextField()
    private lazy var addReplacementButton = KikiActionButton("Remember Replacement", kind: .primary, target: self, action: #selector(addReplacement))
    private lazy var removeCorrectionButton = KikiActionButton(
        "Remove Replacement",
        kind: .danger,
        target: self,
        action: #selector(removeCorrection)
    )
    private lazy var addTermButton = KikiActionButton("Add Term", kind: .primary, target: self, action: #selector(addManualTerm))
    private lazy var removeTermButton = KikiActionButton("Remove Selected", kind: .danger, target: self, action: #selector(removeVocabularyTerm))
    private lazy var saveSnippetButton = KikiActionButton("Save Snippet", kind: .primary, target: self, action: #selector(saveSnippet))
    private lazy var removeSnippetButton = KikiActionButton("Remove Selected", kind: .danger, target: self, action: #selector(removeSnippet))
    private lazy var removePrivateAppButton = KikiActionButton("Remove Selected", kind: .danger, target: self, action: #selector(removePrivateBundle))
    private var dataSurfaces: [ObjectIdentifier: KikiDataSurfaceView] = [:]
    private var pages: [NSView] = []
    private var openingContext: AppContextSnapshot?
    private let correctionStore: CorrectionMemoryStore
    private var editingSnippetID: UUID?
    private var observers: [NSObjectProtocol] = []

    convenience init() {
        self.init(correctionStore: .shared)
    }

    init(correctionStore: CorrectionMemoryStore) {
        self.correctionStore = correctionStore
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1_180, height: 900),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Kiki Words & Replacements"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = false
        window.minSize = NSSize(width: 1_080, height: 820)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildContent()
        observeStores()
        updateActionAvailability()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit { observers.forEach(NotificationCenter.default.removeObserver) }

    func show(context: AppContextSnapshot? = nil, page: Int? = nil) {
        openingContext = context
        reloadAll()
        if let page, pages.indices.contains(page) {
            showPage(page)
        }
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func prepareForEmbeddedDisplay(context: AppContextSnapshot? = nil, page: Int = 0) {
        openingContext = context
        reloadAll()
        if pages.indices.contains(page) { showPage(page) }
    }

    func workbenchPage(context: AppContextSnapshot? = nil, page index: Int) -> NSView {
        guard pages.indices.contains(index) else { return NSView() }
        openingContext = context
        reloadAll()
        showPage(index)
        let page = pages[index]
        page.removeFromSuperview()
        return page
    }

    func prepareForDiagnostics(page index: Int) {
        guard pages.indices.contains(index) else { return }
        reloadAll()
        showPage(index)
        window?.contentView?.layoutSubtreeIfNeeded()
    }

    private func buildContent() {
        guard let content = window?.contentView else { return }
        let backdrop = KikiBackdropView()
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        let sidebar = makeSidebar()
        sidebar.translatesAutoresizingMaskIntoConstraints = false
        let heading = NSStackView(views: [pageTitleLabel, pageSubtitleLabel])
        heading.orientation = .vertical
        heading.alignment = .leading
        heading.spacing = 5
        heading.translatesAutoresizingMaskIntoConstraints = false
        host.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.textColor = KikiPalette.secondaryText
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        content.addSubview(backdrop)
        content.addSubview(sidebar)
        content.addSubview(heading)
        content.addSubview(host)
        content.addSubview(statusLabel)
        NSLayoutConstraint.activate([
            backdrop.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            backdrop.topAnchor.constraint(equalTo: content.topAnchor),
            backdrop.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            sidebar.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            sidebar.topAnchor.constraint(equalTo: content.topAnchor),
            sidebar.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            sidebar.widthAnchor.constraint(equalToConstant: 220),
            heading.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: 32),
            heading.topAnchor.constraint(equalTo: content.topAnchor, constant: 52),
            host.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: 32),
            host.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -28),
            host.topAnchor.constraint(equalTo: heading.bottomAnchor, constant: 20),
            statusLabel.leadingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: 32),
            statusLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -26),
            statusLabel.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -14),
            host.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -10),
        ])

        configureTables()
        configureWorkflowControls()
        pages = [
            makeReplacementsPage(),
            makeVocabularyPage(),
            makeSnippetsPage(),
            makePrivateAppsPage(),
        ]
        showPage(0)
    }

    private func makeSidebar() -> NSView {
        let sidebar = KikiSidebarView()
        let icon = NSImageView()
        if let url = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png") {
            icon.image = NSImage(contentsOf: url)
        }
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.wantsLayer = true
        icon.layer?.cornerRadius = 11
        icon.layer?.masksToBounds = true
        let title = kikiLabel("Studio", size: 20, weight: .bold)
        let subtitle = kikiLabel("PERSONAL · PRIVATE", size: 9.5, weight: .semibold, color: KikiPalette.tertiaryText)
        let labels = NSStackView(views: [title, subtitle])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 2
        let brand = NSStackView(views: [icon, labels])
        brand.orientation = .horizontal
        brand.alignment = .centerY
        brand.spacing = 12

        navButtons = pageMetadata.enumerated().map { index, item in
            let button = KikiNavButton(title: item.0, symbol: item.2, target: self, action: #selector(navigationChanged(_:)))
            button.tag = index
            button.isSelectedPage = index == 0
            return button
        }
        let navigation = NSStackView(views: navButtons)
        navigation.orientation = .vertical
        navigation.alignment = .width
        navigation.spacing = 6
        navButtons.forEach {
            $0.widthAnchor.constraint(equalTo: navigation.widthAnchor).isActive = true
        }
        let privacy = kikiLabel("Nothing in this studio leaves your Mac.", size: 11.5, color: KikiPalette.secondaryText)
        privacy.maximumNumberOfLines = 3
        let stack = NSStackView(views: [brand, navigation, NSView(), privacy])
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 26
        stack.translatesAutoresizingMaskIntoConstraints = false
        sidebar.addSubview(stack)
        NSLayoutConstraint.activate([
            navigation.widthAnchor.constraint(equalTo: stack.widthAnchor),
            icon.widthAnchor.constraint(equalToConstant: 44),
            icon.heightAnchor.constraint(equalToConstant: 44),
            stack.leadingAnchor.constraint(equalTo: sidebar.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: sidebar.trailingAnchor, constant: -18),
            stack.topAnchor.constraint(equalTo: sidebar.topAnchor, constant: 52),
            stack.bottomAnchor.constraint(equalTo: sidebar.bottomAnchor, constant: -24),
        ])
        return sidebar
    }

    private func configureTables() {
        correctionsTable.identifier = NSUserInterfaceItemIdentifier("kiki.personalization.corrections")
        vocabularyTable.identifier = NSUserInterfaceItemIdentifier("kiki.personalization.vocabulary")
        snippetsTable.identifier = NSUserInterfaceItemIdentifier("kiki.personalization.snippets")
        privateAppsTable.identifier = NSUserInterfaceItemIdentifier("kiki.personalization.private-apps")
        configure(correctionsTable, columns: [("heard", "Heard", 190), ("replacement", "Use", 210), ("scope", "Scope", 130)])
        configure(vocabularyTable, columns: [("value", "Term", 320), ("source", "Source", 140), ("scope", "Scope", 160)])
        configure(snippetsTable, columns: [("trigger", "Spoken trigger", 260), ("template", "Inserted template", 380)])
        configure(privateAppsTable, columns: [("bundle", "Application", 640)])
    }

    private func configureWorkflowControls() {
        [manualTermField, snippetTriggerField, snippetTemplateField, replacementHeardField, replacementTextField].forEach { $0.delegate = self }
        replacementHeardField.identifier = NSUserInterfaceItemIdentifier("kiki.replacements.heard")
        replacementTextField.identifier = NSUserInterfaceItemIdentifier("kiki.replacements.text")
        addReplacementButton.identifier = NSUserInterfaceItemIdentifier("kiki.replacements.add")
        removeCorrectionButton.identifier = NSUserInterfaceItemIdentifier("kiki.replacements.remove")
        saveSnippetButton.identifier = NSUserInterfaceItemIdentifier("kiki.personalization.save-snippet")
        removeSnippetButton.identifier = NSUserInterfaceItemIdentifier("kiki.personalization.remove-snippet")
    }

    private func configure(_ table: NSTableView, columns: [(String, String, CGFloat)]) {
        table.dataSource = self
        table.delegate = self
        configureKikiTable(table)
        table.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        for (identifier, title, width) in columns {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(identifier))
            column.title = title
            column.width = width
            column.minWidth = min(width, identifier == "score" ? 70 : 120)
            table.addTableColumn(column)
        }
    }

    private func makeReplacementsPage() -> NSView {
        let heard = kikiFieldGroup("Replace", control: replacementHeardField)
        let use = kikiFieldGroup("With", control: replacementTextField)
        return tablePage(title: "Words & replacements", detail: "Add a replacement explicitly. Your dictionary entries and previously approved rules appear together here.", table: correctionsTable, above: [heard, use], buttons: [addReplacementButton, removeCorrectionButton])
    }

    private func makeVocabularyPage() -> NSView {
        manualTermField.placeholderString = "Add a name, company, acronym, or project term"
        let contacts = KikiActionButton("Import Contacts", kind: .secondary, target: self, action: #selector(importContacts))
        let calendar = KikiActionButton("Import Calendar", kind: .secondary, target: self, action: #selector(importCalendar))
        let project = KikiActionButton("Import Project Folder…", kind: .secondary, target: self, action: #selector(importProject))
        let input = NSStackView(views: [manualTermField, addTermButton])
        input.orientation = .horizontal
        input.spacing = 8
        manualTermField.widthAnchor.constraint(greaterThanOrEqualToConstant: 380).isActive = true
        let field = kikiFieldGroup(
            "Name, company, acronym, or project term",
            detail: "Use the exact spelling you want Kiki to insert.",
            control: input
        )
        return tablePage(
            title: "Context vocabulary",
            detail: "Kiki uses conservative, local spelling correction for distinctive terms. Imports store names only—not contact details, event notes, or project contents.",
            table: vocabularyTable,
            above: [field],
            buttons: [contacts, calendar, project, removeTermButton]
        )
    }

    private func makeSnippetsPage() -> NSView {
        snippetTriggerField.placeholderString = "Spoken trigger, e.g. insert my scheduling link"
        snippetTemplateField.placeholderString = "Template; supports {{date}}, {{time}}, and {{clipboard}}"
        let trigger = kikiFieldGroup("Spoken trigger", detail: "The exact phrase that activates this snippet.", control: snippetTriggerField)
        let template = kikiFieldGroup("Inserted text", detail: "Supports {{date}}, {{time}}, and {{clipboard}}.", control: snippetTemplateField)
        return tablePage(
            title: "Voice snippets",
            detail: "If a dictation exactly matches a trigger, Kiki inserts the template instantly without an AI pass.",
            table: snippetsTable,
            above: [trigger, template],
            buttons: [saveSnippetButton, removeSnippetButton]
        )
    }

    private func makePrivateAppsPage() -> NSView {
        let choose = KikiActionButton("Choose App…", kind: .primary, target: self, action: #selector(choosePrivateApp))
        return tablePage(title: "Private apps", detail: "Dictation continues here without saving history. Secure fields are always private.", table: privateAppsTable, above: [], buttons: [choose, removePrivateAppButton])
    }

    @objc private func choosePrivateApp() {
        let panel = NSOpenPanel()
        panel.title = "Choose a private app"
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        guard panel.runModal() == .OK, let url = panel.url, let identifier = Bundle(url: url)?.bundleIdentifier else { return }
        PrivateZoneStore.shared.add(identifier)
    }

    private func tablePage(title: String, detail: String, table: NSTableView, above: [NSView], buttons: [NSView]) -> NSView {
        let titleLabel = kikiLabel(title, size: 17, weight: .semibold)
        let detailLabel = kikiLabel(detail, size: 12.5, color: KikiPalette.secondaryText)
        detailLabel.maximumNumberOfLines = 3
        let surface = dataSurface(for: table)
        let buttonRow = NSStackView(views: buttons)
        buttonRow.orientation = .horizontal
        buttonRow.alignment = .centerY
        buttonRow.distribution = .fill
        buttonRow.spacing = 8
        if let tableIdentifier = table.identifier?.rawValue {
            buttonRow.identifier = NSUserInterfaceItemIdentifier("\(tableIdentifier).actions")
        }
        buttons.forEach {
            $0.heightAnchor.constraint(equalToConstant: KikiMetrics.primaryControlHeight).isActive = true
        }
        if let firstButton = buttons.first {
            firstButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 150).isActive = true
            buttons.dropFirst().forEach {
                $0.widthAnchor.constraint(equalTo: firstButton.widthAnchor).isActive = true
            }
        }
        let stack = NSStackView(views: [titleLabel, detailLabel] + above + [surface, buttonRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        above.forEach {
            $0.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        let container = KikiCardView()
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 18),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -18),
            stack.topAnchor.constraint(equalTo: container.topAnchor, constant: 17),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -17),
            detailLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            surface.widthAnchor.constraint(equalTo: stack.widthAnchor),
            surface.heightAnchor.constraint(greaterThanOrEqualToConstant: 250),
        ])
        return container
    }

    private func tableSection(
        title: String,
        detail: String,
        countLabel: NSTextField? = nil,
        table: NSTableView,
        below: [NSView] = [],
        buttons: [NSView]
    ) -> NSView {
        let label = kikiLabel(title, size: 15, weight: .semibold)
        let detailLabel = kikiLabel(detail, size: 11, color: KikiPalette.secondaryText)
        detailLabel.maximumNumberOfLines = 2
        let headingCopy = NSStackView(views: [label, detailLabel])
        headingCopy.orientation = .vertical
        headingCopy.alignment = .leading
        headingCopy.spacing = 3
        let heading = NSStackView(views: [headingCopy, NSView()] + (countLabel.map { [$0] } ?? []))
        heading.orientation = .horizontal
        heading.alignment = .centerY
        let surface = dataSurface(for: table)
        let row = NSStackView(views: buttons)
        row.orientation = .horizontal
        row.spacing = 8
        let views: [NSView] = [heading, surface] + below + (buttons.isEmpty ? [] : [row])
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        let view = KikiCardView()
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12),
            heading.widthAnchor.constraint(equalTo: stack.widthAnchor),
            surface.widthAnchor.constraint(equalTo: stack.widthAnchor),
            surface.heightAnchor.constraint(greaterThanOrEqualToConstant: 128),
        ])
        below.forEach { $0.widthAnchor.constraint(lessThanOrEqualTo: stack.widthAnchor).isActive = true }
        return view
    }

    private func dataSurface(for table: NSTableView) -> KikiDataSurfaceView {
        let empty: (String, String, String)
        if table === correctionsTable {
            empty = ("text.badge.checkmark", "No replacements yet", "Enter a word and its replacement above.")
        } else if table === vocabularyTable {
            empty = ("textformat.abc", "No vocabulary terms yet", "Add an exact spelling or import names from a source you approve.")
        } else if table === snippetsTable {
            empty = ("quote.bubble", "No voice snippets yet", "Create a spoken trigger that inserts reusable text instantly.")
        } else if table === privateAppsTable {
            empty = ("hand.raised", "No private apps added", "Secure text fields are always private. Add an app for broader private behavior.")
        } else {
            empty = ("textformat.abc", "No entries yet", "Add an entry above.")
        }
        let surface = KikiDataSurfaceView(
            table: table,
            emptySymbol: empty.0,
            emptyTitle: empty.1,
            emptyDetail: empty.2
        )
        dataSurfaces[ObjectIdentifier(table)] = surface
        return surface
    }

    @objc private func navigationChanged(_ sender: KikiNavButton) { showPage(sender.tag) }
    private func showPage(_ index: Int) {
        host.subviews.forEach { $0.removeFromSuperview() }
        guard pages.indices.contains(index), pageMetadata.indices.contains(index) else { return }
        pageTitleLabel.stringValue = pageMetadata[index].0
        pageSubtitleLabel.stringValue = pageMetadata[index].1
        navButtons.enumerated().forEach { $0.element.isSelectedPage = $0.offset == index }
        let page = pages[index]
        page.translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(page)
        NSLayoutConstraint.activate([
            page.leadingAnchor.constraint(equalTo: host.leadingAnchor),
            page.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            page.topAnchor.constraint(equalTo: host.topAnchor),
            page.bottomAnchor.constraint(equalTo: host.bottomAnchor),
        ])
    }

    private func observeStores() {
        let names = [
            CorrectionMemoryStore.didChangeNotification,
            ContextVocabularyStore.didChangeNotification,
            VoiceSnippetStore.didChangeNotification,
            PrivateZoneStore.didChangeNotification,
        ]
        observers = names.map { name in
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.reloadAll() }
            }
        }
    }

    private func reloadAll() {
        [correctionsTable, vocabularyTable, snippetsTable, privateAppsTable].forEach { $0.reloadData() }
        dataSurfaces[ObjectIdentifier(correctionsTable)]?.isEmpty = correctionStore.corrections.isEmpty && CustomDictionaryStore.shared.entries.isEmpty
        dataSurfaces[ObjectIdentifier(vocabularyTable)]?.isEmpty = ContextVocabularyStore.shared.terms.isEmpty
        dataSurfaces[ObjectIdentifier(snippetsTable)]?.isEmpty = VoiceSnippetStore.shared.snippets.isEmpty
        dataSurfaces[ObjectIdentifier(privateAppsTable)]?.isEmpty = PrivateZoneStore.shared.bundleIdentifiers.isEmpty
        updateActionAvailability()
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        if let table = notification.object as? NSTableView, table === snippetsTable { beginEditingSelectedSnippet() }
        updateActionAvailability()
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        KikiTableRowView()
    }

    func controlTextDidChange(_ obj: Notification) {
        updateActionAvailability()
    }

    private func updateActionAvailability() {
        addReplacementButton.isEnabled = !trimmed(replacementHeardField.stringValue).isEmpty && !trimmed(replacementTextField.stringValue).isEmpty
        removeCorrectionButton.isEnabled = correctionsTable.selectedRow >= 0
        addTermButton.isEnabled = !trimmed(manualTermField.stringValue).isEmpty
        removeTermButton.isEnabled = ContextVocabularyStore.shared.terms.indices.contains(vocabularyTable.selectedRow)
        saveSnippetButton.isEnabled = !trimmed(snippetTriggerField.stringValue).isEmpty
            && !trimmed(snippetTemplateField.stringValue).isEmpty
        removeSnippetButton.isEnabled = VoiceSnippetStore.shared.snippets.indices.contains(snippetsTable.selectedRow)
        removePrivateAppButton.isEnabled = PrivateZoneStore.shared.bundleIdentifiers.indices.contains(privateAppsTable.selectedRow)

    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func beginEditingSelectedSnippet() {
        let row = snippetsTable.selectedRow
        guard VoiceSnippetStore.shared.snippets.indices.contains(row) else {
            editingSnippetID = nil
            saveSnippetButton.title = "Save Snippet"
            return
        }
        let snippet = VoiceSnippetStore.shared.snippets[row]
        editingSnippetID = snippet.id
        snippetTriggerField.stringValue = snippet.trigger
        snippetTemplateField.stringValue = snippet.template
        saveSnippetButton.title = "Update Snippet"
        statusLabel.stringValue = "Editing the “\(snippet.trigger)” voice snippet."
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView === correctionsTable { return correctionStore.corrections.count + CustomDictionaryStore.shared.entries.count }
        if tableView === vocabularyTable { return ContextVocabularyStore.shared.terms.count }
        if tableView === snippetsTable { return VoiceSnippetStore.shared.snippets.count }
        if tableView === privateAppsTable { return PrivateZoneStore.shared.bundleIdentifiers.count }
        return 0
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let identifier = tableColumn?.identifier.rawValue else { return nil }
        let value: String
        if tableView === correctionsTable {
            if row < CustomDictionaryStore.shared.entries.count {
                let item = CustomDictionaryStore.shared.entries[row]
                value = identifier == "heard" ? item.spoken : identifier == "replacement" ? item.replacement : "Everywhere"
            } else {
                let item = correctionStore.corrections[row - CustomDictionaryStore.shared.entries.count]
                value = identifier == "heard" ? item.heard : identifier == "replacement" ? item.replacement : item.bundleIdentifier ?? "Everywhere"
            }
        } else if tableView === vocabularyTable {
            let item = ContextVocabularyStore.shared.terms[row]
            value = identifier == "value" ? item.value : identifier == "source" ? item.source.title : item.bundleIdentifier ?? "Everywhere"
        } else if tableView === snippetsTable {
            let item = VoiceSnippetStore.shared.snippets[row]
            value = identifier == "trigger" ? item.trigger : item.template
        } else if tableView === privateAppsTable {
            let identifier = PrivateZoneStore.shared.bundleIdentifiers[row]
            value = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier)?.deletingPathExtension().lastPathComponent ?? identifier
        } else { return nil }

        return kikiTableCell(value)
    }

    @objc private func removeCorrection() {
        let row = correctionsTable.selectedRow
        guard row >= 0, confirmKikiDestructiveAction(message: "Remove this replacement?", detail: "Kiki will stop applying this spelling rule.", confirmTitle: "Remove Replacement") else { return }
        if CustomDictionaryStore.shared.entries.indices.contains(row) {
            CustomDictionaryStore.shared.remove(id: CustomDictionaryStore.shared.entries[row].id)
        } else {
            let index = row - CustomDictionaryStore.shared.entries.count
            guard correctionStore.corrections.indices.contains(index) else { return }
            correctionStore.removeCorrection(id: correctionStore.corrections[index].id)
        }
        reloadAll()
    }

    @objc private func addReplacement() {
        CustomDictionaryStore.shared.add(spoken: replacementHeardField.stringValue, replacement: replacementTextField.stringValue)
        replacementHeardField.stringValue = ""
        replacementTextField.stringValue = ""
        reloadAll()
    }

    @objc private func addManualTerm() {
        let value = trimmed(manualTermField.stringValue)
        guard !value.isEmpty else {
            statusLabel.stringValue = "Enter a term using the exact spelling you want."
            return
        }
        ContextVocabularyStore.shared.add(values: [value], source: .manual)
        manualTermField.stringValue = ""
        statusLabel.stringValue = "Added “\(value)” to local vocabulary."
        updateActionAvailability()
    }
    @objc private func importContacts() {
        statusLabel.stringValue = "Requesting Contacts access…"
        Task { [weak self] in
            do { self?.statusLabel.stringValue = "Imported \(try await ContextVocabularyImporter.importContacts()) new contact terms." }
            catch { self?.statusLabel.stringValue = error.localizedDescription }
        }
    }
    @objc private func importCalendar() {
        statusLabel.stringValue = "Requesting Calendar access…"
        Task { [weak self] in
            do { self?.statusLabel.stringValue = "Imported \(try await ContextVocabularyImporter.importUpcomingCalendar()) new calendar terms." }
            catch { self?.statusLabel.stringValue = error.localizedDescription }
        }
    }
    @objc private func importProject() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        statusLabel.stringValue = "Scanning names in \(url.lastPathComponent)…"
        Task { [weak self] in
            do { self?.statusLabel.stringValue = "Imported \(try await ContextVocabularyImporter.importProject(at: url)) project terms." }
            catch { self?.statusLabel.stringValue = error.localizedDescription }
        }
    }
    @objc private func removeVocabularyTerm() {
        let row = vocabularyTable.selectedRow
        guard ContextVocabularyStore.shared.terms.indices.contains(row) else { return }
        let term = ContextVocabularyStore.shared.terms[row]
        guard confirmKikiDestructiveAction(
            message: "Remove this vocabulary term?",
            detail: "Kiki will no longer use “\(term.value)” as approved local vocabulary.",
            confirmTitle: "Remove Term"
        ) else { return }
        ContextVocabularyStore.shared.remove(id: term.id)
        statusLabel.stringValue = "Removed “\(term.value)” from local vocabulary."
    }

    @objc private func saveSnippet() {
        let trigger = trimmed(snippetTriggerField.stringValue)
        let template = trimmed(snippetTemplateField.stringValue)
        guard !trigger.isEmpty, !template.isEmpty else {
            statusLabel.stringValue = "Enter both a spoken trigger and the text Kiki should insert."
            return
        }
        let wasEditing = editingSnippetID != nil
        if let editingSnippetID {
            VoiceSnippetStore.shared.update(id: editingSnippetID, trigger: trigger, template: template)
        } else {
            VoiceSnippetStore.shared.add(trigger: trigger, template: template)
        }
        editingSnippetID = nil
        snippetsTable.deselectAll(nil)
        snippetTriggerField.stringValue = ""
        snippetTemplateField.stringValue = ""
        saveSnippetButton.title = "Save Snippet"
        statusLabel.stringValue = "\(wasEditing ? "Updated" : "Saved") the “\(trigger)” voice snippet."
        updateActionAvailability()
    }
    @objc private func removeSnippet() {
        let row = snippetsTable.selectedRow
        guard VoiceSnippetStore.shared.snippets.indices.contains(row) else { return }
        let snippet = VoiceSnippetStore.shared.snippets[row]
        guard confirmKikiDestructiveAction(
            message: "Remove this voice snippet?",
            detail: "The “\(snippet.trigger)” trigger and its saved text will be deleted from this Mac.",
            confirmTitle: "Remove Snippet"
        ) else { return }
        VoiceSnippetStore.shared.remove(id: snippet.id)
        if editingSnippetID == snippet.id {
            editingSnippetID = nil
            snippetTriggerField.stringValue = ""
            snippetTemplateField.stringValue = ""
            saveSnippetButton.title = "Save Snippet"
        }
        statusLabel.stringValue = "Removed the “\(snippet.trigger)” voice snippet."
        updateActionAvailability()
    }

    @objc private func removePrivateBundle() {
        let row = privateAppsTable.selectedRow
        guard PrivateZoneStore.shared.bundleIdentifiers.indices.contains(row) else { return }
        let bundle = PrivateZoneStore.shared.bundleIdentifiers[row]
        guard confirmKikiDestructiveAction(
            message: "Remove this private app?",
            detail: "Kiki may save history again when you dictate in \(bundle).",
            confirmTitle: "Remove Private App"
        ) else { return }
        PrivateZoneStore.shared.remove(bundle)
        statusLabel.stringValue = "Removed \(bundle) from private apps."
    }

}
