import AppKit

@MainActor
final class PersonalizationWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
    private let host = NSView()
    private let statusLabel = NSTextField(labelWithString: "")
    private let pageTitleLabel = kikiLabel("Learning", size: 27, weight: .bold)
    private let pageSubtitleLabel = kikiLabel("Approve what Kiki learns from your edits.", size: 13.5, color: KikiPalette.secondaryText)
    private var navButtons: [KikiNavButton] = []
    private let pageMetadata: [(String, String, String)] = [
        ("Learning", "Approve what Kiki learns from your edits.", "brain.head.profile"),
        ("Vocabulary", "Give distinctive names and terms the spelling they deserve.", "textformat.abc"),
        ("Snippets", "Turn a spoken trigger into a complete reusable response.", "quote.bubble"),
        ("Private Apps", "Choose where Kiki should leave no memory behind.", "hand.raised.fill"),
        ("Confidence", "Review only the transcriptions where local models strongly disagree.", "checkmark.seal"),
    ]
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
    private let suggestionCountLabel = kikiLabel("", size: 10.5, color: KikiPalette.secondaryText)
    private let suggestionSummaryLabel = kikiLabel(
        "Choose a suggestion to see exactly what Kiki learned.",
        size: 11.5,
        color: KikiPalette.secondaryText
    )
    private let suggestionScopePopup = NSPopUpButton()
    private lazy var approveSuggestionButton = KikiActionButton(
        "Approve Rule",
        kind: .primary,
        target: self,
        action: #selector(approveSelectedSuggestion)
    )
    private lazy var ignoreSuggestionButton = KikiActionButton(
        "Ignore",
        kind: .hardware,
        target: self,
        action: #selector(rejectSuggestion)
    )
    private lazy var removeCorrectionButton = KikiActionButton(
        "Forget Selected Rule",
        kind: .hardware,
        target: self,
        action: #selector(removeCorrection)
    )
    private lazy var addTermButton = KikiActionButton("Add Term", kind: .primary, target: self, action: #selector(addManualTerm))
    private lazy var removeTermButton = KikiActionButton("Remove Selected", kind: .hardware, target: self, action: #selector(removeVocabularyTerm))
    private lazy var saveSnippetButton = KikiActionButton("Save Snippet", kind: .primary, target: self, action: #selector(saveSnippet))
    private lazy var removeSnippetButton = KikiActionButton("Remove Selected", kind: .hardware, target: self, action: #selector(removeSnippet))
    private lazy var addPrivateAppButton = KikiActionButton("Add Bundle ID", kind: .primary, target: self, action: #selector(addPrivateBundle))
    private lazy var removePrivateAppButton = KikiActionButton("Remove Selected", kind: .hardware, target: self, action: #selector(removePrivateBundle))
    private lazy var copyAlternateButton = KikiActionButton("Copy Whisper Alternative", kind: .primary, target: self, action: #selector(copyAlternate))
    private lazy var dismissReviewButton = KikiActionButton("Dismiss", kind: .hardware, target: self, action: #selector(removeConfidenceReview))
    private lazy var clearReviewsButton = KikiActionButton("Clear All", kind: .hardware, target: self, action: #selector(clearConfidenceReviews))
    private var dataSurfaces: [ObjectIdentifier: KikiDataSurfaceView] = [:]
    private var pages: [NSView] = []
    private var openingContext: AppContextSnapshot?
    private var editingSnippetID: UUID?
    private var observers: [NSObjectProtocol] = []

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1_180, height: 900),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Kiki Personalization Studio"
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
            makeLearningPage(),
            makeVocabularyPage(),
            makeSnippetsPage(),
            makePrivateAppsPage(),
            makeConfidencePage(),
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
        suggestionsTable.identifier = NSUserInterfaceItemIdentifier("kiki.personalization.suggestions")
        correctionsTable.identifier = NSUserInterfaceItemIdentifier("kiki.personalization.corrections")
        vocabularyTable.identifier = NSUserInterfaceItemIdentifier("kiki.personalization.vocabulary")
        snippetsTable.identifier = NSUserInterfaceItemIdentifier("kiki.personalization.snippets")
        privateAppsTable.identifier = NSUserInterfaceItemIdentifier("kiki.personalization.private-apps")
        confidenceTable.identifier = NSUserInterfaceItemIdentifier("kiki.personalization.confidence")
        configure(suggestionsTable, columns: [("heard", "Kiki heard", 190), ("replacement", "You changed it to", 210), ("scope", "App", 130)])
        suggestionsTable.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        configure(correctionsTable, columns: [("heard", "Heard", 190), ("replacement", "Use", 210), ("scope", "Scope", 130)])
        configure(vocabularyTable, columns: [("value", "Term", 320), ("source", "Source", 140), ("scope", "Scope", 160)])
        configure(snippetsTable, columns: [("trigger", "Spoken trigger", 260), ("template", "Inserted template", 380)])
        configure(privateAppsTable, columns: [("bundle", "Private application bundle identifier", 640)])
        configure(confidenceTable, columns: [("primary", "Primary result", 290), ("alternate", "Whisper alternative", 290), ("score", "Match", 70)])
    }

    private func configureWorkflowControls() {
        [manualTermField, snippetTriggerField, snippetTemplateField, privateBundleField].forEach {
            $0.delegate = self
            $0.focusRingType = .none
        }
        manualTermField.setAccessibilityLabel("Vocabulary term")
        snippetTriggerField.setAccessibilityLabel("Spoken snippet trigger")
        snippetTemplateField.setAccessibilityLabel("Snippet text to insert")
        privateBundleField.setAccessibilityLabel("Private application bundle identifier")
        suggestionScopePopup.addItems(withTitles: ["Everywhere", "This app only"])
        suggestionScopePopup.controlSize = .large
        suggestionScopePopup.font = .systemFont(ofSize: 12, weight: .medium)
        suggestionSummaryLabel.maximumNumberOfLines = 3

        approveSuggestionButton.identifier = NSUserInterfaceItemIdentifier("kiki.personalization.approve")
        ignoreSuggestionButton.identifier = NSUserInterfaceItemIdentifier("kiki.personalization.ignore")
        removeCorrectionButton.identifier = NSUserInterfaceItemIdentifier("kiki.personalization.forget")
        addTermButton.identifier = NSUserInterfaceItemIdentifier("kiki.personalization.add-term")
        removeTermButton.identifier = NSUserInterfaceItemIdentifier("kiki.personalization.remove-term")
        saveSnippetButton.identifier = NSUserInterfaceItemIdentifier("kiki.personalization.save-snippet")
        removeSnippetButton.identifier = NSUserInterfaceItemIdentifier("kiki.personalization.remove-snippet")
        addPrivateAppButton.identifier = NSUserInterfaceItemIdentifier("kiki.personalization.add-private-app")
        removePrivateAppButton.identifier = NSUserInterfaceItemIdentifier("kiki.personalization.remove-private-app")
        copyAlternateButton.identifier = NSUserInterfaceItemIdentifier("kiki.personalization.copy-alternate")
        dismissReviewButton.identifier = NSUserInterfaceItemIdentifier("kiki.personalization.dismiss-review")
        clearReviewsButton.identifier = NSUserInterfaceItemIdentifier("kiki.personalization.clear-reviews")
    }

    private func configure(_ table: NSTableView, columns: [(String, String, CGFloat)]) {
        table.dataSource = self
        table.delegate = self
        table.usesAlternatingRowBackgroundColors = false
        table.backgroundColor = KikiPalette.canvas.withAlphaComponent(0.20)
        table.gridColor = KikiPalette.stroke
        table.gridStyleMask = [.solidHorizontalGridLineMask]
        table.intercellSpacing = NSSize(width: 0, height: 0)
        table.rowHeight = 32
        table.allowsMultipleSelection = false
        for (identifier, title, width) in columns {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(identifier))
            column.title = title
            column.width = width
            table.addTableColumn(column)
        }
    }

    private func makeLearningPage() -> NSView {
        let suggestions = tableSection(
            title: "Suggestions from recent edits",
            detail: "Nothing changes until you choose a suggestion and approve it.",
            countLabel: suggestionCountLabel,
            table: suggestionsTable,
            buttons: []
        )
        suggestions.identifier = NSUserInterfaceItemIdentifier("kiki.personalization.suggestions-section")
        let approved = tableSection(
            title: "Approved spelling rules",
            detail: "Select a rule to remove it. Kiki applies approved rules before insertion.",
            table: correctionsTable,
            buttons: [removeCorrectionButton]
        )

        let selectedStep = KikiGuidedStepView(
            number: 1,
            title: "Choose what changed",
            detail: "Select a suggestion on the left to review the original and corrected text."
        )
        let summaryCard = KikiCardView()
        suggestionSummaryLabel.translatesAutoresizingMaskIntoConstraints = false
        summaryCard.addSubview(suggestionSummaryLabel)
        NSLayoutConstraint.activate([
            suggestionSummaryLabel.leadingAnchor.constraint(equalTo: summaryCard.leadingAnchor, constant: 14),
            suggestionSummaryLabel.trailingAnchor.constraint(equalTo: summaryCard.trailingAnchor, constant: -14),
            suggestionSummaryLabel.topAnchor.constraint(equalTo: summaryCard.topAnchor, constant: 12),
            suggestionSummaryLabel.bottomAnchor.constraint(equalTo: summaryCard.bottomAnchor, constant: -12),
        ])
        let scopeStep = KikiGuidedStepView(
            number: 2,
            title: "Choose where it applies",
            detail: "Use the rule everywhere, or limit it to the app where Kiki noticed the edit.",
            trailing: suggestionScopePopup
        )
        let actionRow = NSStackView(views: [approveSuggestionButton, ignoreSuggestionButton])
        actionRow.orientation = .horizontal
        actionRow.alignment = .centerY
        actionRow.spacing = 8
        let approveStep = KikiGuidedStepView(
            number: 3,
            title: "Approve or ignore",
            detail: "Approved rules stay editable and local on this Mac.",
            trailing: actionRow
        )
        let privacy = kikiLabel(
            "PRIVATE BY DESIGN\nOnly the corrected phrase and app identifier are stored here—not the surrounding dictation.",
            size: 10.5,
            color: KikiPalette.secondaryText
        )
        privacy.maximumNumberOfLines = 4
        let privacyCard = KikiCardView()
        privacy.translatesAutoresizingMaskIntoConstraints = false
        privacyCard.addSubview(privacy)
        NSLayoutConstraint.activate([
            privacy.leadingAnchor.constraint(equalTo: privacyCard.leadingAnchor, constant: 14),
            privacy.trailingAnchor.constraint(equalTo: privacyCard.trailingAnchor, constant: -14),
            privacy.topAnchor.constraint(equalTo: privacyCard.topAnchor, constant: 12),
            privacy.bottomAnchor.constraint(equalTo: privacyCard.bottomAnchor, constant: -12),
        ])
        let guide = NSStackView(views: [
            kikiLabel("GUIDED REVIEW", size: 10, weight: .bold, color: KikiPalette.accentText),
            selectedStep,
            summaryCard,
            scopeStep,
            approveStep,
            privacyCard,
            NSView(),
        ])
        guide.orientation = .vertical
        guide.alignment = .width
        guide.spacing = 10

        let lower = NSStackView(views: [approved, guide])
        lower.orientation = .horizontal
        lower.alignment = .top
        lower.spacing = 16
        approved.widthAnchor.constraint(greaterThanOrEqualToConstant: 500).isActive = true
        guide.widthAnchor.constraint(equalToConstant: 300).isActive = true

        let layout = NSStackView(views: [suggestions, lower])
        layout.identifier = NSUserInterfaceItemIdentifier("kiki.personalization.learning-layout")
        layout.orientation = .vertical
        layout.alignment = .width
        layout.spacing = 14
        suggestions.widthAnchor.constraint(equalTo: layout.widthAnchor).isActive = true
        suggestions.heightAnchor.constraint(greaterThanOrEqualToConstant: 280).isActive = true
        lower.widthAnchor.constraint(equalTo: layout.widthAnchor).isActive = true
        return layout
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
        privateBundleField.placeholderString = "com.company.application"
        let current = KikiActionButton("Add App I Was Using", kind: .secondary, target: self, action: #selector(addOpeningApp))
        let input = NSStackView(views: [privateBundleField, addPrivateAppButton])
        input.orientation = .horizontal
        input.spacing = 8
        privateBundleField.widthAnchor.constraint(greaterThanOrEqualToConstant: 380).isActive = true
        let field = kikiFieldGroup(
            "Application bundle identifier",
            detail: "Example: com.apple.mail. Kiki continues dictating but keeps no optional memory there.",
            control: input
        )
        return tablePage(
            title: "Private zones",
            detail: "Kiki still dictates normally, but skips history, correction learning, contextual vocabulary, and confidence reviews in these apps. Secure text fields are always private.",
            table: privateAppsTable,
            above: [field],
            buttons: [current, removePrivateAppButton]
        )
    }

    private func makeConfidencePage() -> NSView {
        return tablePage(
            title: "Confidence reviews",
            detail: "Only strong disagreements appear here. The primary transcription is never delayed or silently replaced.",
            table: confidenceTable,
            above: [],
            buttons: [copyAlternateButton, dismissReviewButton, clearReviewsButton]
        )
    }

    private func tablePage(title: String, detail: String, table: NSTableView, above: [NSView], buttons: [NSView]) -> NSView {
        let titleLabel = kikiLabel(title, size: 17, weight: .semibold)
        let detailLabel = kikiLabel(detail, size: 12.5, color: KikiPalette.secondaryText)
        detailLabel.maximumNumberOfLines = 3
        let surface = dataSurface(for: table)
        let buttonRow = NSStackView(views: buttons)
        buttonRow.orientation = .horizontal
        buttonRow.alignment = .centerY
        buttonRow.distribution = .fillEqually
        buttonRow.spacing = 8
        if let tableIdentifier = table.identifier?.rawValue {
            buttonRow.identifier = NSUserInterfaceItemIdentifier("\(tableIdentifier).actions")
        }
        buttons.forEach {
            $0.heightAnchor.constraint(equalToConstant: 42).isActive = true
        }
        let stack = NSStackView(views: [titleLabel, detailLabel] + above + [surface, buttonRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
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
        if !buttons.isEmpty {
            buttonRow.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
        return container
    }

    private func tableSection(
        title: String,
        detail: String,
        countLabel: NSTextField? = nil,
        table: NSTableView,
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
        let views: [NSView] = buttons.isEmpty ? [heading, surface] : [heading, surface, row]
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
        return view
    }

    private func dataSurface(for table: NSTableView) -> KikiDataSurfaceView {
        let empty: (String, String, String)
        if table === suggestionsTable {
            empty = ("checkmark.seal", "No suggestions waiting", "Kiki will place repeated corrections here for your approval.")
        } else if table === correctionsTable {
            empty = ("text.badge.checkmark", "No approved rules yet", "Approve a suggestion to create your first local spelling rule.")
        } else if table === vocabularyTable {
            empty = ("textformat.abc", "No vocabulary terms yet", "Add an exact spelling or import names from a source you approve.")
        } else if table === snippetsTable {
            empty = ("quote.bubble", "No voice snippets yet", "Create a spoken trigger that inserts reusable text instantly.")
        } else if table === privateAppsTable {
            empty = ("hand.raised", "No private apps added", "Secure text fields are always private. Add an app for broader private behavior.")
        } else {
            empty = ("checkmark.seal", "No confidence reviews", "Kiki only saves a review when two local models strongly disagree.")
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
        dataSurfaces[ObjectIdentifier(suggestionsTable)]?.isEmpty = CorrectionMemoryStore.shared.suggestions.isEmpty
        dataSurfaces[ObjectIdentifier(correctionsTable)]?.isEmpty = CorrectionMemoryStore.shared.corrections.isEmpty
        dataSurfaces[ObjectIdentifier(vocabularyTable)]?.isEmpty = ContextVocabularyStore.shared.terms.isEmpty
        dataSurfaces[ObjectIdentifier(snippetsTable)]?.isEmpty = VoiceSnippetStore.shared.snippets.isEmpty
        dataSurfaces[ObjectIdentifier(privateAppsTable)]?.isEmpty = PrivateZoneStore.shared.bundleIdentifiers.isEmpty
        dataSurfaces[ObjectIdentifier(confidenceTable)]?.isEmpty = ConfidenceReviewStore.shared.reviews.isEmpty
        let suggestionCount = CorrectionMemoryStore.shared.suggestions.count
        suggestionCountLabel.stringValue = suggestionCount == 1 ? "1 waiting" : "\(suggestionCount) waiting"
        updateActionAvailability()
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        if let table = notification.object as? NSTableView, table === snippetsTable {
            beginEditingSelectedSnippet()
        }
        updateActionAvailability()
    }

    func controlTextDidChange(_ obj: Notification) {
        updateActionAvailability()
    }

    private func updateActionAvailability() {
        let suggestionSelected = CorrectionMemoryStore.shared.suggestions.indices.contains(suggestionsTable.selectedRow)
        approveSuggestionButton.isEnabled = suggestionSelected
        ignoreSuggestionButton.isEnabled = suggestionSelected
        suggestionScopePopup.isEnabled = suggestionSelected
        removeCorrectionButton.isEnabled = CorrectionMemoryStore.shared.corrections.indices.contains(correctionsTable.selectedRow)
        addTermButton.isEnabled = !trimmed(manualTermField.stringValue).isEmpty
        removeTermButton.isEnabled = ContextVocabularyStore.shared.terms.indices.contains(vocabularyTable.selectedRow)
        saveSnippetButton.isEnabled = !trimmed(snippetTriggerField.stringValue).isEmpty
            && !trimmed(snippetTemplateField.stringValue).isEmpty
        removeSnippetButton.isEnabled = VoiceSnippetStore.shared.snippets.indices.contains(snippetsTable.selectedRow)
        addPrivateAppButton.isEnabled = !trimmed(privateBundleField.stringValue).isEmpty
        removePrivateAppButton.isEnabled = PrivateZoneStore.shared.bundleIdentifiers.indices.contains(privateAppsTable.selectedRow)
        let reviewSelected = ConfidenceReviewStore.shared.reviews.indices.contains(confidenceTable.selectedRow)
        copyAlternateButton.isEnabled = reviewSelected
        dismissReviewButton.isEnabled = reviewSelected
        clearReviewsButton.isEnabled = !ConfidenceReviewStore.shared.reviews.isEmpty

        if suggestionSelected {
            let suggestion = CorrectionMemoryStore.shared.suggestions[suggestionsTable.selectedRow]
            let scope = suggestion.bundleIdentifier ?? "the app where Kiki noticed it"
            suggestionSummaryLabel.stringValue = "Kiki heard “\(suggestion.heard)” and you changed it to “\(suggestion.replacement)”. Source: \(scope)."
        } else {
            suggestionSummaryLabel.stringValue = "Choose a suggestion to see exactly what Kiki learned."
        }
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
        cell.textColor = KikiPalette.primaryText
        cell.lineBreakMode = .byTruncatingTail
        cell.toolTip = value
        return cell
    }

    @objc private func approveSelectedSuggestion() {
        approveSuggestion(scopeToApp: suggestionScopePopup.indexOfSelectedItem == 1)
    }

    private func approveSuggestion(scopeToApp: Bool) {
        let row = suggestionsTable.selectedRow
        guard CorrectionMemoryStore.shared.suggestions.indices.contains(row) else {
            statusLabel.stringValue = "Choose a suggestion before approving a rule."
            return
        }
        let suggestion = CorrectionMemoryStore.shared.suggestions[row]
        CorrectionMemoryStore.shared.approve(CorrectionMemoryStore.shared.suggestions[row], scopeToApp: scopeToApp)
        statusLabel.stringValue = "Approved “\(suggestion.replacement)” \(scopeToApp ? "for this app" : "everywhere")."
    }
    @objc private func rejectSuggestion() {
        let row = suggestionsTable.selectedRow
        guard CorrectionMemoryStore.shared.suggestions.indices.contains(row) else {
            statusLabel.stringValue = "Choose a suggestion before ignoring it."
            return
        }
        CorrectionMemoryStore.shared.reject(CorrectionMemoryStore.shared.suggestions[row])
        statusLabel.stringValue = "Suggestion ignored."
    }
    @objc private func removeCorrection() {
        let row = correctionsTable.selectedRow
        guard CorrectionMemoryStore.shared.corrections.indices.contains(row) else {
            statusLabel.stringValue = "Choose an approved rule to forget."
            return
        }
        CorrectionMemoryStore.shared.removeCorrection(id: CorrectionMemoryStore.shared.corrections[row].id)
        statusLabel.stringValue = "Approved rule forgotten."
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
        ContextVocabularyStore.shared.remove(id: ContextVocabularyStore.shared.terms[row].id)
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

    @objc private func addPrivateBundle() {
        let bundle = trimmed(privateBundleField.stringValue)
        guard !bundle.isEmpty else {
            statusLabel.stringValue = "Enter an application bundle identifier."
            return
        }
        PrivateZoneStore.shared.add(bundle)
        privateBundleField.stringValue = ""
        statusLabel.stringValue = "Added \(bundle) as a private app."
        updateActionAvailability()
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
