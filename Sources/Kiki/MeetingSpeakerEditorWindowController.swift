import AppKit

@MainActor
final class MeetingSpeakerEditorWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    var onApply: ((MeetingTranscript) -> Void)?

    private var transcript: MeetingTranscript
    private var availableSpeakers: [String]
    private let tableView = NSTableView()
    private let assignPopup = NSPopUpButton()
    private let renamePopup = NSPopUpButton()
    private let renameField = NSTextField()
    private let statusLabel = kikiLabel("Select one or more transcript rows, then assign the person who spoke.", size: 12, color: KikiPalette.secondaryText)

    init(transcript: MeetingTranscript) {
        self.transcript = transcript
        self.availableSpeakers = transcript.speakerNames
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 620),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Identify Meeting Speakers"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = false
        window.minSize = NSSize(width: 760, height: 500)
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildContent()
        refreshSpeakers()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func buildContent() {
        guard let content = window?.contentView else { return }
        let backdrop = KikiBackdropView()
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(backdrop)

        let eyebrow = kikiLabel("SPEAKER IDENTITY", size: 10, weight: .bold, color: KikiPalette.accentText)
        let title = kikiLabel("Put the right name on every voice.", size: 26, weight: .bold)
        let detail = kikiLabel("Rename a label once to update it everywhere, or select individual transcript rows and assign them to another person. Every export uses these names.", size: 12.5, color: KikiPalette.secondaryText)
        detail.maximumNumberOfLines = 0

        configureTable()
        let scroll = KikiScrollView()
        scroll.documentView = tableView
        scroll.hasVerticalScroller = true

        renameField.placeholderString = "Enter the person’s name"
        renameField.font = .systemFont(ofSize: 13)
        let renameButton = KikiActionButton("Rename Everywhere", kind: .hardware, target: self, action: #selector(renameEverywhere))
        let renameRow = NSStackView(views: [kikiLabel("Rename", size: 12.5, weight: .medium), renamePopup, renameField, renameButton])
        renameRow.orientation = .horizontal
        renameRow.alignment = .centerY
        renameRow.spacing = 8

        let newSpeaker = KikiActionButton("Add Speaker", kind: .hardware, target: self, action: #selector(addSpeaker))
        let assign = KikiActionButton("Assign Selected Rows", kind: .hardware, target: self, action: #selector(assignSelected))
        let assignRow = NSStackView(views: [kikiLabel("Assign", size: 12.5, weight: .medium), assignPopup, assign, newSpeaker, NSView()])
        assignRow.orientation = .horizontal
        assignRow.alignment = .centerY
        assignRow.spacing = 8

        let done = KikiActionButton("Done", kind: .primary, target: self, action: #selector(done))
        let footer = NSStackView(views: [statusLabel, NSView(), done])
        footer.orientation = .horizontal
        footer.alignment = .centerY
        footer.spacing = 10

        let stack = NSStackView(views: [eyebrow, title, detail, renameRow, assignRow, scroll, footer])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            backdrop.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            backdrop.topAnchor.constraint(equalTo: content.topAnchor),
            backdrop.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 26),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -26),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 48),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -22),
            detail.widthAnchor.constraint(equalTo: stack.widthAnchor),
            renameField.widthAnchor.constraint(greaterThanOrEqualToConstant: 220),
            renameRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            assignRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            scroll.widthAnchor.constraint(equalTo: stack.widthAnchor),
            scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 260),
            footer.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
    }

    private func configureTable() {
        let time = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("time"))
        time.title = "Time"
        time.width = 84
        let speaker = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("speaker"))
        speaker.title = "Speaker"
        speaker.width = 140
        let words = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("words"))
        words.title = "Transcript"
        words.width = 580
        tableView.addTableColumn(time)
        tableView.addTableColumn(speaker)
        tableView.addTableColumn(words)
        tableView.headerView = NSTableHeaderView()
        tableView.rowHeight = 34
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsMultipleSelection = true
        tableView.dataSource = self
        tableView.delegate = self
    }

    func numberOfRows(in tableView: NSTableView) -> Int { transcript.segments.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard transcript.segments.indices.contains(row), let identifier = tableColumn?.identifier else { return nil }
        let segment = transcript.segments[row]
        let value: String
        switch identifier.rawValue {
        case "time": value = timestamp(segment.startTime)
        case "speaker": value = segment.speaker
        default: value = segment.text
        }
        let label = NSTextField(labelWithString: value)
        label.font = identifier.rawValue == "time"
            ? .monospacedDigitSystemFont(ofSize: 11.5, weight: .medium)
            : .systemFont(ofSize: 12.5, weight: identifier.rawValue == "speaker" ? .semibold : .regular)
        label.textColor = identifier.rawValue == "speaker" ? KikiPalette.accentText : KikiPalette.primaryText
        label.lineBreakMode = .byTruncatingTail
        return label
    }

    private func refreshSpeakers(selecting name: String? = nil) {
        availableSpeakers = Array(Set(availableSpeakers + transcript.speakerNames)).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        [assignPopup, renamePopup].forEach { popup in
            popup.removeAllItems()
            popup.addItems(withTitles: availableSpeakers)
            popup.controlSize = .large
        }
        if let name {
            assignPopup.selectItem(withTitle: name)
            renamePopup.selectItem(withTitle: name)
        }
        tableView.reloadData()
    }

    @objc private func addSpeaker() {
        var number = 1
        while availableSpeakers.contains("Speaker \(number)") { number += 1 }
        let name = "Speaker \(number)"
        availableSpeakers.append(name)
        refreshSpeakers(selecting: name)
        statusLabel.stringValue = "Added \(name). Select transcript rows and assign them."
    }

    @objc private func assignSelected() {
        let rows = tableView.selectedRowIndexes
        guard !rows.isEmpty, let speaker = assignPopup.selectedItem?.title else {
            statusLabel.stringValue = "Select at least one transcript row first."
            return
        }
        let ids = Set(rows.compactMap { transcript.segments.indices.contains($0) ? transcript.segments[$0].id : nil })
        transcript = transcript.assigningSpeaker(speaker, to: ids)
        tableView.reloadData()
        statusLabel.stringValue = "Assigned \(rows.count) row\(rows.count == 1 ? "" : "s") to \(speaker)."
    }

    @objc private func renameEverywhere() {
        guard let oldName = renamePopup.selectedItem?.title else { return }
        let newName = renameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newName.isEmpty else {
            statusLabel.stringValue = "Enter the person’s name first."
            return
        }
        transcript = transcript.renamingSpeaker(from: oldName, to: newName)
        availableSpeakers.removeAll { $0 == oldName }
        availableSpeakers.append(newName)
        renameField.stringValue = ""
        refreshSpeakers(selecting: newName)
        statusLabel.stringValue = "Replaced \(oldName) with \(newName) everywhere."
    }

    @objc private func done() {
        onApply?(transcript)
        close()
    }

    private func timestamp(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        return String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
    }
}
