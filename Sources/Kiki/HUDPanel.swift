import AppKit
import CoreGraphics

/// Small floating pill near the bottom of the screen showing recording state.
@MainActor
final class HUDPanel {
    private let panel: NSPanel
    private let effect: NSView
    private let logoView: NSImageView
    private let statusLabel: NSTextField
    private let transcriptLabel: NSTextField
    private let waveformView = KikiWaveformView()
    private let textStack = NSStackView()
    private var hasLogo = false
    private var presentation: Presentation?

    private enum Presentation { case message, transcript, waveform }

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

        effect = NSView()
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 9
        effect.layer?.cornerCurve = .continuous
        effect.layer?.masksToBounds = true

        logoView = NSImageView()
        logoView.imageScaling = .scaleProportionallyUpOrDown
        if let url = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png") {
            logoView.image = NSImage(contentsOf: url)
        }
        logoView.isHidden = logoView.image == nil
        hasLogo = logoView.image != nil

        statusLabel = NSTextField(labelWithString: "")
        statusLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        statusLabel.textColor = .secondaryLabelColor

        transcriptLabel = NSTextField(wrappingLabelWithString: "")
        transcriptLabel.font = .systemFont(ofSize: 13, weight: .medium)
        transcriptLabel.maximumNumberOfLines = 1
        transcriptLabel.lineBreakMode = .byTruncatingTail
        transcriptLabel.isHidden = true

        textStack.setViews([statusLabel, transcriptLabel], in: .leading)
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2

        waveformView.isHidden = true
        let content = NSStackView(views: [logoView, textStack, waveformView])
        content.orientation = .horizontal
        content.alignment = .centerY
        content.spacing = 10
        content.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(content)
        NSLayoutConstraint.activate([
            logoView.widthAnchor.constraint(equalToConstant: 34),
            logoView.heightAnchor.constraint(equalToConstant: 34),
            transcriptLabel.widthAnchor.constraint(equalToConstant: 300),
            waveformView.widthAnchor.constraint(equalToConstant: KikiWaveformView.preferredSize.width),
            waveformView.heightAnchor.constraint(equalToConstant: KikiWaveformView.preferredSize.height),
            content.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 12),
            content.trailingAnchor.constraint(lessThanOrEqualTo: effect.trailingAnchor, constant: -12),
            content.centerYAnchor.constraint(equalTo: effect.centerYAnchor),
        ])

        panel.contentView = effect
    }

    func show(_ text: String) {
        applyAppearance()
        presentation = .message
        logoView.isHidden = !hasLogo
        textStack.isHidden = false
        waveformView.isHidden = true
        waveformView.stopAnimating()
        statusLabel.stringValue = text
        statusLabel.textColor = .labelColor
        transcriptLabel.isHidden = true
        let logoWidth: CGFloat = logoView.isHidden ? 0 : 37
        let width = max(180, statusLabel.intrinsicContentSize.width + logoWidth + 54)
        present(width: width, height: 54)
    }

    func showListening(transcript: String? = nil) {
        applyAppearance()
        let needsPresentation = presentation != .transcript || !panel.isVisible
        presentation = .transcript
        logoView.isHidden = !hasLogo
        textStack.isHidden = false
        waveformView.isHidden = true
        waveformView.stopAnimating()
        statusLabel.stringValue = "Listening"
        statusLabel.textColor = KikiPalette.accentText
        transcriptLabel.stringValue = displayText(transcript)
        transcriptLabel.textColor = transcript == nil ? .secondaryLabelColor : .labelColor
        transcriptLabel.isHidden = false
        if needsPresentation { showExpanded() }
    }

    func showWaveform(level: CGFloat, reset: Bool = false) {
        applyAppearance()
        let needsPresentation = presentation != .waveform || !panel.isVisible
        presentation = .waveform
        logoView.isHidden = true
        textStack.isHidden = true
        waveformView.isHidden = false
        if reset { waveformView.reset() }
        waveformView.level = level
        if needsPresentation { present(width: 252, height: 62) }
    }

    func showTranscribing(transcript: String? = nil) {
        applyAppearance()
        presentation = .transcript
        logoView.isHidden = !hasLogo
        textStack.isHidden = false
        waveformView.isHidden = true
        waveformView.stopAnimating()
        statusLabel.stringValue = "Transcribing…"
        statusLabel.textColor = .secondaryLabelColor
        transcriptLabel.stringValue = displayText(transcript)
        transcriptLabel.textColor = transcript == nil ? .secondaryLabelColor : .labelColor
        transcriptLabel.isHidden = false
        showExpanded()
    }

    private func showExpanded() {
        present(width: 410, height: 66)
    }

    private func present(width: CGFloat, height: CGFloat) {
        let frame = positionedFrame(width: width, height: height)
        panel.alphaValue = 1
        panel.setFrame(frame, display: true)
        effect.layoutSubtreeIfNeeded()
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
        if Settings.listeningDisplayPosition == .nearTargetWindow,
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
        return Self.fixedFrame(
            position: Settings.listeningDisplayPosition,
            visibleFrame: visible,
            width: width,
            height: height
        )
    }

    static func fixedFrame(
        position: ListeningDisplayPosition,
        visibleFrame visible: NSRect,
        width: CGFloat,
        height: CGFloat
    ) -> NSRect {
        let horizontalMargin: CGFloat = 24
        let verticalMargin: CGFloat = 32
        let centeredX = visible.midX - width / 2
        let topY = visible.maxY - height - verticalMargin
        let bottomY = visible.minY + verticalMargin
        let leftX = visible.minX + horizontalMargin
        let rightX = visible.maxX - width - horizontalMargin
        let origin: NSPoint
        switch position {
        case .top: origin = NSPoint(x: centeredX, y: topY)
        case .topLeft: origin = NSPoint(x: leftX, y: topY)
        case .topRight: origin = NSPoint(x: rightX, y: topY)
        case .bottomLeft: origin = NSPoint(x: leftX, y: bottomY)
        case .bottomRight: origin = NSPoint(x: rightX, y: bottomY)
        case .bottom, .nearTargetWindow: origin = NSPoint(x: centeredX, y: bottomY)
        }
        return NSRect(origin: origin, size: NSSize(width: width, height: height))
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
            effect.layer?.backgroundColor = KikiPalette.elevatedSurface.withAlphaComponent(0.98).cgColor
            effect.layer?.borderWidth = 1
            effect.layer?.borderColor = KikiPalette.strongStroke.cgColor
            effect.layer?.shadowColor = NSColor.black.cgColor
            effect.layer?.shadowOpacity = 0.18
            effect.layer?.shadowRadius = 16
        }
    }

    func hide() {
        presentation = nil
        waveformView.level = 0
        waveformView.stopAnimating()
        panel.orderOut(nil)
    }

    var isVisibleOnScreen: Bool {
        panel.isVisible && NSScreen.screens.contains { $0.visibleFrame.intersects(panel.frame) }
    }
}

