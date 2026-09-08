import AppKit
import CoreGraphics

/// Small floating pill near the bottom of the screen showing recording state.
@MainActor
final class HUDPanel {
    static let voiceOrbUsesClearSurface = true

    private let panel: NSPanel
    private let effect: NSView
    private let logoView: NSImageView
    private let statusLabel: NSTextField
    private let transcriptLabel: NSTextField
    private let modelProgress = NSProgressIndicator()
    private let voiceOrbView = KikiVoiceOrbView()
    private let signalMeterView = KikiSignalMeterView()
    private let textStack = NSStackView()
    private var hasLogo = false
    private var presentation: Presentation?

    private enum Presentation { case message, transcript, waveform, signalMeter }

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
        // Live transcription is cumulative. Keep the newest words visible as
        // the line outgrows the HUD instead of freezing the display on its
        // earliest text.
        transcriptLabel.lineBreakMode = .byTruncatingHead
        transcriptLabel.isHidden = true

        modelProgress.style = .bar
        modelProgress.isIndeterminate = false
        modelProgress.minValue = 0
        modelProgress.maxValue = 1
        modelProgress.controlSize = .small
        modelProgress.isHidden = true
        modelProgress.setAccessibilityLabel("Model download progress")
        modelProgress.widthAnchor.constraint(equalToConstant: 285).isActive = true

        textStack.setViews([statusLabel, transcriptLabel, modelProgress], in: .leading)
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 2

