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

struct VoiceOrbModel {
    static let frameRate: TimeInterval = 60
    static let sensitivityExponent: CGFloat = 0.56
    static let sensitivityGain: CGFloat = 1.25

    private(set) var innerLevel: CGFloat = 0
    private(set) var outerLevel: CGFloat = 0
    private var targetLevel: CGFloat = 0

    mutating func ingest(samples: [Float]) {
        let capturedLevel = VoiceLevelMeter.normalizedLevel(for: samples)
        targetLevel = capturedLevel > 0
            ? min(1, pow(capturedLevel, Self.sensitivityExponent) * Self.sensitivityGain)
            : 0
    }

    mutating func advanceFrame() {
        let innerResponse: CGFloat = targetLevel > innerLevel ? 0.30 : 0.12
        let outerResponse: CGFloat = targetLevel > outerLevel ? 0.18 : 0.075
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
/// A native Metal interpretation of OrbKit's MIT-licensed Hydrogen direction.
/// Kiki draws its own Templeton-colored material and never embeds the web runtime.
final class KikiVoiceOrbView: NSView {
    static let preferredSize = NSSize(width: 112, height: 112)
    static let usesTempletonMaterialPalette = true
    static let minimumDiameter: CGFloat = 88
    static let maximumDiameter: CGFloat = 102

    private var model = VoiceOrbModel()
    private var animationTimer: Timer?
    private var phase: Float = 0
    private var metalDevice: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    private var pipelineState: MTLRenderPipelineState?
    private var renderTexture: MTLTexture?
    private var imageContext: CIContext?
    private var lastRenderedImage: CGImage?

    private struct OrbUniforms {
        var resolution: SIMD2<Float>
        var time: Float
        var innerLevel: Float
        var outerLevel: Float
        var motionAmount: Float
        var paddingA: Float = 0
        var paddingB: Float = 0
    }

    private static let shaderSource = #"""
    #include <metal_stdlib>
    using namespace metal;

    struct OrbUniforms {
        float2 resolution;
        float time;
        float innerLevel;
        float outerLevel;
        float motionAmount;
        float paddingA;
        float paddingB;
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

    float orbHash(float2 p) {
        return fract(sin(dot(p, float2(127.1, 311.7))) * 43758.5453);
    }

    float orbNoise(float2 p) {
        float2 i = floor(p);
        float2 f = fract(p);
        f = f * f * (3.0 - 2.0 * f);
        return mix(mix(orbHash(i), orbHash(i + float2(1, 0)), f.x),
                   mix(orbHash(i + float2(0, 1)), orbHash(i + float2(1, 1)), f.x), f.y);
    }

    float orbFBM(float2 p) {
        float value = 0.0;
        float amplitude = 0.52;
        for (int octave = 0; octave < 5; octave++) {
            value += amplitude * orbNoise(p);
            p = float2(1.62 * p.x - 1.18 * p.y, 1.18 * p.x + 1.62 * p.y) + 0.17;
            amplitude *= 0.50;
        }
        return value;
    }

    fragment float4 orbFragment(RasterData in [[stage_in]],
                                constant OrbUniforms &u [[buffer(0)]]) {
        float minSide = max(min(u.resolution.x, u.resolution.y), 1.0);
        float2 uv = (in.position.xy * 2.0 - u.resolution) / minSide;
        uv.y *= -1.0;
        float radius = 0.79 + u.outerLevel * 0.12;
        float distanceFromCenter = length(uv);
        float pixel = 2.0 / minSide;
        float sphereMask = 1.0 - smoothstep(radius - pixel * 1.7, radius + pixel * 1.7, distanceFromCenter);
        float outside = max(distanceFromCenter - radius, 0.0);
        float auraEdge = 1.0 - smoothstep(radius + 0.02, 1.0, distanceFromCenter);
        float aura = exp(-outside * outside * 105.0) * auraEdge * (0.18 + u.outerLevel * 0.26);

        if (sphereMask <= 0.001) {
            float3 auraColor = float3(0.322, 0.400, 0.239) * aura;
            return float4(auraColor, aura * 0.72);
        }

        float2 dome = uv / radius;
        float z = sqrt(max(1.0 - dot(dome, dome), 0.0));
        float3 point = float3(dome.x, dome.y, z);
        float time = u.time;

        float yaw = time * (0.44 + u.innerLevel * 0.26);
        float cy = cos(yaw), sy = sin(yaw);
        point = float3(point.x * cy - point.z * sy, point.y, point.x * sy + point.z * cy);
        float tilt = sin(time * 0.31) * (0.32 + u.innerLevel * 0.24);
        float ct = cos(tilt), st = sin(tilt);
        point = float3(point.x, point.y * ct - point.z * st, point.y * st + point.z * ct);

        float flow = 0.52 + u.innerLevel * 0.82;
        float n1 = orbFBM(point.xy * (2.2 + u.innerLevel * 0.9) + float2(time * 0.26, -time * 0.19));
        float n2 = orbFBM(point.yz * 2.5 + float2(-time * 0.21, time * 0.29) + 4.1);
        float n3 = orbFBM(point.zx * 2.1 + float2(time * 0.17, time * 0.24) + 8.7);
        float3 warped = point + (float3(n1, n2, n3) - 0.5) * flow;

        float theta = atan2(warped.y, warped.x);
        float radial = length(warped.xy);
        float travelling = theta * 3.0 + warped.z * 7.0 + radial * 5.0;
        float ribbonA = 0.5 + 0.5 * sin(travelling + n1 * 5.2 - time * 1.42);
        float ribbonB = 0.5 + 0.5 * sin(travelling * 1.37 - n2 * 4.4 + time * 0.93);
        float ribbonC = 0.5 + 0.5 * sin(theta * 5.0 + n3 * 6.1 - time * 0.67);
        float probability = smoothstep(0.30, 0.94, ribbonA * 0.48 + ribbonB * 0.34 + ribbonC * 0.18);
        probability = pow(probability, 0.70 - u.innerLevel * 0.20);

        const float3 charcoal = float3(0.070, 0.076, 0.070);
        const float3 moss = float3(0.322, 0.400, 0.239);
        const float3 sage = float3(0.655, 0.753, 0.502);
        const float3 khaki = float3(0.671, 0.648, 0.502);
        const float3 bone = float3(0.906, 0.871, 0.784);
        const float3 mineral = float3(0.565, 0.606, 0.520);

        float palettePhase = 0.5 + 0.5 * sin(travelling * 0.62 + n2 * 3.0 + time * 0.34);
        float3 flowingColor = mix(moss, sage, palettePhase);
        flowingColor = mix(flowingColor, khaki, smoothstep(0.58, 0.92, ribbonB));
        flowingColor = mix(flowingColor, mineral, smoothstep(0.64, 0.96, ribbonC) * 0.52);
        float3 color = mix(charcoal, moss, 0.30 + n3 * 0.12);
        color = mix(color, flowingColor, 0.28 + probability * (0.58 + u.innerLevel * 0.12));

        float3 normal = normalize(float3(dome, z));
        float diffuse = 0.34 + 0.66 * max(dot(normal, normalize(float3(-0.44, 0.62, 0.74))), 0.0);
        float fresnel = pow(1.0 - z, 2.1);
        float specular = pow(max(dot(normal, normalize(float3(-0.36, 0.48, 0.80))), 0.0), 24.0);
        color *= diffuse;
        color += sage * fresnel * (0.30 + u.outerLevel * 0.28);
        color += bone * specular * (0.72 + u.innerLevel * 0.38);
        color += flowingColor * probability * u.innerLevel * 0.24;

        float alpha = sphereMask * (0.92 + probability * 0.08);
        return float4(color * alpha, alpha);
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

    func reset() {
        animationTimer?.invalidate()
        animationTimer = nil
        model.reset()
        phase = 0
        lastRenderedImage = nil
        layer?.contents = nil
    }

    private func startAnimating() {
        guard animationTimer == nil else { return }
        let timer = Timer(timeInterval: 1 / VoiceOrbModel.frameRate, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.model.advanceFrame()
                if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                    // Keep the surface drift calm and ambient. Voice energy is expressed
                    // primarily through scale, deformation, and light—not rapid rotation.
                    self.phase += Float((0.06 + self.model.innerLevel * 0.12) / CGFloat(VoiceOrbModel.frameRate))
                }
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
            time: phase,
            innerLevel: Float(model.innerLevel),
            outerLevel: Float(model.outerLevel),
            motionAmount: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 1
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
        phase = value
    }
}