enum VoiceLevelMeter {
    static func normalizedLevel(for samples: [Float]) -> CGFloat {
        guard !samples.isEmpty else { return 0 }
        let meanSquare = samples.reduce(0.0) { $0 + Double($1 * $1) } / Double(samples.count)
        let rms = meanSquare.squareRoot()
        let peak = samples.reduce(0.0) { max($0, Double(abs($1))) }
        guard peak > 0.0015 else { return 0 }

        // A logarithmic meter preserves visible motion in a normal speaking range.
        // The former linear scale spent most of its time close to zero unless the
        // microphone signal was unusually loud.
        let weightedAmplitude = max((rms * 0.74) + (peak * 0.26), 0.000_001)
        let decibels = 20 * log10(weightedAmplitude)
        let normalized = min(max((decibels + 52) / 40, 0), 1)
        return CGFloat(pow(normalized, 0.72))
    }
}

@MainActor
final class KikiWaveformView: NSView {
    static let preferredSize = NSSize(width: 220, height: 34)
    static let barCount = 38

    var level: CGFloat = 0 {
        didSet {
            targetLevel = min(max(level, 0), 1)
            startAnimating()
        }
    }
    private var targetLevel: CGFloat = 0
    private var envelope: CGFloat = 0
    private var phase: CGFloat = 0
    private var history = [CGFloat](repeating: 0.055, count: barCount)
    private var animationTimer: Timer?

    func reset() {
        targetLevel = 0
        envelope = 0
        phase = 0
        history = [CGFloat](repeating: 0.055, count: Self.barCount)
        needsDisplay = true
        startAnimating()
    }

    func stopAnimating() {
        animationTimer?.invalidate()
        animationTimer = nil
    }

    private func startAnimating() {
        guard animationTimer == nil else { return }
        let timer = Timer(timeInterval: 1 / 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.advanceFrame() }
        }
        timer.tolerance = 0.006
        RunLoop.main.add(timer, forMode: .common)
        animationTimer = timer
    }

    private func advanceFrame() {
        let response: CGFloat = targetLevel > envelope ? 0.62 : 0.16
        envelope += (targetLevel - envelope) * response
        targetLevel *= 0.93
        phase += 0.31

        let idlePulse = 0.055 + ((sin(phase * 0.58) + 1) * 0.014)
        let voiceMotion = envelope * (0.78 + 0.22 * sin(phase * 1.41))
        let transient = max(0, sin(phase * 0.73)) * envelope * 0.16
        let sample = min(1, max(idlePulse, voiceMotion + transient))
        history.removeFirst()
        history.append(sample)
        needsDisplay = true
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let barWidth: CGFloat = 3
        let spacing: CGFloat = 2.7
        let totalWidth = CGFloat(Self.barCount) * barWidth + CGFloat(Self.barCount - 1) * spacing
        let startX = (bounds.width - totalWidth) / 2

        effectiveAppearance.performAsCurrentDrawingAppearance {
            let centerLine = NSBezierPath()
            centerLine.move(to: NSPoint(x: startX, y: bounds.midY))
            centerLine.line(to: NSPoint(x: startX + totalWidth, y: bounds.midY))
            centerLine.lineWidth = 1
            KikiPalette.strongStroke.withAlphaComponent(0.22).setStroke()
            centerLine.stroke()

            for (index, sample) in history.enumerated() {
                let progress = CGFloat(index) / CGFloat(max(Self.barCount - 1, 1))
                let spatialMotion = 0.68 + 0.32 * ((sin(CGFloat(index) * 1.19 + phase * 0.72) + 1) / 2)
                let neighboringLift = index > 0 ? history[index - 1] * 0.16 : 0
                let amplitude = min(1, max(0.045, sample * spatialMotion + neighboringLift))
                let height = max(3, 3 + amplitude * (bounds.height - 5))
                let rect = NSRect(
                    x: startX + CGFloat(index) * (barWidth + spacing),
                    y: (bounds.height - height) / 2,
                    width: barWidth,
                    height: height
                )
                let headMix = max(0, (progress - 0.78) / 0.22) * 0.42
                let color = KikiPalette.accentText.blended(withFraction: headMix, of: KikiPalette.khaki)
                    ?? KikiPalette.accentText
                color.withAlphaComponent(0.66 + progress * 0.34).setFill()
                NSBezierPath(roundedRect: rect, xRadius: barWidth / 2, yRadius: barWidth / 2).fill()
            }
        }
    }
}