        voiceOrbView.isHidden = true
        signalMeterView.isHidden = true
        let content = NSStackView(views: [logoView, textStack, voiceOrbView, signalMeterView])
        content.orientation = .horizontal
        content.alignment = .centerY
        content.spacing = 10
        content.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(content)
        NSLayoutConstraint.activate([
            logoView.widthAnchor.constraint(equalToConstant: 34),
            logoView.heightAnchor.constraint(equalToConstant: 34),
            transcriptLabel.widthAnchor.constraint(equalToConstant: 300),
            voiceOrbView.widthAnchor.constraint(equalToConstant: KikiVoiceOrbView.preferredSize.width),
            voiceOrbView.heightAnchor.constraint(equalToConstant: KikiVoiceOrbView.preferredSize.height),
            signalMeterView.widthAnchor.constraint(equalToConstant: KikiSignalMeterView.preferredSize.width),
            signalMeterView.heightAnchor.constraint(equalToConstant: KikiSignalMeterView.preferredSize.height),
            content.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 12),
            content.trailingAnchor.constraint(lessThanOrEqualTo: effect.trailingAnchor, constant: -12),
            content.centerYAnchor.constraint(equalTo: effect.centerYAnchor),
        ])

        panel.contentView = effect
    }

    func show(_ text: String) {
        presentation = .message
        applyAppearance()
        logoView.isHidden = !hasLogo
        textStack.isHidden = false
        voiceOrbView.isHidden = true
        voiceOrbView.reset()
        signalMeterView.isHidden = true
        signalMeterView.reset()
        statusLabel.stringValue = text
        statusLabel.textColor = .labelColor
        transcriptLabel.isHidden = true
        modelProgress.isHidden = true
        let logoWidth: CGFloat = logoView.isHidden ? 0 : 37
        let width = max(180, statusLabel.intrinsicContentSize.width + logoWidth + 54)
        present(width: width, height: 54)
    }

    func showModelPreparation(_ status: ModelPreparationStatus) {
        presentation = .message
        applyAppearance()
        logoView.isHidden = !hasLogo
        textStack.isHidden = false
        voiceOrbView.isHidden = true
        voiceOrbView.reset()
        signalMeterView.isHidden = true
        signalMeterView.reset()
        statusLabel.stringValue = status.compactTitle
        statusLabel.textColor = KikiPalette.primaryText
        transcriptLabel.isHidden = true
        if let fraction = status.downloadFraction {
            modelProgress.doubleValue = fraction
            modelProgress.isHidden = false
            modelProgress.setAccessibilityValue("\(Int((fraction * 100).rounded(.down))) percent")
            present(width: 410, height: 70)
        } else {
            modelProgress.isHidden = true
            present(width: 410, height: 56)
        }
    }

    var diagnosticModelStatusText: String { statusLabel.stringValue }
    var diagnosticTranscriptText: String { transcriptLabel.stringValue }
    var diagnosticTranscriptLineBreakMode: NSLineBreakMode { transcriptLabel.lineBreakMode }
    var diagnosticModelProgressValue: Double? {
        modelProgress.isHidden ? nil : modelProgress.doubleValue
    }

    func showListening(transcript: String? = nil) {
        let needsPresentation = presentation != .transcript || !panel.isVisible
        presentation = .transcript
        applyAppearance()
        logoView.isHidden = !hasLogo
        textStack.isHidden = false
        voiceOrbView.isHidden = true
        voiceOrbView.reset()
        signalMeterView.isHidden = true
        signalMeterView.reset()
        statusLabel.stringValue = "Listening"
        statusLabel.textColor = KikiPalette.accentText
        transcriptLabel.stringValue = displayText(transcript)
        transcriptLabel.textColor = transcript == nil ? .secondaryLabelColor : .labelColor
        transcriptLabel.isHidden = false
        modelProgress.isHidden = true
        if needsPresentation { showExpanded() }
    }

    func showWaveform(samples: [Float], reset: Bool = false) {
        let needsPresentation = presentation != .waveform || !panel.isVisible
        presentation = .waveform
        applyAppearance()
        logoView.isHidden = true
        textStack.isHidden = true
        modelProgress.isHidden = true
        voiceOrbView.isHidden = false
        signalMeterView.isHidden = true
        signalMeterView.reset()
        if reset { voiceOrbView.reset() }
        voiceOrbView.update(samples: samples)
        if needsPresentation { present(width: 88, height: 88) }
    }

    func showSignalMeter(samples: [Float], reset: Bool = false) {
        let needsPresentation = presentation != .signalMeter || !panel.isVisible
        presentation = .signalMeter
        applyAppearance()
        logoView.isHidden = true
        textStack.isHidden = true
        modelProgress.isHidden = true
        voiceOrbView.isHidden = true
        voiceOrbView.reset()
        signalMeterView.isHidden = false
        if reset { signalMeterView.reset() }
        signalMeterView.update(samples: samples)
        if needsPresentation { present(width: 118, height: 64) }
    }

    func showTranscribing(transcript: String? = nil) {
        presentation = .transcript
        applyAppearance()
        logoView.isHidden = !hasLogo
        textStack.isHidden = false
        voiceOrbView.isHidden = true
        voiceOrbView.reset()
        signalMeterView.isHidden = true
        signalMeterView.reset()
        statusLabel.stringValue = "Transcribing…"
        statusLabel.textColor = .secondaryLabelColor
        transcriptLabel.stringValue = displayText(transcript)
        transcriptLabel.textColor = transcript == nil ? .secondaryLabelColor : .labelColor
        transcriptLabel.isHidden = false
        modelProgress.isHidden = true
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
        guard let transcript, !transcript.isEmpty else {
            return "Speak now · \(Settings.dictationShortcut.displayString) to stop and insert"
        }
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
            let usesClearSurface = presentation == .waveform && Self.voiceOrbUsesClearSurface
            panel.hasShadow = !usesClearSurface
            effect.layer?.backgroundColor = usesClearSurface
                ? NSColor.clear.cgColor
                : KikiPalette.elevatedSurface.withAlphaComponent(0.98).cgColor
            effect.layer?.borderWidth = usesClearSurface ? 0 : 1
            effect.layer?.borderColor = usesClearSurface
                ? NSColor.clear.cgColor
                : KikiPalette.strongStroke.cgColor
            effect.layer?.shadowColor = NSColor.black.cgColor
            effect.layer?.shadowOpacity = usesClearSurface ? 0 : 0.18
            effect.layer?.shadowRadius = 16
        }
    }

    func hide() {
        presentation = nil
        voiceOrbView.reset()
        signalMeterView.reset()
        panel.orderOut(nil)
    }

    var isVisibleOnScreen: Bool {
        panel.isVisible && NSScreen.screens.contains { $0.visibleFrame.intersects(panel.frame) }
    }
}

enum VoiceLevelMeter {
    static func normalizedLevel(for samples: [Float]) -> CGFloat {
        normalizedLevel(for: samples[...])
    }

