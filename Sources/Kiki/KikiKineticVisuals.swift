import AppKit

enum KikiVoiceVisualState {
    case unavailable
    case loading
    case ready
    case listening
    case transcribing
}

/// A restrained, native voice-state object for Kiki's Studio Hardware surfaces.
/// The dotted field is supplemental: every state remains available as text.
@MainActor
final class KikiVoiceStateVisual: NSView {
    private var visualState: KikiVoiceVisualState = .ready
    private var animationTimer: Timer?
    private var phase: CGFloat = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setAccessibilityElement(false)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit { animationTimer?.invalidate() }

    func setState(_ state: KikiVoiceVisualState) {
        visualState = state
        updateAnimation()
        needsDisplay = true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateAnimation()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard bounds.width > 0, bounds.height > 0 else { return }

        let center = CGPoint(x: bounds.midX, y: bounds.midY + 6)
        let radius = min(bounds.width, bounds.height) * 0.38
        let accent = stateColor

        drawHalo(center: center, radius: radius, color: accent)
        drawInstrumentRings(center: center, radius: radius, color: accent)
        drawDotField(center: center, radius: radius * 0.84, color: accent)
        drawCore(center: center, radius: radius * 0.43, color: accent)
        drawStatusPill(center: CGPoint(x: center.x, y: center.y - radius - 14), color: accent)
    }

    private var stateColor: NSColor {
        switch visualState {
        case .unavailable: KikiPalette.tertiaryText
        case .loading: KikiPalette.khaki
        case .ready: KikiPalette.accentText
        case .listening: KikiPalette.accentText
        case .transcribing: KikiPalette.khaki
        }
    }

    private var statusText: String {
        switch visualState {
        case .unavailable: "MODEL NEEDED"
        case .loading: "LOADING"
        case .ready: "READY"
        case .listening: "LISTENING"
        case .transcribing: "REFINING"
        }
    }

    private var isActive: Bool {
        visualState == .loading || visualState == .listening || visualState == .transcribing
    }

