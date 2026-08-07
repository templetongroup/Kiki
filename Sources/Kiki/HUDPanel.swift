import AppKit

/// Small floating pill near the bottom of the screen showing recording state.
@MainActor
final class HUDPanel {
    private let panel: NSPanel
    private let effect: NSVisualEffectView
    private let logoView: NSImageView
    private let statusLabel: NSTextField
    private let transcriptLabel: NSTextField

    init() {
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 220, height: 48),
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered,
                        defer: true)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        effect = NSVisualEffectView()
        effect.material = .hudWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 14
        effect.layer?.masksToBounds = true

        logoView = NSImageView()
        logoView.imageScaling = .scaleProportionallyUpOrDown
        if let url = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png") {
            logoView.image = NSImage(contentsOf: url)
        }
        logoView.isHidden = logoView.image == nil

        statusLabel = NSTextField(labelWithString: "")
        statusLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        statusLabel.textColor = .secondaryLabelColor

        transcriptLabel = NSTextField(wrappingLabelWithString: "")
        transcriptLabel.font = .systemFont(ofSize: 15, weight: .medium)
        transcriptLabel.maximumNumberOfLines = 2
        transcriptLabel.lineBreakMode = .byTruncatingHead
        transcriptLabel.isHidden = true

        let textStack = NSStackView(views: [statusLabel, transcriptLabel])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 3

        let content = NSStackView(views: [logoView, textStack])
        content.orientation = .horizontal
        content.alignment = .centerY
        content.spacing = 12
        content.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(content)
        NSLayoutConstraint.activate([
            logoView.widthAnchor.constraint(equalToConstant: 38),
            logoView.heightAnchor.constraint(equalToConstant: 38),
            transcriptLabel.widthAnchor.constraint(equalToConstant: 350),
            content.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 14),
            content.trailingAnchor.constraint(lessThanOrEqualTo: effect.trailingAnchor, constant: -14),
            content.centerYAnchor.constraint(equalTo: effect.centerYAnchor),
        ])

        panel.contentView = effect
    }

    func show(_ text: String) {
        applyAppearance()
        statusLabel.stringValue = text
        statusLabel.textColor = .labelColor
        transcriptLabel.isHidden = true
        let logoWidth: CGFloat = logoView.isHidden ? 0 : 37
        let width = max(180, statusLabel.intrinsicContentSize.width + logoWidth + 54)
        let frame = positionedFrame(width: width, height: 54)
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
    }

    func showListening(transcript: String? = nil) {
        applyAppearance()
        statusLabel.stringValue = "●  Listening"
        statusLabel.textColor = Settings.accentColor.color
        transcriptLabel.stringValue = displayText(transcript)
        transcriptLabel.textColor = transcript == nil ? .secondaryLabelColor : .labelColor
        transcriptLabel.isHidden = false
        showExpanded()
    }

    func showTranscribing(transcript: String? = nil) {
        applyAppearance()
        statusLabel.stringValue = "Transcribing…"
        statusLabel.textColor = .secondaryLabelColor
        transcriptLabel.stringValue = displayText(transcript)
        transcriptLabel.textColor = transcript == nil ? .secondaryLabelColor : .labelColor
        transcriptLabel.isHidden = false
        showExpanded()
    }

    private func showExpanded() {
        let width: CGFloat = 440
        let frame = positionedFrame(width: width, height: 82)
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
    }

    private func displayText(_ transcript: String?) -> String {
        guard let transcript, !transcript.isEmpty else { return "Speak now…" }
        let limit = 220
        guard transcript.count > limit else { return transcript }
        return "…" + transcript.suffix(limit)
    }

    private func positionedFrame(width: CGFloat, height: CGFloat) -> NSRect {
        if Settings.showHUDNearCaret,
           let caret = AppContextSnapshot.caretScreenRect(),
           let primary = NSScreen.screens.first {
            let point = NSPoint(x: caret.midX, y: primary.frame.maxY - caret.midY)
            let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.main
            if let visible = screen?.visibleFrame {
                let desiredX = point.x - width / 2
                let desiredY = point.y - height - 14
                return NSRect(
                    x: min(max(desiredX, visible.minX + 8), visible.maxX - width - 8),
                    y: min(max(desiredY, visible.minY + 8), visible.maxY - height - 8),
                    width: width,
                    height: height
                )
            }
        }
        let visible = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame ?? .zero
        return NSRect(
            x: visible.midX - width / 2,
            y: visible.minY + 60,
            width: width,
            height: height
        )
    }

    private func applyAppearance() {
        panel.appearance = Settings.appearanceMode.appearance
        effect.layer?.borderWidth = 1
        effect.layer?.borderColor = Settings.accentColor.color.withAlphaComponent(0.45).cgColor
    }

    func hide() {
        panel.orderOut(nil)
    }
}
