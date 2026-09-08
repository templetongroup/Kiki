import AppKit
import CoreGraphics
import CoreImage
@preconcurrency import MetalKit

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

    func showWaveform(samples: [Float], reset: Bool = false, state: VoiceOrbState? = nil) {
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
        if let state { voiceOrbView.setState(state) }
        else { voiceOrbView.update(samples: samples) }
        if needsPresentation { present(width: 136, height: 136) }
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

enum VoiceOrbState: String, CaseIterable {
    case idle
    case thinking
    case speaking
}

/// Native state driver for OrbKit's idle / thinking / speaking contract.
/// It preserves OrbKit's synthesized baseline motion, critically damped state
/// transitions, and integrated clock so changing states never jumps the phase.
struct VoiceOrbModel {
    static let frameRate: TimeInterval = 60
    static let sensitivityExponent: CGFloat = 0.56
    static let sensitivityGain: CGFloat = 1.25

    private(set) var state: VoiceOrbState = .idle
    private(set) var inputLevel: Float = 0
    private(set) var outputLevel: Float = 0.3
    private(set) var ambient: Float = 0.12
    private(set) var power: Float = 1.9
    private(set) var shadowLift: Float = 0.55
    private(set) var lightColor = SIMD3<Float>(0.906, 0.871, 0.784)
    private(set) var shadowColor = SIMD3<Float>(0.322, 0.400, 0.239)
    private(set) var ambientTime: Float = 0
    private(set) var animationClock: Float = 0

    private var targetInput: Float = 0
    private var elapsed: Float = 0
    private var speed: Float = 0.1
    private var speedVelocity: Float = 0
    private var ambientVelocity: Float = 0
    private var powerVelocity: Float = 0
    private var shadowLiftVelocity: Float = 0
    private var lightVelocity = SIMD3<Float>(repeating: 0)
    private var shadowVelocity = SIMD3<Float>(repeating: 0)

    // Kept for the existing real-microphone calibration diagnostics.
    var innerLevel: CGFloat { CGFloat(inputLevel) }
    var outerLevel: CGFloat { CGFloat(outputLevel) }

    mutating func ingest(samples: [Float]) {
        let captured = VoiceLevelMeter.normalizedLevel(for: samples)
        targetInput = captured > 0
            ? Float(min(1, pow(captured, Self.sensitivityExponent) * Self.sensitivityGain))
            : 0
        if state != .thinking {
            state = targetInput > 0.075 ? .speaking : .idle
        }
    }

    mutating func setState(_ state: VoiceOrbState) {
        self.state = state
        if state == .thinking { targetInput = 0 }
    }

    mutating func advanceFrame(dt: Float = Float(1 / frameRate)) {
        elapsed += dt
        let targets = targetVolumes(at: elapsed)
        let volumeEase = 1 - exp(-dt * 12)
        inputLevel += (targets.input - inputLevel) * volumeEase
        outputLevel += (targets.output - outputLevel) * volumeEase

        let preset = statePreset
        (ambient, ambientVelocity) = Self.springStep(ambient, ambientVelocity, preset.ambient, dt)
        (power, powerVelocity) = Self.springStep(power, powerVelocity, preset.power, dt)
        (shadowLift, shadowLiftVelocity) = Self.springStep(shadowLift, shadowLiftVelocity, preset.shadowLift, dt)
        for index in 0..<3 {
            let lightStep = Self.springStep(
                lightColor[index], lightVelocity[index], preset.light[index], dt
            )
            lightColor[index] = lightStep.0
            lightVelocity[index] = lightStep.1
            let shadowStep = Self.springStep(
                shadowColor[index], shadowVelocity[index], preset.shadow[index], dt
            )
            shadowColor[index] = shadowStep.0
            shadowVelocity[index] = shadowStep.1
        }

        let targetSpeed = 0.1 + (1 - pow(outputLevel - 1, 2)) * 0.9
        (speed, speedVelocity) = Self.springStep(speed, speedVelocity, targetSpeed, dt)
        // SHDR-21 declares speed=10 as an integrated parameter.
        animationClock += dt * speed * 10
        ambientTime += dt * 0.5
    }

    mutating func reset() {
        self = VoiceOrbModel()
    }

    mutating func setDiagnosticClock(_ value: Float) {
        animationClock = value
        ambientTime = value * 0.5
    }

    private func targetVolumes(at time: Float) -> (input: Float, output: Float) {
        switch state {
        case .idle:
            return (targetInput, 0.3)
        case .thinking:
            let base = 0.38 + 0.07 * sin(time * 0.7)
            let wander = 0.05 * sin(time * 2.1) * sin(time * 0.37 + 1.2)
            return (Self.clamp01(base + wander), Self.clamp01(0.48 + 0.12 * sin(time * 1.05 + 0.6)))
        case .speaking:
            let synthesizedInput = Self.clamp01(0.65 + sin(time * 4.8) * 0.22)
            return (max(targetInput, synthesizedInput), Self.clamp01(0.75 + sin(time * 3.6) * 0.22))
        }
    }

    private var statePreset: (
        ambient: Float,
        power: Float,
        shadowLift: Float,
        light: SIMD3<Float>,
        shadow: SIMD3<Float>
    ) {
        // OrbKit's SHDR-21 numeric presets, recolored with Templeton's bone,
        // khaki, sage, mineral, and moss palette.
        switch state {
        case .idle:
            return (0.12, 1.9, 0.55, SIMD3(0.906, 0.871, 0.784), SIMD3(0.322, 0.400, 0.239))
        case .thinking:
            return (0.22, 2.15, 0.65, SIMD3(0.655, 0.753, 0.502), SIMD3(0.337, 0.380, 0.337))
        case .speaking:
            return (0.46, 3.1, 0.95, SIMD3(0.906, 0.871, 0.784), SIMD3(0.420, 0.405, 0.270))
        }
    }

    private static func springStep(
        _ value: Float,
        _ velocity: Float,
        _ target: Float,
        _ dt: Float,
        omega: Float = 4
    ) -> (Float, Float) {
        let f = 1 + 2 * dt * omega
        let omegaSquared = omega * omega
        let hOmegaSquared = dt * omegaSquared
        let hhOmegaSquared = dt * hOmegaSquared
        let inverseDeterminant = 1 / (f + hhOmegaSquared)
        return (
            (f * value + dt * velocity + hhOmegaSquared * target) * inverseDeterminant,
            (velocity + hOmegaSquared * (target - value)) * inverseDeterminant
        )
    }

    private static func clamp01(_ value: Float) -> Float {
        min(1, max(0, value))
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
/// A native Metal port of OrbKit's MIT-licensed SHDR-21 Nimbus renderer.
/// Source: https://orbkit.zzzzshawn.cloud/r/shdr-21.json
final class KikiVoiceOrbView: NSView {
    static let preferredSize = NSSize(width: 112, height: 112)
    static let usesTempletonMaterialPalette = true
    static let minimumDiameter: CGFloat = 88
    static let maximumDiameter: CGFloat = 102

    private var model = VoiceOrbModel()
    private var animationTimer: Timer?
    private var metalDevice: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    private var pipelineState: MTLRenderPipelineState?
    private var renderTexture: MTLTexture?
    private var imageContext: CIContext?
    private var lastRenderedImage: CGImage?

    private struct OrbUniforms {
        var resolution: SIMD2<Float>
        var animationClock: Float
        var inputLevel: Float
        var outputLevel: Float
        var ambient: Float
        var power: Float
        var shadowLift: Float
        var motionAmount: Float
        var lightColor: SIMD4<Float>
        var shadowColor: SIMD4<Float>
    }

    private static let shaderSource = #"""
    #include <metal_stdlib>
    using namespace metal;

    struct OrbUniforms {
        float2 resolution;
        float animationClock;
        float inputLevel;
        float outputLevel;
        float ambient;
        float power;
        float shadowLift;
        float motionAmount;
        float4 lightColor;
        float4 shadowColor;
    };

    struct RasterData { float4 position [[position]]; };

    vertex RasterData orbVertex(uint vertexID [[vertex_id]]) {
        const float2 positions[3] = {
            float2(-1.0, -1.0), float2(3.0, -1.0), float2(-1.0, 3.0)
        };
        RasterData out;
        out.position = float4(positions[vertexID], 0.0, 1.0);
        return out;
    }

    float nimbusDensity(float3 p, float animTime, float reactiveDensity) {
        const float radius = 2.0;
        float shell = 1.0 - length(p) / radius;
        if (shell <= 0.0) return 0.0;
        float3 q = p * 0.8;
        float f = 1.0;
        for (int k = 0; k < 4; k++) {
            q += cos(q.yzx * f + animTime * 0.3) / f;
            f *= 1.8;
        }
        float n = (sin(q.x) + sin(q.y) + sin(q.z)) / 3.0 * 0.5 + 0.5;
        float clump = smoothstep(0.075, 1.0, n);
        return clump * pow(shell, 0.8) * reactiveDensity;
    }

    float phaseHG(float c, float g) {
        float g2 = g * g;
        return (1.0 - g2) / pow(max(1.0 + g2 - 2.0 * g * c, 0.0001), 1.5);
    }

    fragment float4 orbFragment(RasterData in [[stage_in]],
                                constant OrbUniforms &u [[buffer(0)]]) {
        float animTime = u.motionAmount > 0.5 ? u.animationClock : 1.75;
        float2 uv = (2.0 * in.position.xy - u.resolution) / min(u.resolution.x, u.resolution.y);
        float3 ro = float3(0.0, 0.0, -4.4);
        float3 rd = normalize(float3(uv, 1.8));
        float3 light = normalize(float3(cos(animTime * 0.12) * 0.7, 0.45,
                                        sin(animTime * 0.12) * 0.35 + 0.65));
        float phase = phaseHG(dot(rd, light), 0.45);
        float reactiveDensity = 3.2 * (1.0 + 0.35 * u.inputLevel);
        float reactivePower = u.power * (0.7 + 0.9 * u.outputLevel);
        float tStart = 2.4;
        float dt = 4.0 / 56.0;
        float transmittance = 1.0;
        float3 scattered = float3(0.0);
        for (int i = 0; i < 56; i++) {
            float t = tStart + (float(i) + 0.5) * dt;
            float3 p = ro + rd * t;
            float density = nimbusDensity(p, animTime, reactiveDensity);
            if (density > 0.001) {
                float shadow = 1.0;
                float lightStep = 0.5;
                for (int k = 1; k <= 4; k++) {
                    float3 lp = p + light * (float(k) - 0.5) * lightStep;
                    shadow *= exp(-nimbusDensity(lp, animTime, reactiveDensity) * lightStep * 2.4);
                }
                float3 lit = mix(u.shadowColor.rgb * u.shadowLift, u.lightColor.rgb, shadow);
                scattered += transmittance * density * dt * lit * phase * reactivePower;
                transmittance *= exp(-density * dt * 1.4);
                if (transmittance < 0.01) break;
            }
        }
        float body = 1.0 - transmittance;
        scattered += u.shadowColor.rgb * body * u.ambient;
        float3 color = tanh(scattered);
        float alpha = clamp(body * 1.5, 0.0, 1.0);
        return float4(color, alpha);
    }
    """#

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureRenderer(device: MTLCreateSystemDefaultDevice())
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configureRenderer(device: MTLCreateSystemDefaultDevice())
    }

    override var isOpaque: Bool { false }

    func update(samples: [Float]) {
        model.ingest(samples: samples)
        startAnimating()
        if layer?.contents == nil { renderFrame() }
    }

    func setState(_ state: VoiceOrbState) {
        model.setState(state)
        startAnimating()
        renderFrame()
    }

    func reset() {
        animationTimer?.invalidate()
        animationTimer = nil
        model.reset()
        lastRenderedImage = nil
        layer?.contents = nil
    }

    private func startAnimating() {
        guard animationTimer == nil else { return }
        let timer = Timer(timeInterval: 1 / VoiceOrbModel.frameRate, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { self.model.advanceFrame() }
                self.renderFrame()
            }
        }
        timer.tolerance = 0.001
        RunLoop.main.add(timer, forMode: .common)
        animationTimer = timer
    }

    private func configureRenderer(device metalDevice: MTLDevice?) {
        setAccessibilityElement(false)
        wantsLayer = true
        layer?.isOpaque = false
        layer?.contentsGravity = .resizeAspect
        guard let metalDevice else { return }
        self.metalDevice = metalDevice
        commandQueue = metalDevice.makeCommandQueue()
        imageContext = CIContext(mtlDevice: metalDevice)
        do {
            let library = try metalDevice.makeLibrary(source: Self.shaderSource, options: nil)
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.vertexFunction = library.makeFunction(name: "orbVertex")
            descriptor.fragmentFunction = library.makeFunction(name: "orbFragment")
            descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            descriptor.colorAttachments[0].isBlendingEnabled = true
            descriptor.colorAttachments[0].sourceRGBBlendFactor = .one
            descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
            descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            pipelineState = try metalDevice.makeRenderPipelineState(descriptor: descriptor)
        } catch {
            NSLog("Kiki voice orb Metal setup failed: %@", String(describing: error))
        }
    }

    @discardableResult
    private func encode(
        into texture: MTLTexture,
        descriptor: MTLRenderPassDescriptor
    ) -> MTLCommandBuffer? {
        guard let pipelineState, let commandQueue,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else { return nil }
        var uniforms = OrbUniforms(
            resolution: SIMD2(Float(texture.width), Float(texture.height)),
            animationClock: model.animationClock,
            inputLevel: model.inputLevel,
            outputLevel: model.outputLevel,
            ambient: model.ambient,
            power: model.power,
            shadowLift: model.shadowLift,
            motionAmount: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 1,
            lightColor: SIMD4(model.lightColor, 1),
            shadowColor: SIMD4(model.shadowColor, 1)
        )
        encoder.setRenderPipelineState(pipelineState)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<OrbUniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        commandBuffer.commit()
        return commandBuffer
    }

    private func renderedCGImage(scale: CGFloat) -> CGImage? {
        guard let metalDevice, let imageContext, commandQueue != nil, pipelineState != nil else {
            return nil
        }
        let width = max(1, Int(Self.preferredSize.width * scale))
        let height = max(1, Int(Self.preferredSize.height * scale))
        if renderTexture?.width != width || renderTexture?.height != height {
            let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .bgra8Unorm,
                width: width,
                height: height,
                mipmapped: false
            )
            textureDescriptor.usage = [.renderTarget, .shaderRead]
            textureDescriptor.storageMode = .shared
            renderTexture = metalDevice.makeTexture(descriptor: textureDescriptor)
        }
        guard let texture = renderTexture else { return nil }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0)
        guard let commandBuffer = encode(into: texture, descriptor: pass) else { return nil }
        commandBuffer.waitUntilCompleted()
        guard let image = CIImage(mtlTexture: texture, options: [.colorSpace: CGColorSpace(name: CGColorSpace.sRGB)!]) else {
            return nil
        }
        return imageContext.createCGImage(image, from: image.extent)
    }

    private func renderFrame() {
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        guard let image = renderedCGImage(scale: scale) else { return }
        layer?.contentsScale = scale
        lastRenderedImage = image
        layer?.contents = image
    }

    var diagnosticHasVisibleContents: Bool { layer?.contents != nil }

    func renderFrameForDiagnostics() {
        renderFrame()
    }

    func renderedPNGData(scale: CGFloat = 2) -> Data? {
        if layer?.contents == nil { renderFrame() }
        guard let image = lastRenderedImage else { return nil }
        return NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
    }

    func setDiagnosticPhase(_ value: Float) {
        model.setDiagnosticClock(value)
    }
}
