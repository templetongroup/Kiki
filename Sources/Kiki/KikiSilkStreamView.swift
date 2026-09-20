import AppKit
import QuartzCore

/// Live microphone amplitude controls the waves; only their horizontal flow is decorative.
@MainActor
final class KikiSilkStreamView: NSView {
    static let preferredSize = NSSize(width: 240, height: 88)
    private let ribbon = CALayer()
    private var strands: [CAShapeLayer] = []
    private var active = false
    private var thinking = false

    static func amplitude(for samples: [Float]) -> CGFloat {
        let level = VoiceLevelMeter.normalizedLevel(for: samples)
        return 0.12 + 0.88 * min(1, pow(level, 0.56) * 1.25)
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        setAccessibilityElement(false)
        layer?.addSublayer(ribbon)
        for index in 0..<9 {
            let strand = CAShapeLayer()
            strand.fillColor = nil
            strand.strokeColor = NSColor(calibratedRed: CGFloat(106 + index * 10) / 255,
                green: CGFloat(140 + index * 8) / 255, blue: CGFloat(74 + index * 8) / 255,
                alpha: 0.25 + CGFloat(index) * 0.06).cgColor
            strand.lineWidth = index == 8 ? 2.4 : 1.3
            strand.lineCap = .round
            ribbon.addSublayer(strand)
            strands.append(strand)
        }
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(refresh),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layout() { super.layout(); rebuild() }
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); rebuild() }
    override func viewDidHide() { super.viewDidHide(); rebuild() }
    override func viewDidUnhide() { super.viewDidUnhide(); rebuild() }
    @objc private func refresh() { rebuild() }

    func update(samples: [Float]) {
        let needsFlow = !active || thinking
        active = true
        thinking = false
        if needsFlow { rebuild() }
        setAmplitude(Self.amplitude(for: samples))
    }
    func setState(_ state: VoiceOrbState) {
        active = true
        thinking = state == .thinking
        rebuild()
        setAmplitude(thinking ? 0.48 : 0.12)
    }
    func reset() {
        active = false
        thinking = false
        rebuild()
        setAmplitude(0.12)
    }
    private func setAmplitude(_ value: CGFloat) {
        let reduced = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let current = ribbon.presentation()?.transform ?? ribbon.transform
        let target = CATransform3DMakeScale(1, reduced ? 0.25 : value, 1)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        ribbon.transform = target
        CATransaction.commit()
        let response = CABasicAnimation(keyPath: "transform")
        response.fromValue = NSValue(caTransform3D: current)
        response.toValue = NSValue(caTransform3D: target)
        response.duration = 0.18
        response.timingFunction = CAMediaTimingFunction(controlPoints: 0.23, 1, 0.32, 1)
        if !reduced { ribbon.add(response, forKey: "amplitude") }
    }
    private func path(phase: CGFloat, strand: Int) -> CGPath {
        let p = CGMutablePath()
        for step in 0...80 {
            let u = CGFloat(step) / 80
            let y = bounds.height / 2 + sin(u * 9 - phase + CGFloat(strand) * 0.35)
                * pow(sin(u * .pi), 2) * bounds.height * 0.42
            let point = CGPoint(x: 8 + u * max(0, bounds.width - 16), y: y)
            if step == 0 { p.move(to: point) } else { p.addLine(to: point) }
        }
        return p
    }
    private func rebuild() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        ribbon.bounds = bounds
        ribbon.position = CGPoint(x: bounds.midX, y: bounds.midY)
        for (index, strand) in strands.enumerated() {
            strand.frame = bounds
            strand.path = path(phase: 0, strand: index)
            strand.removeAnimation(forKey: "flow")
            if active && window != nil && !isHiddenOrHasHiddenAncestor
                && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
                let flow = CAKeyframeAnimation(keyPath: "path")
                flow.values = (0...48).map { path(phase: CGFloat($0) / 48 * 2 * .pi, strand: index) }
                flow.duration = thinking ? 3.2 : 5.7
                flow.calculationMode = .linear
                flow.repeatCount = .infinity
                strand.add(flow, forKey: "flow")
            }
        }
        CATransaction.commit()
    }
}