    private func updateAnimation() {
        let shouldAnimate = window != nil
            && isActive
            && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if shouldAnimate, animationTimer == nil {
            animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 24.0, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.phase += self.visualState == .listening ? 0.045 : 0.026
                    self.needsDisplay = true
                }
            }
        } else if !shouldAnimate {
            animationTimer?.invalidate()
            animationTimer = nil
            phase = 0
        }
    }

    private func drawHalo(center: CGPoint, radius: CGFloat, color: NSColor) {
        let haloRect = CGRect(
            x: center.x - radius * 1.20,
            y: center.y - radius * 1.20,
            width: radius * 2.40,
            height: radius * 2.40
        )
        let gradient = NSGradient(colorsAndLocations:
            (color.withAlphaComponent(isActive ? 0.18 : 0.11), 0),
            (color.withAlphaComponent(0.04), 0.55),
            (NSColor.clear, 1)
        )
        gradient?.draw(in: NSBezierPath(ovalIn: haloRect), relativeCenterPosition: .zero)
    }

    private func drawInstrumentRings(center: CGPoint, radius: CGFloat, color: NSColor) {
        for (index, scale) in [1.0, 0.78, 0.58].enumerated() {
            let ringRadius = radius * scale
            let rect = CGRect(
                x: center.x - ringRadius,
                y: center.y - ringRadius,
                width: ringRadius * 2,
                height: ringRadius * 2
            )
            let ring = NSBezierPath(ovalIn: rect)
            ring.lineWidth = index == 0 ? 1.2 : 0.8
            color.withAlphaComponent(index == 0 ? 0.34 : 0.16).setStroke()
            ring.stroke()
        }

        let tickCount = 28
        for index in 0..<tickCount {
            let angle = (CGFloat(index) / CGFloat(tickCount)) * .pi * 2 + phase * 0.35
            let emphasis = index % 7 == 0
            let outer = radius * 1.03
            let inner = radius * (emphasis ? 0.94 : 0.975)
            let path = NSBezierPath()
            path.move(to: CGPoint(x: center.x + cos(angle) * inner, y: center.y + sin(angle) * inner))
            path.line(to: CGPoint(x: center.x + cos(angle) * outer, y: center.y + sin(angle) * outer))
            path.lineWidth = emphasis ? 1.6 : 0.8
            color.withAlphaComponent(emphasis ? 0.52 : 0.22).setStroke()
            path.stroke()
        }
    }

    private func drawDotField(center: CGPoint, radius: CGFloat, color: NSColor) {
        let dotCount = 84
        let goldenAngle = CGFloat.pi * (3 - sqrt(5))
        for index in 0..<dotCount {
            let progress = (CGFloat(index) + 0.5) / CGFloat(dotCount)
            let radial = sqrt(progress) * radius
            let angle = CGFloat(index) * goldenAngle + phase
            let x = cos(angle) * radial
            let y = sin(angle) * radial * 0.88
            let wave = sin(angle * 2.2 + phase * 3)
            let activeBoost: CGFloat = isActive ? max(0, wave) * 0.34 : 0
            let alpha = 0.18 + (1 - progress) * 0.46 + activeBoost
            let size = 1.2 + (1 - progress) * 1.7 + activeBoost * 1.4
            let dot = CGRect(
                x: center.x + x - size / 2,
                y: center.y + y - size / 2,
                width: size,
                height: size
            )
            (index % 11 == 0 ? KikiPalette.khaki : color).withAlphaComponent(alpha).setFill()
            NSBezierPath(ovalIn: dot).fill()
        }
    }

    private func drawCore(center: CGPoint, radius: CGFloat, color: NSColor) {
        let coreRect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        KikiPalette.hardwareControl.withAlphaComponent(0.94).setFill()
        NSBezierPath(ovalIn: coreRect).fill()
        let coreStroke = NSBezierPath(ovalIn: coreRect.insetBy(dx: 0.5, dy: 0.5))
        coreStroke.lineWidth = 1
        color.withAlphaComponent(0.48).setStroke()
        coreStroke.stroke()

        let levels = barLevels
        let barWidth = max(2.2, radius * 0.085)
        let gap = barWidth * 0.72
        let totalWidth = CGFloat(levels.count) * barWidth + CGFloat(levels.count - 1) * gap
        for (index, level) in levels.enumerated() {
            let height = max(5, radius * level)
            let rect = CGRect(
                x: center.x - totalWidth / 2 + CGFloat(index) * (barWidth + gap),
                y: center.y - height / 2,
                width: barWidth,
                height: height
            )
            color.withAlphaComponent(index == levels.count / 2 ? 1 : 0.72).setFill()
            NSBezierPath(roundedRect: rect, xRadius: barWidth / 2, yRadius: barWidth / 2).fill()
        }
    }

    private var barLevels: [CGFloat] {
        switch visualState {
        case .unavailable: return [0.18, 0.18, 0.18, 0.18, 0.18]
        case .loading: return [0.24, 0.42, 0.58, 0.42, 0.24]
        case .ready: return [0.25, 0.48, 0.72, 0.48, 0.25]
        case .listening:
            return (0..<5).map { index in
                0.28 + abs(sin(phase * 3.1 + CGFloat(index) * 0.9)) * 0.56
            }
        case .transcribing:
            return (0..<5).map { index in
                0.24 + abs(cos(phase * 2.4 + CGFloat(index) * 0.72)) * 0.40
            }
        }
    }

    private func drawStatusPill(center: CGPoint, color: NSColor) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 9.5, weight: .semibold),
            .foregroundColor: color,
            .kern: 0.8,
        ]
        let size = statusText.size(withAttributes: attributes)
        let pillRect = CGRect(
            x: center.x - size.width / 2 - 15,
            y: center.y - 10,
            width: size.width + 30,
            height: 21
        )
        KikiPalette.hardwareControl.withAlphaComponent(0.86).setFill()
        NSBezierPath(roundedRect: pillRect, xRadius: 10.5, yRadius: 10.5).fill()
        let stroke = NSBezierPath(roundedRect: pillRect.insetBy(dx: 0.5, dy: 0.5), xRadius: 10, yRadius: 10)
        stroke.lineWidth = 1
        color.withAlphaComponent(0.30).setStroke()
        stroke.stroke()
        statusText.draw(
            at: CGPoint(x: pillRect.midX - size.width / 2, y: pillRect.midY - size.height / 2),
            withAttributes: attributes
        )
    }
}

