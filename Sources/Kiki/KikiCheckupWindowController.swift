import AppKit

struct KikiCheckupSnapshot: Equatable {
    let microphoneAuthorized: Bool
    let inputResponding: Bool
    let accessibilityAuthorized: Bool
    let modelStatus: ModelPreparationStatus
    let shortcutVerified: Bool
    let firstDictationCompleted: Bool

    var isReady: Bool {
        microphoneAuthorized
            && inputResponding
            && accessibilityAuthorized
            && modelStatus.isReady
            && shortcutVerified
            && firstDictationCompleted
    }
}

@MainActor
final class KikiCheckupWindowController: NSWindowController {
    struct Microphone: Equatable {
        let name: String
        let uniqueID: String
    }

    var onRefresh: (() -> Void)?
    var onTestShortcut: (() -> Void)?
    var onBeginPractice: (() -> Void)?
    var onOpenModels: (() -> Void)?
    var onMicrophoneSelected: ((String) -> Void)?
    var onInputDetected: (() -> Void)?
    var onWillClose: (() -> Void)?

    private let readinessLabel = kikiLabel("Finish the checks below", size: 15, weight: .semibold)
    private let microphonePopup = NSPopUpButton()
    private let inputMeter = KikiCheckupInputMeter()
    private let practiceText = NSTextView()
    private lazy var microphoneRow = KikiCheckupStatusRow(
        title: "Microphone permission",
        actionTitle: "Open settings",
        actionIdentifier: "kiki.checkup.readiness.microphone.action",
        target: self,
        action: #selector(openMicrophoneSettings)
    )
    private let inputRow = KikiCheckupStatusRow(title: "Live input")
    private lazy var accessibilityRow = KikiCheckupStatusRow(
        title: "Accessibility permission",
        actionTitle: "Open settings",
        actionIdentifier: "kiki.checkup.readiness.accessibility.action",
        target: self,
        action: #selector(openAccessibilitySettings)
    )
    private lazy var modelRow = KikiCheckupStatusRow(
        title: "Local model",
        actionTitle: "Open Models",
        actionIdentifier: "kiki.checkup.readiness.model.action",
        target: self,
        action: #selector(openModels)
    )
    private let modelProgress = NSProgressIndicator()
    private lazy var shortcutRow = KikiCheckupStatusRow(
        title: "Dictation shortcut",
        actionTitle: "Test shortcut",
        actionIdentifier: "kiki.checkup.readiness.shortcut.action",
        target: self,
        action: #selector(testShortcut)
    )
    private lazy var firstDictationRow = KikiCheckupStatusRow(
        title: "First dictation",
        actionTitle: "Try dictation",
        actionIdentifier: "kiki.checkup.readiness.first-dictation.action",
        target: self,
        action: #selector(beginPractice)
    )
    private lazy var practiceButton = KikiActionButton("Try Dictation", kind: .primary, target: self, action: #selector(beginPractice))
    private let monitor = AudioRecorder()
    private var hasDetectedInput = false

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 650),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Kiki Checkup"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = false
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        buildContent()
        update(
            snapshot: KikiCheckupSnapshot(
                microphoneAuthorized: false,
                inputResponding: false,
                accessibilityAuthorized: false,
                modelStatus: .unavailable(model: Settings.transcriptionModel),
                shortcutVerified: false,
                firstDictationCompleted: false
            )
        )
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show() {
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func setMicrophones(_ microphones: [Microphone], selectedID: String?) {
        microphonePopup.removeAllItems()
        for microphone in microphones {
            microphonePopup.addItem(withTitle: microphone.name)
            microphonePopup.lastItem?.representedObject = microphone.uniqueID
        }
        if let selectedID,
           let index = microphonePopup.itemArray.firstIndex(where: { ($0.representedObject as? String) == selectedID }) {
            microphonePopup.selectItem(at: index)
        } else if microphonePopup.numberOfItems > 0 {
            microphonePopup.selectItem(at: 0)
        }
        microphonePopup.isEnabled = !microphones.isEmpty
        if microphones.isEmpty { microphonePopup.addItem(withTitle: "No microphone found") }
    }

    func updateInputLevel(_ level: CGFloat) {
        inputMeter.level = level
    }

    func startInputMonitor() {
        stopInputMonitor()
        hasDetectedInput = false
        monitor.setSamplesHandler { [weak self] samples in
            let level = VoiceLevelMeter.normalizedLevel(for: samples)
            DispatchQueue.main.async {
                guard let self else { return }
                self.updateInputLevel(level)
                if !self.hasDetectedInput, level > 0.08 {
                    self.hasDetectedInput = true
                    self.onInputDetected?()
                }
            }
        }
        do {
            try monitor.start()
        } catch {
            monitor.setSamplesHandler(nil)
            updateInputLevel(0)
        }
    }

    func stopInputMonitor() {
        _ = monitor.stop()
        monitor.setSamplesHandler(nil)
        updateInputLevel(0)
    }

    func armShortcutTest() {
        shortcutRow.update(
            passed: false,
            detail: "Waiting",
            guidance: "\(Settings.activationMode.shortcutTestInstruction(for: Settings.dictationShortcut)) Kiki will mark this check complete.",
            showsAction: false
        )
    }

    func preparePractice() {
        stopInputMonitor()
        practiceText.string = ""
        practiceText.window?.makeFirstResponder(practiceText)
        firstDictationRow.update(
            passed: false,
            detail: "In progress",
            guidance: "Speak, then click Stop & Insert. Your text will appear in the field.",
            showsAction: false
        )
    }

    func update(snapshot: KikiCheckupSnapshot) {
        microphoneRow.update(
            passed: snapshot.microphoneAuthorized,
            detail: snapshot.microphoneAuthorized ? "Allowed" : "Action needed",
            guidance: snapshot.microphoneAuthorized ? nil : "Allow Kiki to use your microphone in System Settings.",
            showsAction: !snapshot.microphoneAuthorized
        )
        inputRow.update(
            passed: snapshot.inputResponding,
            detail: snapshot.inputResponding ? "Signal detected" : "Waiting for sound",
            guidance: snapshot.inputResponding ? nil : "Speak normally. The input meter above should move.",
            showsAction: false
        )
        accessibilityRow.update(
            passed: snapshot.accessibilityAuthorized,
            detail: snapshot.accessibilityAuthorized ? "Allowed" : "Action needed",
            guidance: snapshot.accessibilityAuthorized ? nil : "Allow Kiki to insert dictated text into other apps.",
            showsAction: !snapshot.accessibilityAuthorized
        )
        let modelNeedsAction: Bool
        switch snapshot.modelStatus {
        case .unavailable, .failed:
            modelNeedsAction = true
        case .downloading, .loading, .ready:
            modelNeedsAction = false
        }
        modelRow.update(
            passed: snapshot.modelStatus.isReady,
            detail: snapshot.modelStatus.checkupDetail,
            guidance: modelNeedsAction ? "Choose and download a speech model before dictating." : nil,
            showsAction: modelNeedsAction
        )
        if let fraction = snapshot.modelStatus.downloadFraction {
            modelProgress.doubleValue = fraction
            modelProgress.isHidden = false
            modelProgress.setAccessibilityValue("\(Int((fraction * 100).rounded(.down))) percent")
        } else {
            modelProgress.isHidden = true
        }
        shortcutRow.update(
            passed: snapshot.shortcutVerified,
            detail: snapshot.shortcutVerified ? "Verified" : "Needs a quick test",
            guidance: snapshot.shortcutVerified
                ? nil
                : "Click Test shortcut. \(Settings.activationMode.shortcutTestInstruction(for: Settings.dictationShortcut)) Kiki will confirm it works.",
            showsAction: !snapshot.shortcutVerified
        )
        firstDictationRow.update(
            passed: snapshot.firstDictationCompleted,
            detail: snapshot.firstDictationCompleted ? "Completed" : "Try it once",
            guidance: snapshot.firstDictationCompleted ? nil : "Use the guided field beside these checks to confirm text appears.",
            showsAction: !snapshot.firstDictationCompleted
        )
        let remaining = [
            snapshot.microphoneAuthorized,
            snapshot.inputResponding,
            snapshot.accessibilityAuthorized,
            snapshot.modelStatus.isReady,
            snapshot.shortcutVerified,
            snapshot.firstDictationCompleted,
        ].filter { !$0 }.count
        readinessLabel.stringValue = snapshot.isReady
            ? "Kiki is ready"
            : "\(remaining) setup check\(remaining == 1 ? "" : "s") remaining"
        readinessLabel.textColor = snapshot.isReady ? KikiPalette.accentText : KikiPalette.primaryText
    }

    func updateDictationState(_ state: DictationState) {
        switch state {
        case .noModel:
            practiceButton.title = "Model Unavailable"
            practiceButton.isEnabled = false
        case .loadingModel:
            practiceButton.title = "Loading Model…"
            practiceButton.isEnabled = false
        case .idle:
            practiceButton.title = "Try Dictation"
            practiceButton.isEnabled = true
        case .recording:
            practiceButton.title = "Stop & Insert"
            practiceButton.isEnabled = true
        case .transcribing:
            practiceButton.title = "Transcribing…"
            practiceButton.isEnabled = false
        }
    }

    private func buildContent() {
        guard let content = window?.contentView else { return }
        let backdrop = KikiBackdropView()
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(backdrop)

        let eyebrow = kikiLabel("SYSTEM CHECK · FULLY LOCAL", size: 11, weight: .semibold, color: KikiPalette.accentText)
        eyebrow.identifier = NSUserInterfaceItemIdentifier("kiki.checkup.eyebrow")
        let title = kikiLabel("Kiki Checkup", size: 30, weight: .bold)
        let intro = kikiLabel("Confirm your microphone, local model, shortcut, and first dictation before you rely on Kiki.", size: 14, color: KikiPalette.secondaryText)
        intro.maximumNumberOfLines = 0
        readinessLabel.identifier = NSUserInterfaceItemIdentifier("kiki.checkup.readiness")
        let header = NSStackView(views: [eyebrow, title, intro, readinessLabel])
        header.orientation = .vertical
        header.alignment = .leading
        header.spacing = 6

        microphonePopup.identifier = NSUserInterfaceItemIdentifier("kiki.checkup.microphone")
        microphonePopup.target = self
        microphonePopup.action = #selector(microphoneChanged)
        microphonePopup.focusRingType = .default
        inputMeter.identifier = NSUserInterfaceItemIdentifier("kiki.checkup.input-meter")
        let deviceTitle = kikiLabel("Input device", size: 13, weight: .semibold)
        let deviceHelp = kikiLabel("Choose a microphone, then speak normally. The meter should respond without reaching the end.", size: 12.5, color: KikiPalette.secondaryText)
        deviceHelp.maximumNumberOfLines = 0
        let deviceStack = NSStackView(views: [deviceTitle, microphonePopup, inputMeter, deviceHelp])
        deviceStack.orientation = .vertical
        deviceStack.alignment = .leading
        deviceStack.spacing = 8
        let deviceCard = card(containing: deviceStack)

        let checksTitle = kikiLabel("Readiness checks", size: 13, weight: .semibold)
        modelProgress.style = .bar
        modelProgress.isIndeterminate = false
        modelProgress.minValue = 0
        modelProgress.maxValue = 1
        modelProgress.controlSize = .small
        modelProgress.isHidden = true
        modelProgress.identifier = NSUserInterfaceItemIdentifier("kiki.checkup.model-progress")
        modelProgress.setAccessibilityLabel("Local model download progress")
        let statusStack = NSStackView(views: [
            checksTitle,
            microphoneRow,
            inputRow,
            accessibilityRow,
            modelRow,
            modelProgress,
            shortcutRow,
            firstDictationRow,
        ])
        statusStack.orientation = .vertical
        statusStack.alignment = .leading
        statusStack.spacing = 8
        [microphoneRow, inputRow, accessibilityRow, modelRow, shortcutRow, firstDictationRow].forEach {
            $0.widthAnchor.constraint(equalTo: statusStack.widthAnchor).isActive = true
        }
        modelProgress.widthAnchor.constraint(equalTo: statusStack.widthAnchor).isActive = true
        let statusCard = card(containing: statusStack)

        practiceText.string = "Kiki, this is my first private dictation."
        practiceText.font = .systemFont(ofSize: 14)
        practiceText.textColor = KikiPalette.primaryText
        practiceText.backgroundColor = KikiPalette.canvas.withAlphaComponent(0.58)
        practiceText.textContainerInset = NSSize(width: 10, height: 9)
        practiceText.isEditable = true
        practiceText.isSelectable = true
        let practiceScroll = NSScrollView()
        practiceScroll.documentView = practiceText
        practiceScroll.hasVerticalScroller = true
        practiceScroll.borderType = .noBorder
        practiceScroll.wantsLayer = true
        practiceScroll.layer?.cornerRadius = 6
        practiceScroll.heightAnchor.constraint(equalToConstant: 66).isActive = true
        let practiceTitle = kikiLabel("Guided first dictation", size: 13, weight: .semibold)
        let practiceHelp = kikiLabel("Speak into the field below. Click Try Dictation to begin, then Stop & Insert when you're done.", size: 12.5, color: KikiPalette.secondaryText)
        practiceHelp.maximumNumberOfLines = 0
        practiceButton.identifier = NSUserInterfaceItemIdentifier("kiki.checkup.practice")
        let practiceStack = NSStackView(views: [practiceTitle, practiceHelp, practiceScroll, practiceButton])
        practiceStack.orientation = .vertical
        practiceStack.alignment = .leading
        practiceStack.spacing = 8
        let practiceCard = card(containing: practiceStack)

        let refresh = KikiActionButton("Refresh Checks", kind: .hardware, target: self, action: #selector(refreshChecks))
        refresh.identifier = NSUserInterfaceItemIdentifier("kiki.checkup.footer.refresh")
        practiceButton.heightAnchor.constraint(equalToConstant: 40).isActive = true
        refresh.heightAnchor.constraint(equalToConstant: 36).isActive = true
        refresh.widthAnchor.constraint(equalToConstant: 140).isActive = true
        let footer = NSStackView(views: [NSView(), refresh])
        footer.orientation = .horizontal
        footer.alignment = .centerY

        let bodyColumns = KikiCheckupBodyStack(statusCard: statusCard, practiceCard: practiceCard)
        bodyColumns.identifier = NSUserInterfaceItemIdentifier("kiki.checkup.body")
        statusCard.widthAnchor.constraint(equalTo: practiceCard.widthAnchor).isActive = true

        let stack = NSStackView(views: [header, deviceCard, bodyColumns, footer])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)

        NSLayoutConstraint.activate([
            backdrop.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            backdrop.topAnchor.constraint(equalTo: content.topAnchor),
            backdrop.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 44),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -22),
            intro.widthAnchor.constraint(equalTo: stack.widthAnchor),
            deviceCard.widthAnchor.constraint(equalTo: stack.widthAnchor),
            microphonePopup.widthAnchor.constraint(equalTo: deviceStack.widthAnchor),
            inputMeter.widthAnchor.constraint(equalTo: deviceStack.widthAnchor),
            inputMeter.heightAnchor.constraint(equalToConstant: 14),
            deviceStack.widthAnchor.constraint(equalTo: deviceCard.widthAnchor, constant: -28),
            bodyColumns.widthAnchor.constraint(equalTo: stack.widthAnchor),
            statusStack.widthAnchor.constraint(equalTo: statusCard.widthAnchor, constant: -28),
            practiceStack.widthAnchor.constraint(equalTo: practiceCard.widthAnchor, constant: -28),
            practiceScroll.widthAnchor.constraint(equalTo: practiceStack.widthAnchor),
            practiceButton.widthAnchor.constraint(equalTo: practiceStack.widthAnchor),
            footer.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
    }

    private func card(containing stack: NSStackView) -> KikiCardView {
        let card = KikiCardView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -14),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 13),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -13),
        ])
        return card
    }

    @objc private func refreshChecks() { onRefresh?() }
    @objc private func testShortcut() { onTestShortcut?() }
    @objc private func beginPractice() { onBeginPractice?() }
    @objc private func openModels() { onOpenModels?() }
    @objc private func microphoneChanged() {
        guard let uniqueID = microphonePopup.selectedItem?.representedObject as? String else { return }
        onMicrophoneSelected?(uniqueID)
    }
    @objc private func openMicrophoneSettings() {
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!
        )
    }
    @objc private func openAccessibilitySettings() {
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        )
    }
}

