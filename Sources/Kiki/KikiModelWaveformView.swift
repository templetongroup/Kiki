import AppKit
import QuartzCore

/// Decorative model-state indicator, never a microphone level meter.
@MainActor
final class KikiModelWaveformView: NSView {
    var processing = false { didSet { rebuild() } }
    private var waves: [CAShapeLayer] = []

    override init(frame: NSRect) {
        super.init(frame: frame)
        identifier = .init("kiki.model.silk-waveform")
        wantsLayer = true
        setAccessibilityElement(false)
        for index in 0..<5 {
            let wave = CAShapeLayer()
            wave.fillColor = nil
            wave.lineWidth = index == 4 ? 1.6 : 1
            wave.lineCap = .round
            layer?.addSublayer(wave)
            waves.append(wave)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(refreshMotion), name: NSWindow.didChangeOcclusionStateNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refreshMotion), name: NSApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(refreshMotion), name: NSApplication.didResignActiveNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(refreshMotion), name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); rebuild() }
    override func viewDidHide() { super.viewDidHide(); rebuild() }
    override func viewDidUnhide() { super.viewDidUnhide(); rebuild() }
    override func layout() { super.layout(); rebuild() }
    override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); rebuild() }
    @objc private func refreshMotion() { rebuild() }

    private func path(phase: CGFloat, strand: Int) -> CGPath {
        let path = CGMutablePath()
        let amplitude: CGFloat = processing ? 0.36 : 0.22
        for step in 0...64 {
            let u = CGFloat(step) / 64
            let envelope = pow(sin(u * .pi), 2)
            let y = bounds.midY + sin(u * 10 - phase + CGFloat(strand) * 0.7) * envelope * bounds.height * amplitude
            let point = CGPoint(x: 4 + u * max(0, bounds.width - 8), y: y)
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        return path
    }

    private func rebuild() {
        guard !waves.isEmpty else { return }
        let animate = window?.occlusionState.contains(.visible) == true
            && NSApp.isActive && !isHiddenOrHasHiddenAncestor && !visibleRect.isEmpty
            && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (index, wave) in waves.enumerated() {
            wave.removeAnimation(forKey: "silk")
            wave.frame = bounds
            effectiveAppearance.performAsCurrentDrawingAppearance {
                wave.strokeColor = KikiPalette.accentText.withAlphaComponent(0.22 + Double(index) * 0.16).cgColor
            }
            wave.path = path(phase: 0, strand: index)
            if animate {
                // Precomputed paths run in Core Animation: no per-frame Swift timer.
                let motion = CAKeyframeAnimation(keyPath: "path")
                motion.values = (0...48).map { path(phase: CGFloat($0) / 48 * 2 * .pi, strand: index) }
                motion.duration = processing ? 2.4 : 6.4
                motion.calculationMode = .linear
                motion.repeatCount = .infinity
                wave.add(motion, forKey: "silk")
            }
        }
        CATransaction.commit()
    }
}