    private static func normalizedLevel(for samples: ArraySlice<Float>) -> CGFloat {
        guard !samples.isEmpty else { return 0 }
        let meanSquare = samples.reduce(0.0) { $0 + Double($1 * $1) } / Double(samples.count)
        let rms = meanSquare.squareRoot()
        guard rms > 0.003 else { return 0 }

        // Map the whole capture chunk by RMS. The saved normal-voice fixture
        // calibrates this curve so conversational speech retains ample headroom.
        let decibels = 20 * log10(max(rms, 0.000_001))
        let normalized = min(max((decibels + 45) / 44, 0), 1)
        return CGFloat(pow(normalized, 1.9))
    }
}

struct VoiceOrbModel {
    static let frameRate: TimeInterval = 30

    private(set) var innerLevel: CGFloat = 0
    private(set) var outerLevel: CGFloat = 0
    private var targetLevel: CGFloat = 0

    mutating func ingest(samples: [Float]) {
        targetLevel = VoiceLevelMeter.normalizedLevel(for: samples)
    }

    mutating func advanceFrame() {
        let innerResponse: CGFloat = targetLevel > innerLevel ? 0.45 : 0.22
        let outerResponse: CGFloat = targetLevel > outerLevel ? 0.28 : 0.14
        innerLevel += (targetLevel - innerLevel) * innerResponse
        outerLevel += (targetLevel - outerLevel) * outerResponse
    }

    mutating func reset() {
        targetLevel = 0
        innerLevel = 0
        outerLevel = 0
    }
}

struct SignalMeterModel {
    static let frameRate: TimeInterval = 30
    static let barCount = 7
    static let barProfile: [CGFloat] = [0.56, 0.74, 0.90, 1.00, 0.86, 0.68, 0.52]
    static let sensitivityExponent: CGFloat = 0.58
    static let sensitivityGain: CGFloat = 1.18
    static let attackResponse: CGFloat = 0.68
    static let releaseResponse: CGFloat = 0.24

    private(set) var levels = [CGFloat](repeating: 0, count: barCount)
    private var targetLevels = [CGFloat](repeating: 0, count: barCount)

    var level: CGFloat { levels.max() ?? 0 }

    mutating func ingest(samples: [Float]) {
        guard !samples.isEmpty else {
            targetLevels = [CGFloat](repeating: 0, count: Self.barCount)
            return
        }
        let overall = Self.displayLevel(for: VoiceLevelMeter.normalizedLevel(for: samples))
        targetLevels.removeFirst()
        targetLevels.append(overall)
    }

    mutating func advanceFrame() {
        for index in levels.indices {
            let response = targetLevels[index] > levels[index]
                ? Self.attackResponse
                : Self.releaseResponse
            levels[index] += (targetLevels[index] - levels[index]) * response
        }
    }

    static func displayLevel(for normalizedInput: CGFloat) -> CGFloat {
        guard normalizedInput > 0 else { return 0 }
        return min(1, pow(normalizedInput, sensitivityExponent) * sensitivityGain)
    }

    mutating func reset() {
        levels = [CGFloat](repeating: 0, count: Self.barCount)
        targetLevels = [CGFloat](repeating: 0, count: Self.barCount)
    }
}

/// A literal, bottom-anchored microphone meter. Its seven bars respond to the
/// captured signal rather than running a decorative loop.
@MainActor
final class KikiSignalMeterView: NSView {
    static let preferredSize = NSSize(width: 94, height: 40)
    static let barCount = SignalMeterModel.barCount
    static let usesBottomBaseline = true

