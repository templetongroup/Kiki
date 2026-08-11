import AppKit

@MainActor
final class PawprintsWindowController: NSWindowController {
    private let enableCheckbox = NSButton(
        checkboxWithTitle: "Collect private, aggregate-only Pawprints on this Mac",
        target: nil,
        action: nil
    )
    private let dictationsValue = kikiLabel("0", size: 30, weight: .bold)
    private let wordsValue = kikiLabel("0", size: 30, weight: .bold)
    private let timeValue = kikiLabel("0 min", size: 30, weight: .bold)
    private let daysValue = kikiLabel("0", size: 30, weight: .bold)
    private let statusLabel = kikiLabel("Pawprints are off", size: 12.5, weight: .semibold, color: KikiPalette.secondaryText)

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 520),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Kiki Pawprints"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = false
        window.isReleasedWhenClosed = false
        super.init(window: window)
        buildContent()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(pawprintsDidChange),
            name: PawprintsStore.didChangeNotification,
            object: nil
        )
        refresh()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show() {
        refresh()
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

        let eyebrow = kikiLabel("LOCAL ACTIVITY · NO TRANSCRIPTS", size: 11, weight: .bold, color: KikiPalette.accentText)
        eyebrow.identifier = NSUserInterfaceItemIdentifier("kiki.pawprints.eyebrow")
        let title = kikiLabel("Pawprints", size: 31, weight: .bold)
        let intro = kikiLabel("A small, private view of how Kiki helps—built from totals only. Dictated text, recordings, app names, and Private Sessions are never included.", size: 14, color: KikiPalette.secondaryText)
        intro.maximumNumberOfLines = 0
        let header = NSStackView(views: [eyebrow, title, intro, statusLabel])
        header.orientation = .vertical
        header.alignment = .leading
        header.spacing = 6

        let summary = NSStackView(views: [
            metricCard(value: dictationsValue, label: "DICTATIONS"),
            metricCard(value: wordsValue, label: "WORDS"),
            metricCard(value: timeValue, label: "TIME SAVED"),
            metricCard(value: daysValue, label: "ACTIVE DAYS"),
        ])
        summary.identifier = NSUserInterfaceItemIdentifier("kiki.pawprints.summary")
        summary.orientation = .horizontal
        summary.distribution = .fillEqually
        summary.spacing = 12

        enableCheckbox.identifier = NSUserInterfaceItemIdentifier("kiki.pawprints.enable")
        enableCheckbox.target = self
        enableCheckbox.action = #selector(toggleEnabled)
        enableCheckbox.contentTintColor = KikiPalette.accentText
        let privacy = kikiLabel("Stored locally as daily counts and durations. Turning this off stops collection; Reset permanently removes every Pawprint.", size: 12, color: KikiPalette.secondaryText)
        privacy.maximumNumberOfLines = 0
        let reset = KikiActionButton("Reset Pawprints", kind: .danger, target: self, action: #selector(resetPawprints))
        let controls = NSStackView(views: [enableCheckbox, privacy, reset])
        controls.orientation = .vertical
        controls.alignment = .leading
        controls.spacing = 10
        let controlsCard = KikiCardView()
        controls.translatesAutoresizingMaskIntoConstraints = false
        controlsCard.addSubview(controls)
        NSLayoutConstraint.activate([
            controls.leadingAnchor.constraint(equalTo: controlsCard.leadingAnchor, constant: 16),
            controls.trailingAnchor.constraint(equalTo: controlsCard.trailingAnchor, constant: -16),
            controls.topAnchor.constraint(equalTo: controlsCard.topAnchor, constant: 15),
            controls.bottomAnchor.constraint(equalTo: controlsCard.bottomAnchor, constant: -15),
            privacy.widthAnchor.constraint(equalTo: controls.widthAnchor),
        ])

        let root = NSStackView(views: [header, summary, controlsCard])
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 16
        root.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(root)
        NSLayoutConstraint.activate([
            backdrop.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            backdrop.topAnchor.constraint(equalTo: content.topAnchor),
            backdrop.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            root.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 26),
            root.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -26),
            root.topAnchor.constraint(equalTo: content.topAnchor, constant: 46),
            root.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -24),
            intro.widthAnchor.constraint(equalTo: root.widthAnchor),
            summary.widthAnchor.constraint(equalTo: root.widthAnchor),
            summary.heightAnchor.constraint(equalToConstant: 120),
            controlsCard.widthAnchor.constraint(equalTo: root.widthAnchor),
        ])
    }

    private func metricCard(value: NSTextField, label: String) -> KikiCardView {
        value.textColor = KikiPalette.accentText
        let caption = kikiLabel(label, size: 10.5, weight: .bold, color: KikiPalette.secondaryText)
        let stack = NSStackView(views: [value, caption])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        let card = KikiCardView()
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 15),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: card.trailingAnchor, constant: -12),
            stack.centerYAnchor.constraint(equalTo: card.centerYAnchor),
        ])
        return card
    }

    private func refresh() {
        let summary = PawprintsStore.shared.summary
        dictationsValue.stringValue = summary.dictations.formatted()
        wordsValue.stringValue = summary.words.formatted()
        let typingSeconds = Double(summary.words) / 40 * 60
        let savedMinutes = max(0, Int(((typingSeconds - summary.speakingSeconds) / 60).rounded()))
        timeValue.stringValue = "\(savedMinutes) min"
        daysValue.stringValue = summary.activeDays.formatted()
        enableCheckbox.state = Settings.pawprintsEnabled ? .on : .off
        statusLabel.stringValue = Settings.pawprintsEnabled
            ? "Pawprints are on · Private Sessions never count"
            : "Pawprints are off"
        statusLabel.textColor = Settings.pawprintsEnabled ? KikiPalette.accentText : KikiPalette.secondaryText
        statusLabel.identifier = NSUserInterfaceItemIdentifier("kiki.pawprints.status")
    }

    @objc private func toggleEnabled() {
        Settings.pawprintsEnabled = enableCheckbox.state == .on
        refresh()
    }

    @objc private func pawprintsDidChange() { refresh() }

    @objc private func resetPawprints() {
        let alert = NSAlert()
        alert.messageText = "Reset Pawprints?"
        alert.informativeText = "This permanently removes every locally stored aggregate. Dictation itself is not affected."
        alert.addButton(withTitle: "Reset Pawprints")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        guard PawprintsStore.shared.reset() else {
            let failure = NSAlert()
            failure.messageText = "Pawprints could not be reset"
            failure.informativeText = "Kiki left the existing totals unchanged. Try again after checking access to Kiki’s Application Support folder."
            failure.runModal()
            return
        }
    }
}