enum KikiCapabilityVisualKind {
    case dictation
    case meeting
    case audioFile
    case voiceStudio
}

@MainActor
final class KikiCapabilityGlyphView: NSView {
    private let kind: KikiCapabilityVisualKind

    init(kind: KikiCapabilityVisualKind) {
        self.kind = kind
        super.init(frame: .zero)
        wantsLayer = true
        setAccessibilityElement(false)
        widthAnchor.constraint(equalToConstant: 30).isActive = true
        heightAnchor.constraint(equalToConstant: 30).isActive = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let plate = bounds.insetBy(dx: 0.5, dy: 0.5)
        KikiPalette.hardwareControl.withAlphaComponent(0.84).setFill()
        NSBezierPath(roundedRect: plate, xRadius: 8, yRadius: 8).fill()
        let border = NSBezierPath(roundedRect: plate, xRadius: 8, yRadius: 8)
        border.lineWidth = 1
        KikiPalette.strongStroke.withAlphaComponent(0.8).setStroke()
        border.stroke()

        switch kind {
        case .dictation: drawWaveform()
        case .meeting: drawMeeting()
        case .audioFile: drawFiles()
        case .voiceStudio: drawVoice()
        }
    }

    private func drawWaveform() {
        let heights: [CGFloat] = [6, 12, 18, 12, 7]
        for (index, height) in heights.enumerated() {
            let rect = CGRect(x: 8 + CGFloat(index) * 3.5, y: bounds.midY - height / 2, width: 2, height: height)
            (index == 2 ? KikiPalette.khaki : KikiPalette.accentText).setFill()
            NSBezierPath(roundedRect: rect, xRadius: 1, yRadius: 1).fill()
        }
    }

    private func drawMeeting() {
        let points = [CGPoint(x: 10, y: 17), CGPoint(x: 20, y: 17), CGPoint(x: 15, y: 10)]
        let connector = NSBezierPath()
        connector.move(to: points[0]); connector.line(to: points[1]); connector.line(to: points[2]); connector.close()
        connector.lineWidth = 1
        KikiPalette.accentText.withAlphaComponent(0.45).setStroke()
        connector.stroke()
        for (index, point) in points.enumerated() {
            let rect = CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)
            (index == 2 ? KikiPalette.khaki : KikiPalette.accentText).setFill()
            NSBezierPath(ovalIn: rect).fill()
        }
    }

    private func drawFiles() {
        for (index, offset) in [CGPoint(x: 0, y: 4), CGPoint(x: 2, y: 2), CGPoint(x: 4, y: 0)].enumerated() {
            let rect = CGRect(x: 7 + offset.x, y: 7 + offset.y, width: 13, height: 16)
            (index == 2 ? KikiPalette.elevatedSurface : KikiPalette.hardwareControl).setFill()
            NSBezierPath(roundedRect: rect, xRadius: 2.5, yRadius: 2.5).fill()
            (index == 2 ? KikiPalette.accentText : KikiPalette.strongStroke).withAlphaComponent(0.8).setStroke()
            let outline = NSBezierPath(roundedRect: rect, xRadius: 2.5, yRadius: 2.5)
            outline.lineWidth = 0.8
            outline.stroke()
        }
        let line = NSBezierPath()
        line.move(to: CGPoint(x: 13, y: 13)); line.line(to: CGPoint(x: 20, y: 13))
        line.lineWidth = 1.2
        KikiPalette.khaki.setStroke()
        line.stroke()
    }

    private func drawVoice() {
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let ring = NSBezierPath(ovalIn: CGRect(x: center.x - 8, y: center.y - 8, width: 16, height: 16))
        ring.lineWidth = 1
        KikiPalette.accentText.withAlphaComponent(0.55).setStroke()
        ring.stroke()
        for index in 0..<12 {
            let angle = CGFloat(index) / 12 * .pi * 2
            let point = CGPoint(x: center.x + cos(angle) * 8, y: center.y + sin(angle) * 8)
            let size: CGFloat = index % 3 == 0 ? 2.3 : 1.5
            (index % 4 == 0 ? KikiPalette.khaki : KikiPalette.accentText).setFill()
            NSBezierPath(ovalIn: CGRect(x: point.x - size / 2, y: point.y - size / 2, width: size, height: size)).fill()
        }
        for (index, height) in [6, 11, 6].enumerated() {
            let rect = CGRect(x: 12 + CGFloat(index) * 3, y: center.y - CGFloat(height) / 2, width: 1.7, height: CGFloat(height))
            KikiPalette.accentText.setFill()
            NSBezierPath(roundedRect: rect, xRadius: 0.85, yRadius: 0.85).fill()
        }
    }
}