    private var model = SignalMeterModel()
    private var animationTimer: Timer?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        setAccessibilityElement(false)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        setAccessibilityElement(false)
    }

    deinit { animationTimer?.invalidate() }

    func update(samples: [Float]) {
        model.ingest(samples: samples)
        startAnimating()
    }

    func reset() {
        animationTimer?.invalidate()
        animationTimer = nil
        model.reset()
        needsDisplay = true
    }

    private func startAnimating() {
        guard animationTimer == nil else { return }
        let timer = Timer(timeInterval: 1 / SignalMeterModel.frameRate, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.model.advanceFrame()
                self.needsDisplay = true
            }
        }
        timer.tolerance = 0.003
        RunLoop.main.add(timer, forMode: .common)
        animationTimer = timer
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let baselineY = bounds.maxY - 3
        let barWidth: CGFloat = 8
        let gap: CGFloat = 5
        let totalWidth = CGFloat(Self.barCount) * barWidth + CGFloat(Self.barCount - 1) * gap
        let originX = bounds.midX - totalWidth / 2
        let availableHeight = bounds.height - 8
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        effectiveAppearance.performAsCurrentDrawingAppearance {
            let baseline = NSBezierPath()
            baseline.move(to: CGPoint(x: originX - 4, y: baselineY + 0.5))
            baseline.line(to: CGPoint(x: originX + totalWidth + 4, y: baselineY + 0.5))
            baseline.lineWidth = 1
            KikiPalette.strongStroke.withAlphaComponent(0.72).setStroke()
            baseline.stroke()

            for (index, profile) in SignalMeterModel.barProfile.enumerated() {
                let level = model.levels[index]
                let height: CGFloat
                let alpha: CGFloat
                if reduceMotion {
                    height = availableHeight * profile
                    let threshold = CGFloat(index + 1) / CGFloat(Self.barCount + 1)
                    alpha = level >= threshold ? 0.98 : 0.18
                } else {
                    height = max(4, availableHeight * (0.08 + level * 0.92) * profile)
                    alpha = 0.52 + level * 0.48
                }
                let rect = NSRect(
                    x: originX + CGFloat(index) * (barWidth + gap),
                    y: baselineY - height,
                    width: barWidth,
                    height: height
                )
                let bar = NSBezierPath(
                    roundedRect: rect,
                    xRadius: min(3.5, height / 2),
                    yRadius: min(3.5, height / 2)
                )
                NSGraphicsContext.saveGraphicsState()
                bar.addClip()
                NSGradient(colors: [
                    KikiPalette.accentText.withAlphaComponent(alpha),
                    KikiPalette.accent.withAlphaComponent(alpha * 0.90),
                ])?.draw(in: rect, angle: 90)
                NSGraphicsContext.restoreGraphicsState()
            }
        }
    }
}

@MainActor
/// A native AppKit interpretation of OrbKit's MIT-licensed Hydrogen direction.
/// Kiki draws its own Templeton-colored material and never embeds the web runtime.
final class KikiVoiceOrbView: NSView {
    static let preferredSize = NSSize(width: 64, height: 64)
    static let usesTempletonMaterialPalette = true
    static let minimumDiameter: CGFloat = 45
    static let maximumDiameter: CGFloat = 51

