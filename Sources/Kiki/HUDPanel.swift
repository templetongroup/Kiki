import AppKit
import CoreGraphics

/// Small floating pill near the bottom of the screen showing recording state.
@MainActor
final class HUDPanel {
    private let panel: NSPanel
    private let effect: NSVisualEffectView
    private let gradient = CAGradientLayer()
    private let logoView: NSImageView
    private let statusLabel: NSTextField
    private let transcriptLabel: NSTextField

    init() {
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 220, height: 48),
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered,
                        defer: false)
        panel.title = "Kiki Live Transcription"
        panel.level = .statusBar
        panel.isFloatingPanel = true
        panel.isReleasedWhenClosed = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.setAccessibilityTitle("Kiki Live Transcription")

        effect = NSVisualEffectView()
        effect.material = .hudWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 14
        effect.layer?.cornerCurve = .continuous
        effect.layer?.masksToBounds = true
        gradient.locations = [0, 1]
        gradient.startPoint = CGPoint(x: 0, y: 1)
        gradient.endPoint = CGPoint(x: 1, y: 0)
        effect.layer?.addSublayer(gradient)

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
        present(width: width, height: 54)
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
        present(width: 440, height: 82)
    }

    private func present(width: CGFloat, height: CGFloat) {
        let frame = positionedFrame(width: width, height: height)
        panel.alphaValue = 1
        panel.setFrame(frame, display: true)
        effect.layoutSubtreeIfNeeded()
        gradient.frame = effect.bounds
        panel.orderFrontRegardless()
        panel.displayIfNeeded()
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
           let placement = caretPlacement(for: caret) {
            return clampedFrame(
                near: placement.point,
                visibleFrame: placement.screen.visibleFrame,
                width: width,
                height: height
            )
        }

        let pointer = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(pointer) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: width, height: height)
        return NSRect(
            x: visible.midX - width / 2,
            y: visible.minY + 60,
            width: width,
            height: height
        )
    }

    private func caretPlacement(for caret: CGRect) -> (point: NSPoint, screen: NSScreen)? {
        let quartzPoint = CGPoint(x: caret.midX, y: caret.midY)
        for screen in NSScreen.screens {
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                continue
            }
            let quartzFrame = CGDisplayBounds(CGDirectDisplayID(number.uint32Value))
            guard quartzFrame.contains(quartzPoint) else { continue }
            let point = NSPoint(
                x: screen.frame.minX + quartzPoint.x - quartzFrame.minX,
                y: screen.frame.maxY - (quartzPoint.y - quartzFrame.minY)
            )
            return (point, screen)
        }
        return nil
    }

    private func clampedFrame(
        near point: NSPoint,
        visibleFrame: NSRect,
        width: CGFloat,
        height: CGFloat
    ) -> NSRect {
        let margin: CGFloat = 8
        let gap: CGFloat = 14
        let minimumX = visibleFrame.minX + margin
        let maximumX = max(minimumX, visibleFrame.maxX - width - margin)
        let minimumY = visibleFrame.minY + margin
        let maximumY = max(minimumY, visibleFrame.maxY - height - margin)
        let belowCaret = point.y - height - gap
        let desiredY = belowCaret >= minimumY ? belowCaret : point.y + gap
        return NSRect(
            x: min(max(point.x - width / 2, minimumX), maximumX),
            y: min(max(desiredY, minimumY), maximumY),
            width: width,
            height: height
        )
    }

    private func applyAppearance() {
        panel.appearance = Settings.appearanceMode.appearance
        panel.effectiveAppearance.performAsCurrentDrawingAppearance {
            gradient.colors = [
                KikiPalette.elevatedSurface.withAlphaComponent(0.97).cgColor,
                KikiPalette.canvas.withAlphaComponent(0.97).cgColor,
            ]
            effect.layer?.borderWidth = 1
            effect.layer?.borderColor = KikiPalette.strongStroke.cgColor
            effect.layer?.shadowColor = NSColor.black.cgColor
            effect.layer?.shadowOpacity = 0.18
            effect.layer?.shadowRadius = 16
        }
    }

    func hide() {
        panel.orderOut(nil)
    }

    var isVisibleOnScreen: Bool {
        panel.isVisible && NSScreen.screens.contains { $0.visibleFrame.intersects(panel.frame) }
    }
}