@MainActor
final class KikiAudioFileStackVisual: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setAccessibilityElement(false)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        drawCard(center: CGPoint(x: center.x - 8, y: center.y), angle: 8, alpha: 0.45, front: false)
        drawCard(center: CGPoint(x: center.x + 8, y: center.y), angle: -8, alpha: 0.62, front: false)
        drawCard(center: center, angle: 0, alpha: 1, front: true)
    }

    private func drawCard(center: CGPoint, angle: CGFloat, alpha: CGFloat, front: Bool) {
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: center.x, yBy: center.y)
        transform.rotate(byDegrees: angle)
        transform.translateX(by: -center.x, yBy: -center.y)
        transform.concat()

        let rect = CGRect(x: center.x - 31, y: center.y - 20, width: 62, height: 40)
        (front ? KikiPalette.elevatedSurface : KikiPalette.hardwareControl).withAlphaComponent(alpha).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 7, yRadius: 7).fill()
        let outline = NSBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), xRadius: 6.5, yRadius: 6.5)
        outline.lineWidth = front ? 1.1 : 0.8
        KikiPalette.accentText.withAlphaComponent(alpha * (front ? 0.58 : 0.28)).setStroke()
        outline.stroke()

        if front {
            let levels: [CGFloat] = [5, 10, 15, 9, 13, 7, 4]
            for (index, height) in levels.enumerated() {
                let bar = CGRect(x: rect.minX + 10 + CGFloat(index) * 4.2, y: rect.midY - height / 2, width: 2.1, height: height)
                (index == 3 ? KikiPalette.khaki : KikiPalette.accentText).setFill()
                NSBezierPath(roundedRect: bar, xRadius: 1, yRadius: 1).fill()
            }
            KikiPalette.secondaryText.withAlphaComponent(0.55).setFill()
            NSBezierPath(roundedRect: CGRect(x: rect.maxX - 14, y: rect.minY + 8, width: 5, height: 2), xRadius: 1, yRadius: 1).fill()
        }
        NSGraphicsContext.restoreGraphicsState()
    }
}

@MainActor
final class KikiActivityIndicatorView: NSView {
    private var timer: Timer?
    private var phase: CGFloat = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        isHidden = true
        setAccessibilityElement(false)
        widthAnchor.constraint(equalToConstant: 22).isActive = true
        heightAnchor.constraint(equalToConstant: 22).isActive = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit { timer?.invalidate() }

    func startAnimating() {
        isHidden = false
        guard timer == nil, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            needsDisplay = true
            return
        }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 20.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.phase += 0.09
                self?.needsDisplay = true
            }
        }
    }

    func stopAnimating() {
        timer?.invalidate()
        timer = nil
        isHidden = true
        phase = 0
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        for index in 0..<14 {
            let progress = CGFloat(index) / 14
            let angle = progress * .pi * 2 + phase
            let wave = (sin(angle - phase * 2) + 1) / 2
            let size = 1.4 + wave * 1.7
            let point = CGPoint(x: center.x + cos(angle) * 7.2, y: center.y + sin(angle) * 7.2)
            (index % 5 == 0 ? KikiPalette.khaki : KikiPalette.accentText)
                .withAlphaComponent(0.24 + wave * 0.68)
                .setFill()
            NSBezierPath(ovalIn: CGRect(x: point.x - size / 2, y: point.y - size / 2, width: size, height: size)).fill()
        }
    }
}
