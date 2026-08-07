import AppKit

@MainActor
final class PersonalizationWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    private let pageControl = NSSegmentedControl(
        labels: ["Learning", "Vocabulary", "Snippets", "Private Apps", "Confidence"],
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )
    private let host = NSView()
    private let statusLabel = NSTextField(labelWithString: "")
    private let suggestionsTable = NSTableView()
    private let correctionsTable = NSTableView()
    private let vocabularyTable = NSTableView()
    private let snippetsTable = NSTableView()
    private let privateAppsTable = NSTableView()
    private let confidenceTable = NSTableView()
    private let manualTermField = NSTextField()
    private let snippetTriggerField = NSTextField()
    private let snippetTemplateField = NSTextField()
    private let privateBundleField = NSTextField()
    private var pages: [NSView] = []
    private var openingContext: AppContextSnapshot?
    private var observers: [NSObjectProtocol] = []

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Kiki Personalization Studio"
        window.minSize = NSSize(width: 740, height: 580)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildContent()
        observeStores()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit { observers.forEach(NotificationCenter.default.removeObserver) }

    func show(context: AppContextSnapshot? = nil, page: Int? = nil) {
        openingContext = context
        reloadAll()
        if let page, pages.indices.contains(page) {
            pageControl.selectedSegment = page
            showPage(page)
        }
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildContent() {
        guard let content = window?.contentView else { return }
        let icon = NSImageView()
        if let url = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png") {
            icon.image = NSImage(contentsOf: url)
        }
        icon.imageScaling = .scaleProportionallyUpOrDown
        let title = NSTextField(labelWithString: "Personalization Studio")
        title.font = .systemFont(ofSize: 24, weight: .bold)
        let subtitle = NSTextField(labelWithString: "Teach Kiki your world without sending it anywhere.")
        subtitle.textColor = .secondaryLabelColor
        let labels = NSStackView(views: [title, subtitle])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 3
        let header = NSStackView(views: [icon, labels])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 14
        header.translatesAutoresizingMaskIntoConstraints = false

        pageControl.target = self
        pageControl.action = #selector(pageChanged)
        pageControl.selectedSegment = 0
        pageControl.controlSize = .large
        pageControl.translatesAutoresizingMaskIntoConstraints = false
        host.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false

        content.addSubview(header)
        content.addSubview(pageControl)
        content.addSubview(host)
        content.addSubview(statusLabel)
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 48),
            icon.heightAnchor.constraint(equalToConstant: 48),
            header.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 26),
            header.topAnchor.constraint(equalTo: content.topAnchor, constant: 22),
            pageControl.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 18),
            pageControl.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            host.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            host.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            host.topAnchor.constraint(equalTo: pageControl.bottomAnchor, constant: 16),
            statusLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 26),
            statusLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -26),
            statusLabel.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -14),
            host.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -10),
        ])

        configureTables()
        pages = [
            makeLearningPage(),
            makeVocabularyPage(),
            makeSnippetsPage(),
            makePrivateAppsPage(),
            makeConfidencePage(),
        ]
        showPage(0)
    }

    private func configureTables() {
        configure(suggestionsTable, columns: [("heard", "Kiki heard", 220), ("replacement", "You changed it to", 220), ("scope", "App", 160)])
        configure(correctionsTable, columns: [("heard", "Heard", 220), ("replacement", "Use", 220), ("scope", "Scope", 160)])
        configure(vocabularyTable, columns: [("value", "Term", 320), ("source", "Source", 140), ("scope", "Scope", 160)])
        configure(snippetsTable, columns: [("trigger", "Spoken trigger", 260), ("template", "Inserted template", 380)])
        configure(privateAppsTable, columns: [("bundle", "Private application bundle identifier", 640)])
        configure(confidenceTable, columns: [("primary", "Primary result", 290), ("alternate", "Whisper alternative", 290), ("score", "Match", 70)])
    }

    private func configure(_ table: NSTableView, columns: [(String, String, CGFloat)]) {
        table.dataSource = self
        table.delegate = self
        table.usesAlternatingRowBackgroundColors = true
        table.rowHeight = 28
        table.allowsMultipleSelection = false
        for (identifier, title, width) in columns {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(identifier))
            column.title = title
            column.width = width
            table.addTableColumn(column)
        }
    }

    private func makeLearningPage() -> NSView {
        let learnGlobal = NSButton(title: "Learn Everywhere", target: self, action: #selector(approveGlobal))
        let learnApp = NSButton(title: "Learn for This App", target: self, action: #selector(approveForApp))
        let ignore = NSButton(title: "Ignore", target: self, action: #selector(rejectSuggestion))
        let remove = NSButton(title: "Forget Selected Rule", target: self, action: #selector(removeCorrection))
        return splitPage(
            topTitle: "Suggestions from your recent edits",
            topTable: suggestionsTable,
            topButtons: [learnGlobal, learnApp, ignore],
            bottomTitle: "Approved spelling rules",
            bottomTable: correctionsTable,
            bottomButtons: [remove]
        )
    }

    private func makeVocabularyPage() -> NSView {
        manualTermField.placeholderString = "Add a name, company, acronym, or project term"
        let add = NSButton(title: "Add Term", target: self, action: #selector(addManualTerm))
        let contacts = NSButton(title: "Import Contacts", target: self, action: #selector(importContacts))
        let calendar = NSButton(title: "Import Upcoming Calendar", target: self, action: #selector(importCalendar))
        let project = NSButton(title: "Import Project Folder…", target: self, action: #selector(importProject))
        let remove = NSButton(title: "Remove Selected", target: self, action: #selector(removeVocabularyTerm))
        let input = NSStackView(views: [manualTermField, add])
        input.orientation = .horizontal
        input.spacing = 8
        manualTermField.widthAnchor.constraint(greaterThanOrEqualToConstant: 380).isActive = true
        return tablePage(
            title: "Context vocabulary",
            detail: "Kiki uses conservative, local spelling correction for distinctive terms. Imports store names only—not contact details, event notes, or project contents.",
            table: vocabularyTable,
            above: [input],
            buttons: [contacts, calendar, project, remove]
        )
    }

    private func makeSnippetsPage() -> NSView {
        snippetTriggerField.placeholderString = "Spoken trigger, e.g. insert my scheduling link"
        snippetTemplateField.placeholderString = "Template; supports {{date}}, {{time}}, and {{clipboard}}"
        let add = NSButton(title: "Save Snippet", target: self, action: #selector(addSnippet))
        let remove = NSButton(title: "Remove Selected", target: self, action: #selector(removeSnippet))
        return tablePage(
            title: "Voice snippets",
            detail: "If a dictation exactly matches a trigger, Kiki inserts the template instantly without an AI pass.",
            table: snippetsTable,
            above: [snippetTriggerField, snippetTemplateField],
            buttons: [add, remove]
        )
    }

    private func makePrivateAppsPage() -> NSView {
        privateBundleField.placeholderString = "com.company.application"
        let add = NSButton(title: "Add Bundle ID", target: self, action: #selector(addPrivateBundle))
        let current = NSButton(title: "Add App I Was Using", target: self, action: #selector(addOpeningApp))
        let remove = NSButton(title: "Remove Selected", target: self, action: #selector(removePrivateBundle))
        let input = NSStackView(views: [privateBundleField, add])
        input.orientation = .horizontal
        input.spacing = 8
        privateBundleField.widthAnchor.constraint(greaterThanOrEqualToConstant: 380).isActive = true
        return tablePage(
            title: "Private zones",
            detail: "Kiki still dictates normally, but skips history, correction learning, contextual vocabulary, and confidence reviews in these apps. Secure text fields are always private.",
            table: privateAppsTable,
            above: [input],
            buttons: [current, remove]
        )
    }

    private func makeConfidencePage() -> NSView {
        let copy = NSButton(title: "Copy Whisper Alternative", target: self, action: #selector(copyAlternate))
        let remove = NSButton(title: "Dismiss", target: self, action: #selector(removeConfidenceReview))
        let clear = NSButton(title: "Clear All", target: self, action: #selector(clearConfidenceReviews))
        return tablePage(
            title: "Confidence reviews",
            detail: "Only strong disagreements appear here. The primary transcription is never delayed or silently replaced.",
            table: confidenceTable,
            above: [],
            buttons: [copy, remove, clear]
        )
    }

    private func splitPage(
        topTitle: String,
        topTable: NSTableView,
        topButtons: [NSView],
        bottomTitle: String,
        bottomTable: NSTableView,
        bottomButtons: [NSView]
    ) -> NSView {
        let top = tableSection(title: topTitle, table: topTable, buttons: topButtons)
        let bottom = tableSection(title: bottomTitle, table: bottomTable, buttons: bottomButtons)
        let split = NSSplitView()
        split.isVertical = false
        split.dividerStyle = .thin
        split.addArrangedSubview(top)
        split.addArrangedSubview(bottom)
        return split
    }

    private func tablePage(title: String, detail: String, table: NSTableView, above: [NSView], buttons: [NSView]) -> NSView {
        let titleLabel = NSTextField(labelWithString: title)
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        let detailLabel = NSTextField(wrappingLabelWithString: detail)
        detailLabel.textColor = .secondaryLabelColor
        let scroll = scrollView(for: table)
        let buttonRow = NSStackView(views: buttons)
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 8
        let stack = NSStackView(views: [titleLabel, detailLabel] + above + [scroll, buttonRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        let container = NSView()
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            detailLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
            scroll.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
        return container
    }

    private func tableSection(title: String, table: NSTableView, buttons: [NSView]) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        let scroll = scrollView(for: table)
        let row = NSStackView(views: buttons)
        row.orientation = .horizontal
        row.spacing = 8
        let stack = NSStackView(views: [label, scroll, row])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        let view = NSView()
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -8),
            scroll.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
        return view
    }

    private func scrollView(for table: NSTableView) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder
        scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 150).isActive = true
        return scroll
    }

    @objc private func pageChanged() { showPage(pageControl.selectedSegment) }
    private func showPage(_ index: Int) {
        host.subviews.forEach { $0.removeFromSuperview() }
        guard pages.indices.contains(index) else { return }
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
            ConfidenceReviewStore.didChangeNotification,
        ]
        observers = names.map { name in
            NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.reloadAll() }
            }
        }
    }

    private func reloadAll() {
        [suggestionsTable, correctionsTable, vocabularyTable, snippetsTable, privateAppsTable, confidenceTable]
            .forEach { $0.reloadData() }
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        if tableView === suggestionsTable { return CorrectionMemoryStore.shared.suggestions.count }
        if tableView === correctionsTable { return CorrectionMemoryStore.shared.corrections.count }
        if tableView === vocabularyTable { return ContextVocabularyStore.shared.terms.count }
        if tableView === snippetsTable { return VoiceSnippetStore.shared.snippets.count }
        if tableView === privateAppsTable { return PrivateZoneStore.shared.bundleIdentifiers.count }
        if tableView === confidenceTable { return ConfidenceReviewStore.shared.reviews.count }
        return 0
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let identifier = tableColumn?.identifier.rawValue else { return nil }
        let value: String
        if tableView === suggestionsTable {
            let item = CorrectionMemoryStore.shared.suggestions[row]
            value = identifier == "heard" ? item.heard : identifier == "replacement" ? item.replacement : item.bundleIdentifier ?? "Everywhere"
        } else if tableView === correctionsTable {
            let item = CorrectionMemoryStore.shared.corrections[row]
            value = identifier == "heard" ? item.heard : identifier == "replacement" ? item.replacement : item.bundleIdentifier ?? "Everywhere"
        } else if tableView === vocabularyTable {
            let item = ContextVocabularyStore.shared.terms[row]
            value = identifier == "value" ? item.value : identifier == "source" ? item.source.title : item.bundleIdentifier ?? "Everywhere"
        } else if tableView === snippetsTable {
            let item = VoiceSnippetStore.shared.snippets[row]
            value = identifier == "trigger" ? item.trigger : item.template
        } else if tableView === privateAppsTable {
            value = PrivateZoneStore.shared.bundleIdentifiers[row]
        } else if tableView === confidenceTable {
            let item = ConfidenceReviewStore.shared.reviews[row]
            value = identifier == "primary" ? item.primaryText : identifier == "alternate" ? item.alternateText : "\(Int(item.similarity * 100))%"
        } else { return nil }

        let cell = NSTextField(labelWithString: value)
        cell.lineBreakMode = .byTruncatingTail
        cell.toolTip = value
        return cell
    }

    @objc private func approveGlobal() { approveSuggestion(scopeToApp: false) }
    @objc private func approveForApp() { approveSuggestion(scopeToApp: true) }
    private func approveSuggestion(scopeToApp: Bool) {
        let row = suggestionsTable.selectedRow
        guard CorrectionMemoryStore.shared.suggestions.indices.contains(row) else { return }
        CorrectionMemoryStore.shared.approve(CorrectionMemoryStore.shared.suggestions[row], scopeToApp: scopeToApp)
    }
    @objc private func rejectSuggestion() {
        let row = suggestionsTable.selectedRow
        guard CorrectionMemoryStore.shared.suggestions.indices.contains(row) else { return }
        CorrectionMemoryStore.shared.reject(CorrectionMemoryStore.shared.suggestions[row])
    }
    @objc private func removeCorrection() {
        let row = correctionsTable.selectedRow
        guard CorrectionMemoryStore.shared.corrections.indices.contains(row) else { return }
        CorrectionMemoryStore.shared.removeCorrection(id: CorrectionMemoryStore.shared.corrections[row].id)
    }

    @objc private func addManualTerm() {
        ContextVocabularyStore.shared.add(values: [manualTermField.stringValue], source: .manual)
        manualTermField.stringValue = ""
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
        ContextVocabularyStore.shared.remove(id: ContextVocabularyStore.shared.terms[row].id)
    }

    @objc private func addSnippet() {
        VoiceSnippetStore.shared.add(trigger: snippetTriggerField.stringValue, template: snippetTemplateField.stringValue)
        snippetTriggerField.stringValue = ""
        snippetTemplateField.stringValue = ""
    }
    @objc private func removeSnippet() {
        let row = snippetsTable.selectedRow
        guard VoiceSnippetStore.shared.snippets.indices.contains(row) else { return }
        VoiceSnippetStore.shared.remove(id: VoiceSnippetStore.shared.snippets[row].id)
    }

    @objc private func addPrivateBundle() {
        PrivateZoneStore.shared.add(privateBundleField.stringValue)
        privateBundleField.stringValue = ""
    }
    @objc private func addOpeningApp() {
        guard let bundle = openingContext?.bundleIdentifier,
              bundle != Bundle.main.bundleIdentifier
        else { statusLabel.stringValue = "Open the studio from Kiki’s menu while the target app is active."; return }
        PrivateZoneStore.shared.add(bundle)
        statusLabel.stringValue = "Added \(openingContext?.displayName ?? bundle) as a private zone."
    }
    @objc private func removePrivateBundle() {
        let row = privateAppsTable.selectedRow
        guard PrivateZoneStore.shared.bundleIdentifiers.indices.contains(row) else { return }
        PrivateZoneStore.shared.remove(PrivateZoneStore.shared.bundleIdentifiers[row])
    }

    @objc private func copyAlternate() {
        let row = confidenceTable.selectedRow
        guard ConfidenceReviewStore.shared.reviews.indices.contains(row) else { return }
        TextInserter.copyOnly(ConfidenceReviewStore.shared.reviews[row].alternateText)
        statusLabel.stringValue = "Whisper alternative copied."
    }
    @objc private func removeConfidenceReview() {
        let row = confidenceTable.selectedRow
        guard ConfidenceReviewStore.shared.reviews.indices.contains(row) else { return }
        ConfidenceReviewStore.shared.remove(id: ConfidenceReviewStore.shared.reviews[row].id)
    }
    @objc private func clearConfidenceReviews() { ConfidenceReviewStore.shared.clear() }
}