extension KikiCheckupWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        stopInputMonitor()
        onWillClose?()
    }
}

@MainActor
private final class KikiCheckupBodyStack: NSStackView {
    private let statusCard: NSView
    private let practiceCard: NSView
    private var stackedWidthConstraints: [NSLayoutConstraint] = []
    private var usesStackedLayout: Bool?

    init(statusCard: NSView, practiceCard: NSView) {
        self.statusCard = statusCard
        self.practiceCard = practiceCard
        super.init(frame: .zero)
        addArrangedSubview(statusCard)
        addArrangedSubview(practiceCard)
        spacing = 14
        stackedWidthConstraints = [
            statusCard.widthAnchor.constraint(equalTo: widthAnchor),
            practiceCard.widthAnchor.constraint(equalTo: widthAnchor),
        ]
        updateLayout(for: frame.width)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func setFrameSize(_ newSize: NSSize) {
        updateLayout(for: newSize.width)
        super.setFrameSize(newSize)
    }

    override func layout() {
        updateLayout(for: bounds.width)
        super.layout()
    }

    private func updateLayout(for width: CGFloat) {
        let stacked = width < 720
        guard usesStackedLayout != stacked else { return }
        usesStackedLayout = stacked
        if stacked {
            orientation = .vertical
            alignment = .leading
            distribution = .fill
            NSLayoutConstraint.activate(stackedWidthConstraints)
        } else {
            NSLayoutConstraint.deactivate(stackedWidthConstraints)
            orientation = .horizontal
            alignment = .top
            distribution = .fillEqually
        }
    }
}

@MainActor
private final class KikiCheckupStatusRow: NSView {
    private let indicator = NSView()
    private let titleLabel: NSTextField
    private let detailLabel = kikiLabel("Not checked", size: 11.5, color: KikiPalette.secondaryText)
    private let guidanceLabel = kikiLabel("", size: 11.5, color: KikiPalette.secondaryText)
    private var actionButton: KikiActionButton?
    private var guidanceRow: NSStackView?
    private var actionRow: NSStackView?