    private var model = VoiceOrbModel()
    private var animationTimer: Timer?
    private var phase: CGFloat = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setAccessibilityElement(false)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setAccessibilityElement(false)
        wantsLayer = true
    }

    func update(samples: [Float]) {
        model.ingest(samples: samples)
        startAnimating()
    }

    func reset() {
        animationTimer?.invalidate()
        animationTimer = nil
        model.reset()
        phase = 0
        needsDisplay = true
    }

    private func startAnimating() {
        guard animationTimer == nil else { return }
        let timer = Timer(timeInterval: 1 / VoiceOrbModel.frameRate, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.model.advanceFrame()
                if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                    self.phase += 0.035 + self.model.innerLevel * 0.045
                }
                self.needsDisplay = true
            }
        }
        timer.tolerance = 0.003
        RunLoop.main.add(timer, forMode: .common)
        animationTimer = timer
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let innerLevel = model.innerLevel
        let outerLevel = model.outerLevel
        let diameter = Self.minimumDiameter
            + (reduceMotion ? 0 : outerLevel * (Self.maximumDiameter - Self.minimumDiameter))
        let radius = diameter / 2

        effectiveAppearance.performAsCurrentDrawingAppearance {
            drawAura(centeredAt: center, radius: radius, level: outerLevel)
            drawOrb(centeredAt: center, radius: radius, level: innerLevel)
        }
    }

    private func drawAura(centeredAt center: CGPoint, radius: CGFloat, level: CGFloat) {
        let auraRadius = radius * (1.16 + level * 0.08)
        let auraRect = NSRect(
            x: center.x - auraRadius,
            y: center.y - auraRadius,
            width: auraRadius * 2,
            height: auraRadius * 2
        )
        NSGradient(colorsAndLocations:
            (KikiPalette.accent.withAlphaComponent(0.15 + level * 0.17), 0),
            (KikiPalette.khaki.withAlphaComponent(0.06 + level * 0.08), 0.54),
            (NSColor.clear, 1)
        )?.draw(in: NSBezierPath(ovalIn: auraRect), relativeCenterPosition: .zero)
    }

    private func drawOrb(centeredAt center: CGPoint, radius: CGFloat, level: CGFloat) {
        let orbRect = NSRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        let orb = NSBezierPath(ovalIn: orbRect)

        NSGraphicsContext.saveGraphicsState()
        orb.addClip()

        NSGradient(colorsAndLocations:
            (KikiPalette.onAccentText.withAlphaComponent(0.90), 0),
            (KikiPalette.khaki.withAlphaComponent(0.88), 0.17),
            (KikiPalette.accent.withAlphaComponent(0.96), 0.43),
            (KikiPalette.hardwareControl.withAlphaComponent(0.99), 0.76),
            (KikiPalette.hardwareControl.withAlphaComponent(1), 1)
        )?.draw(in: orb, relativeCenterPosition: NSPoint(x: -0.52, y: 0.24))

        drawReflectionBands(in: orbRect, level: level)

        let shade = NSGradient(colorsAndLocations:
            (NSColor.clear, 0),
            (KikiPalette.canvas.withAlphaComponent(0.08), 0.62),
            (NSColor.black.withAlphaComponent(0.62), 1)
        )
        shade?.draw(in: orb, relativeCenterPosition: NSPoint(x: -0.48, y: 0.46))
        NSGraphicsContext.restoreGraphicsState()

        drawOrbEdge(orbRect)

        let highlightRadius = radius * 0.34
        let highlightRect = NSRect(
            x: orbRect.minX + radius * 0.30,
            y: orbRect.minY + radius * 0.22,
            width: highlightRadius * 2,
            height: highlightRadius * 2
        )
        NSGradient(colorsAndLocations:
            (KikiPalette.onAccentText.withAlphaComponent(0.48 + level * 0.18), 0),
            (KikiPalette.onAccentText.withAlphaComponent(0.10), 0.38),
            (NSColor.clear, 1)
        )?.draw(in: NSBezierPath(ovalIn: highlightRect), relativeCenterPosition: .zero)
    }

    private func drawOrbEdge(_ orbRect: NSRect) {
        KikiPalette.canvas.withAlphaComponent(0.96).setStroke()
        let separation = NSBezierPath(ovalIn: orbRect.insetBy(dx: -0.15, dy: -0.15))
        separation.lineWidth = 1.20
        separation.stroke()

        let rim = NSBezierPath(ovalIn: orbRect.insetBy(dx: 0.6, dy: 0.6))
        rim.lineWidth = 0.60
        KikiPalette.accentText.withAlphaComponent(0.42).setStroke()
        rim.stroke()
    }

    private func drawReflectionBands(in rect: NSRect, level: CGFloat) {
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        let colors = [KikiPalette.accentText, KikiPalette.khaki, KikiPalette.magenta]
        for index in colors.indices {
            let offset = CGFloat(index - 1) * rect.width * 0.24
            let drift = sin(phase * (0.72 + CGFloat(index) * 0.11) + CGFloat(index)) * rect.width * 0.08
            let path = NSBezierPath()
            path.move(to: CGPoint(x: rect.midX + offset + drift, y: rect.minY - 4))
            path.curve(
                to: CGPoint(x: rect.midX - offset * 0.35 - drift, y: rect.maxY + 4),
                controlPoint1: CGPoint(
                    x: rect.midX + offset * 0.45 + drift + rect.width * 0.18,
                    y: rect.minY + rect.height * 0.32
                ),
                controlPoint2: CGPoint(
                    x: rect.midX - offset * 0.20 - drift - rect.width * 0.16,
                    y: rect.minY + rect.height * 0.70
                )
            )
            let shadow = NSShadow()
            shadow.shadowBlurRadius = 4.5 + level * 2.5
            shadow.shadowColor = colors[index].withAlphaComponent(0.26 + level * 0.22)
            shadow.shadowOffset = .zero
            shadow.set()
            path.lineWidth = rect.width * (index == 1 ? 0.17 : 0.11)
            colors[index].withAlphaComponent(0.10 + level * 0.10).setStroke()
            path.stroke()
        }
    }
}