    init(
        title: String,
        actionTitle: String? = nil,
        actionIdentifier: String? = nil,
        target: AnyObject? = nil,
        action: Selector? = nil
    ) {
        titleLabel = kikiLabel(title, size: 12.5, weight: .medium)
        super.init(frame: .zero)
        indicator.wantsLayer = true
        indicator.layer?.cornerRadius = 4
        detailLabel.maximumNumberOfLines = 1
        detailLabel.lineBreakMode = .byTruncatingTail
        detailLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        guidanceLabel.maximumNumberOfLines = 0
        guidanceLabel.lineBreakMode = .byWordWrapping
        if let actionIdentifier {
            let baseIdentifier = actionIdentifier.replacingOccurrences(of: ".action", with: "")
            identifier = NSUserInterfaceItemIdentifier(baseIdentifier)
            detailLabel.identifier = NSUserInterfaceItemIdentifier("\(baseIdentifier).detail")
            guidanceLabel.identifier = NSUserInterfaceItemIdentifier("\(baseIdentifier).guidance")
        }
        let heading = NSStackView(views: [indicator, titleLabel, NSView(), detailLabel])
        heading.orientation = .horizontal
        heading.alignment = .centerY
        heading.spacing = 8
        let guidanceIndent = NSView()
        guidanceIndent.widthAnchor.constraint(equalToConstant: 16).isActive = true
        let guidance = NSStackView(views: [guidanceIndent, guidanceLabel])
        guidance.orientation = .horizontal
        guidance.alignment = .top
        guidance.spacing = 0
        guidance.isHidden = true
        guidanceRow = guidance

        var rows: [NSView] = [heading, guidance]
        if let actionTitle, let action {
            let button = KikiActionButton(actionTitle, kind: .hardware, target: target, action: action)
            if let actionIdentifier {
                button.identifier = NSUserInterfaceItemIdentifier(actionIdentifier)
            }
            button.widthAnchor.constraint(equalToConstant: 128).isActive = true
            button.heightAnchor.constraint(equalToConstant: 30).isActive = true
            actionButton = button
            let actionIndent = NSView()
            actionIndent.widthAnchor.constraint(equalToConstant: 16).isActive = true
            let actionContainer = NSStackView(views: [actionIndent, button, NSView()])
            actionContainer.orientation = .horizontal
            actionContainer.alignment = .centerY
            actionContainer.spacing = 0
            actionContainer.isHidden = true
            actionRow = actionContainer
            rows.append(actionContainer)
        }
        let stack = NSStackView(views: rows)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        heading.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        guidance.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        actionRow?.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        NSLayoutConstraint.activate([
            indicator.widthAnchor.constraint(equalToConstant: 8),
            indicator.heightAnchor.constraint(equalToConstant: 8),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(passed: Bool, detail: String, guidance: String?, showsAction: Bool) {
        indicator.layer?.backgroundColor = (passed ? KikiPalette.accentText : KikiPalette.tertiaryText).cgColor
        detailLabel.stringValue = detail
        guidanceLabel.stringValue = guidance ?? ""
        guidanceRow?.isHidden = guidance == nil
        actionRow?.isHidden = !showsAction
        actionButton?.isHidden = !showsAction
        actionButton?.setAccessibilityHelp(guidance ?? "")
    }
}

@MainActor
private final class KikiCheckupInputMeter: NSView {
    var level: CGFloat = 0 { didSet { needsDisplay = true } }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let track = NSBezierPath(roundedRect: bounds, xRadius: 5, yRadius: 5)
        KikiPalette.elevatedSurface.setFill()
        track.fill()
        let normalized = CGFloat(max(0, min(1, level)))
        guard normalized > 0 else { return }
        let fillRect = NSRect(x: 0, y: 0, width: bounds.width * normalized, height: bounds.height)
        let fill = NSBezierPath(roundedRect: fillRect, xRadius: 5, yRadius: 5)
        KikiPalette.meterAccent.setFill()
        fill.fill()
    }
}
