import AppKit
import QuartzCore

enum KikiPalette {
    private static func adaptive(dark: NSColor, light: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        }
    }

    // Studio Hardware: warm enamel in light mode, charcoal equipment panels in dark mode.
    // Sage and khaki are sampled from the Templeton palette and remain consistent
    // across both appearances.
    static let canvas = adaptive(
        dark: NSColor(red: 0.102, green: 0.102, blue: 0.110, alpha: 1),
        light: NSColor(red: 0.957, green: 0.945, blue: 0.910, alpha: 1)
    )
    static let sidebar = adaptive(
        dark: NSColor(red: 0.094, green: 0.094, blue: 0.102, alpha: 1),
        light: NSColor(red: 0.925, green: 0.908, blue: 0.866, alpha: 1)
    )
    static let surface = adaptive(
        dark: NSColor(red: 0.114, green: 0.114, blue: 0.118, alpha: 1),
        light: NSColor(red: 0.985, green: 0.976, blue: 0.949, alpha: 1)
    )
    static let elevatedSurface = adaptive(
        dark: NSColor(red: 0.137, green: 0.137, blue: 0.141, alpha: 1),
        light: NSColor(red: 0.929, green: 0.918, blue: 0.882, alpha: 1)
    )
    static let stroke = adaptive(
        dark: NSColor(red: 0.620, green: 0.600, blue: 0.475, alpha: 0.22),
        light: NSColor(red: 0.160, green: 0.175, blue: 0.150, alpha: 0.16)
    )
    static let strongStroke = adaptive(
        dark: NSColor(red: 0.620, green: 0.600, blue: 0.475, alpha: 0.40),
        light: NSColor(red: 0.160, green: 0.175, blue: 0.150, alpha: 0.28)
    )
    static let primaryText = adaptive(
        dark: NSColor(red: 0.949, green: 0.933, blue: 0.886, alpha: 1),
        light: NSColor(red: 0.137, green: 0.143, blue: 0.122, alpha: 1)
    )
    static let secondaryText = adaptive(
        dark: NSColor(red: 0.735, green: 0.712, blue: 0.643, alpha: 1),
        light: NSColor(red: 0.335, green: 0.347, blue: 0.302, alpha: 1)
    )
    static let tertiaryText = adaptive(
        dark: NSColor(red: 0.545, green: 0.533, blue: 0.475, alpha: 1),
        light: NSColor(red: 0.455, green: 0.459, blue: 0.400, alpha: 1)
    )
    static let accent = adaptive(
        dark: NSColor(red: 0.424, green: 0.482, blue: 0.396, alpha: 1),
        light: NSColor(red: 0.376, green: 0.424, blue: 0.349, alpha: 1)
    )
    static let onAccentText = adaptive(
        dark: NSColor(red: 0.985, green: 0.976, blue: 0.949, alpha: 1),
        light: NSColor(red: 0.985, green: 0.976, blue: 0.949, alpha: 1)
    )
    static let accentText = adaptive(
        dark: NSColor(red: 0.653, green: 0.698, blue: 0.604, alpha: 1),
        light: NSColor(red: 0.306, green: 0.357, blue: 0.282, alpha: 1)
    )
    static let selectionSurface = adaptive(
        dark: NSColor(red: 0.231, green: 0.239, blue: 0.196, alpha: 1),
        light: NSColor(red: 0.855, green: 0.871, blue: 0.824, alpha: 1)
    )
    static let khaki = adaptive(
        dark: NSColor(red: 0.671, green: 0.648, blue: 0.502, alpha: 1),
        light: NSColor(red: 0.565, green: 0.545, blue: 0.420, alpha: 1)
    )
    static let hardwareControl = NSColor(red: 0.094, green: 0.094, blue: 0.098, alpha: 1)
    static let hardwareControlText = NSColor(red: 0.949, green: 0.933, blue: 0.886, alpha: 1)
    static let meterTrack = adaptive(
        dark: NSColor(red: 0.038, green: 0.043, blue: 0.037, alpha: 1),
        light: NSColor(red: 0.865, green: 0.847, blue: 0.800, alpha: 1)
    )
    static let violet = adaptive(
        dark: NSColor(red: 0.671, green: 0.648, blue: 0.502, alpha: 1),
        light: NSColor(red: 0.565, green: 0.545, blue: 0.420, alpha: 1)
    )
    static let magenta = adaptive(
        dark: NSColor(red: 0.565, green: 0.606, blue: 0.520, alpha: 1),
        light: NSColor(red: 0.420, green: 0.467, blue: 0.388, alpha: 1)
    )
    static let success = adaptive(
        dark: NSColor(red: 0.295, green: 0.760, blue: 0.565, alpha: 1),
        light: NSColor(red: 0.040, green: 0.505, blue: 0.330, alpha: 1)
    )
}

@MainActor
final class KikiFlippedView: NSView {
    override var isFlipped: Bool { true }
}

@MainActor
final class KikiBackdropView: NSView {
    private let topRail = CALayer()
    private let bottomRail = CALayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.addSublayer(topRail)
        layer?.addSublayer(bottomRail)
        updateColors()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        topRail.frame = CGRect(x: 0, y: bounds.height - 1, width: bounds.width, height: 1)
        bottomRail.frame = CGRect(x: 0, y: 0, width: bounds.width, height: 1)
        CATransaction.commit()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }

    private func updateColors() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = KikiPalette.canvas.cgColor
            topRail.backgroundColor = KikiPalette.strongStroke.cgColor
            bottomRail.backgroundColor = KikiPalette.stroke.cgColor
        }
    }
}

@MainActor
final class KikiSidebarView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.borderWidth = 1
        updateColors()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }

    private func updateColors() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = KikiPalette.sidebar.cgColor
            layer?.borderColor = KikiPalette.stroke.cgColor
        }
    }
}

@MainActor
class KikiCardView: NSView {
    var selected = false { didSet { updateStyle() } }
    var usesSelectionFill = true { didSet { updateStyle() } }
    var showsFasteners = false { didSet { updateFasteners() } }
    private let fasteners = (0..<4).map { _ in KikiFastenerLayer() }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        fasteners.forEach {
            $0.isHidden = true
            layer?.addSublayer($0)
        }
        updateStyle()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateStyle()
    }

    override func layout() {
        super.layout()
        let inset: CGFloat = 7
        let size: CGFloat = 10
        let positions = [
            CGPoint(x: inset, y: inset),
            CGPoint(x: max(inset, bounds.width - inset - size), y: inset),
            CGPoint(x: inset, y: max(inset, bounds.height - inset - size)),
            CGPoint(x: max(inset, bounds.width - inset - size), y: max(inset, bounds.height - inset - size)),
        ]
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (fastener, point) in zip(fasteners, positions) {
            fastener.frame = CGRect(origin: point, size: CGSize(width: size, height: size))
        }
        CATransaction.commit()
    }

    private func updateFasteners() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            fasteners.forEach {
                $0.isHidden = !showsFasteners
                $0.applyColors(
                    face: KikiPalette.khaki,
                    edge: KikiPalette.strongStroke,
                    slot: KikiPalette.canvas
                )
            }
        }
        needsLayout = true
    }

    func updateStyle() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.cornerRadius = 8
            layer?.cornerCurve = .continuous
            layer?.backgroundColor = (selected && usesSelectionFill ? KikiPalette.selectionSurface : KikiPalette.surface).cgColor
            layer?.borderWidth = 1
            layer?.borderColor = (selected ? KikiPalette.strongStroke : KikiPalette.stroke).cgColor
            layer?.shadowColor = NSColor.black.cgColor
            layer?.shadowOpacity = selected ? 0.12 : 0.04
            layer?.shadowRadius = selected ? 9 : 4
            layer?.shadowOffset = CGSize(width: 0, height: -2)
            updateFasteners()
        }
    }
}

private final class KikiFastenerLayer: CALayer {
    private let slot = CALayer()
    private let highlight = CALayer()

    override init() {
        super.init()
        cornerRadius = 5
        borderWidth = 1
        shadowColor = NSColor.black.cgColor
        shadowOpacity = 0.35
        shadowRadius = 1.5
        shadowOffset = CGSize(width: 0, height: -1)
        slot.cornerRadius = 0.5
        slot.setAffineTransform(CGAffineTransform(rotationAngle: -.pi / 4))
        highlight.cornerRadius = 1
        addSublayer(slot)
        addSublayer(highlight)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSublayers() {
        super.layoutSublayers()
        slot.frame = CGRect(x: bounds.midX - 0.55, y: bounds.midY - 3, width: 1.1, height: 6)
        highlight.frame = CGRect(x: 2, y: bounds.height - 4, width: 2, height: 2)
    }

    func applyColors(face: NSColor, edge: NSColor, slot slotColor: NSColor) {
        backgroundColor = face.cgColor
        borderColor = edge.cgColor
        slot.backgroundColor = slotColor.withAlphaComponent(0.8).cgColor
        highlight.backgroundColor = NSColor.white.withAlphaComponent(0.55).cgColor
    }
}

@MainActor
final class KikiNavButton: NSButton {
    var isSelectedPage = false { didSet { updateStyle() } }
    private let symbolView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let chevronView = NSImageView()
    private let contentStack = NSStackView()

    init(title: String, symbol: String, target: AnyObject?, action: Selector?) {
        super.init(frame: .zero)
        self.title = ""
        isBordered = false
        focusRingType = .none
        self.target = target
        self.action = action
        setAccessibilityLabel(title)
        toolTip = title

        symbolView.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        symbolView.imageScaling = .scaleProportionallyDown
        symbolView.setContentHuggingPriority(.required, for: .horizontal)
        titleLabel.stringValue = title
        titleLabel.font = .systemFont(ofSize: 13.5, weight: .medium)
        titleLabel.lineBreakMode = .byTruncatingTail
        chevronView.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil)
        chevronView.imageScaling = .scaleProportionallyDown
        chevronView.setContentHuggingPriority(.required, for: .horizontal)

        contentStack.setViews([symbolView, titleLabel, chevronView], in: .leading)
        contentStack.orientation = .horizontal
        contentStack.alignment = .centerY
        contentStack.spacing = 8
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentStack)

        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.cornerCurve = .continuous
        heightAnchor.constraint(equalToConstant: 42).isActive = true
        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            contentStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -14),
            contentStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            symbolView.widthAnchor.constraint(equalToConstant: 16),
            symbolView.heightAnchor.constraint(equalToConstant: 16),
            chevronView.widthAnchor.constraint(equalToConstant: 9),
            chevronView.heightAnchor.constraint(equalToConstant: 12),
        ])
        updateStyle()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateStyle()
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: ceil(contentStack.fittingSize.width) + 28, height: 42)
    }

    override var mouseDownCanMoveWindow: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard !isHidden, alphaValue > 0.01, frame.contains(point) else { return nil }
        return self
    }

    private func updateStyle() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = isSelectedPage
                ? KikiPalette.selectionSurface.withAlphaComponent(0.72).cgColor
                : NSColor.clear.cgColor
            layer?.borderWidth = isSelectedPage ? 1 : 0
            layer?.borderColor = KikiPalette.khaki.withAlphaComponent(0.48).cgColor
            let color = isSelectedPage ? KikiPalette.accentText : KikiPalette.secondaryText
            symbolView.contentTintColor = color
            titleLabel.textColor = color
            chevronView.contentTintColor = color
            chevronView.isHidden = !isSelectedPage
        }
    }
}

@MainActor
final class KikiCircularPortraitView: NSView {
    private var portrait: NSImage?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        if let url = Bundle.main.url(forResource: "SplashArtwork", withExtension: "png") {
            portrait = NSImage(contentsOf: url)
        } else if let url = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png") {
            portrait = NSImage(contentsOf: url)
        }
        wantsLayer = true
        setAccessibilityElement(false)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let portraitRect = bounds.insetBy(dx: 2, dy: 2)
        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(ovalIn: portraitRect).addClip()
        KikiPalette.meterTrack.setFill()
        NSBezierPath(rect: portraitRect).fill()
        if let portrait {
            let source = NSRect(
                x: portrait.size.width * 0.16,
                y: portrait.size.height * 0.34,
                width: portrait.size.width * 0.68,
                height: portrait.size.height * 0.62
            )
            portrait.draw(in: portraitRect, from: source, operation: .sourceOver, fraction: 1)
        }
        NSGraphicsContext.restoreGraphicsState()
        KikiPalette.khaki.withAlphaComponent(0.5).setStroke()
        let ring = NSBezierPath(ovalIn: portraitRect.insetBy(dx: 0.5, dy: 0.5))
        ring.lineWidth = 1
        ring.stroke()
    }
}

@MainActor
final class KikiActionButton: NSButton {
    enum Kind { case primary, secondary, hardware, quiet, danger }
    private let kind: Kind

    init(_ title: String, kind: Kind = .secondary, target: AnyObject?, action: Selector?) {
        self.kind = kind
        super.init(frame: .zero)
        self.title = title
        self.target = target
        self.action = action
        setButtonType(.momentaryPushIn)
        isBordered = false
        focusRingType = .none
        font = .systemFont(ofSize: kind == .hardware ? 12 : 13, weight: .semibold)
        lineBreakMode = .byTruncatingTail
        cell?.wraps = false
        setContentCompressionResistancePriority(.required, for: .vertical)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.cornerCurve = .continuous
        alignment = .center
        heightAnchor.constraint(greaterThanOrEqualToConstant: kind == .hardware ? 32 : 42).isActive = true
        updateStyle()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isEnabled: Bool { didSet { updateStyle() } }

    override var intrinsicContentSize: NSSize {
        let base = super.intrinsicContentSize
        if kind == .hardware {
            return NSSize(width: ceil(base.width) + 24, height: max(32, ceil(base.height) + 12))
        }
        return NSSize(width: ceil(base.width) + 40, height: max(42, ceil(base.height) + 18))
    }

    override var mouseDownCanMoveWindow: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateStyle()
    }

    private func updateStyle() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            if !isEnabled {
                alphaValue = 0.78
                switch kind {
                case .quiet:
                    layer?.backgroundColor = NSColor.clear.cgColor
                    layer?.borderWidth = 0
                    contentTintColor = KikiPalette.tertiaryText
                case .hardware:
                    layer?.backgroundColor = KikiPalette.hardwareControl.withAlphaComponent(0.72).cgColor
                    layer?.borderWidth = 1
                    layer?.borderColor = KikiPalette.khaki.withAlphaComponent(0.34).cgColor
                    contentTintColor = KikiPalette.hardwareControlText.withAlphaComponent(0.62)
                default:
                    layer?.backgroundColor = KikiPalette.elevatedSurface.cgColor
                    layer?.borderWidth = 1
                    layer?.borderColor = KikiPalette.stroke.cgColor
                    contentTintColor = KikiPalette.tertiaryText
                }
                return
            }
            alphaValue = 1
            switch kind {
            case .primary:
                layer?.backgroundColor = KikiPalette.accent.cgColor
                layer?.borderWidth = 1
                layer?.borderColor = KikiPalette.accentText.withAlphaComponent(0.55).cgColor
                contentTintColor = KikiPalette.onAccentText
            case .secondary:
                layer?.backgroundColor = KikiPalette.elevatedSurface.cgColor
                layer?.borderWidth = 1
                layer?.borderColor = KikiPalette.strongStroke.cgColor
                contentTintColor = KikiPalette.primaryText
            case .hardware:
                layer?.backgroundColor = KikiPalette.hardwareControl.cgColor
                layer?.borderWidth = 1
                layer?.borderColor = KikiPalette.khaki.withAlphaComponent(0.5).cgColor
                layer?.shadowColor = NSColor.black.cgColor
                layer?.shadowOpacity = 0.28
                layer?.shadowRadius = 2
                layer?.shadowOffset = CGSize(width: 0, height: -1)
                contentTintColor = KikiPalette.hardwareControlText
            case .quiet:
                layer?.backgroundColor = NSColor.clear.cgColor
                layer?.borderWidth = 0
                contentTintColor = KikiPalette.secondaryText
            case .danger:
                layer?.backgroundColor = NSColor.systemRed.withAlphaComponent(0.88).cgColor
                layer?.borderWidth = 0
                contentTintColor = .white
            }
        }
    }
}

@MainActor
final class KikiScrollView: NSScrollView {
    var fillsBackground = true { didSet { updateStyle() } }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        drawsBackground = false
        borderType = .noBorder
        autohidesScrollers = true
        scrollerStyle = .overlay
        horizontalScrollElasticity = .none
        verticalScrollElasticity = .none
        automaticallyAdjustsContentInsets = false
        contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.cornerCurve = .continuous
        layer?.borderWidth = 1
        updateStyle()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateStyle()
    }

    private func updateStyle() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = fillsBackground
                ? KikiPalette.canvas.withAlphaComponent(0.54).cgColor
                : NSColor.clear.cgColor
            layer?.borderWidth = fillsBackground ? 1 : 0
            layer?.borderColor = KikiPalette.stroke.cgColor
            let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            scrollerKnobStyle = isDark ? .light : .dark
        }
    }
}

@MainActor
final class KikiInsetPanelView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.cornerCurve = .continuous
        layer?.borderWidth = 1
        layer?.masksToBounds = true
        updateStyle()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateStyle()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateStyle()
    }

    private func updateStyle() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = KikiPalette.elevatedSurface.cgColor
            layer?.borderColor = KikiPalette.strongStroke.cgColor
        }
    }
}

@MainActor
final class KikiHardwareDialView: NSView {
    var isActive = false { didSet { needsDisplay = true } }

    override var isFlipped: Bool { false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setAccessibilityElement(false)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        effectiveAppearance.performAsCurrentDrawingAppearance {
            let side = min(bounds.width, bounds.height) - 2
            let dialRect = CGRect(
                x: bounds.midX - side / 2,
                y: bounds.midY - side / 2,
                width: side,
                height: side
            )
            KikiPalette.meterTrack.setFill()
            NSBezierPath(ovalIn: dialRect).fill()
            KikiPalette.strongStroke.setStroke()
            let ring = NSBezierPath(ovalIn: dialRect.insetBy(dx: 0.5, dy: 0.5))
            ring.lineWidth = 1
            ring.stroke()

            let inner = dialRect.insetBy(dx: 7, dy: 7)
            (isActive ? KikiPalette.khaki : KikiPalette.elevatedSurface).setFill()
            NSBezierPath(ovalIn: inner).fill()

            let indicator = NSBezierPath()
            indicator.move(to: CGPoint(x: bounds.midX, y: bounds.midY + 3))
            indicator.line(to: CGPoint(x: bounds.midX + side * 0.18, y: bounds.midY + side * 0.25))
            (isActive ? KikiPalette.accentText : KikiPalette.tertiaryText).setStroke()
            indicator.lineWidth = 2
            indicator.lineCapStyle = .round
            indicator.stroke()
        }
    }
}

@MainActor
final class KikiAnalogMeterView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        identifier = NSUserInterfaceItemIdentifier("kiki.model.analog-meter")
        setAccessibilityElement(false)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        effectiveAppearance.performAsCurrentDrawingAppearance {
            let labels = ["-30", "-18", "-12", "-6", "0"]
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 6.5, weight: .medium),
                .foregroundColor: KikiPalette.secondaryText,
            ]
            let baselineY: CGFloat = 21
            let left: CGFloat = 5
            let right = bounds.width - 5

            KikiPalette.stroke.setStroke()
            let arc = NSBezierPath()
            arc.move(to: CGPoint(x: left, y: 8))
            arc.curve(
                to: CGPoint(x: right, y: 8),
                controlPoint1: CGPoint(x: bounds.width * 0.33, y: 18),
                controlPoint2: CGPoint(x: bounds.width * 0.67, y: 18)
            )
            arc.lineWidth = 1
            arc.stroke()

            for (index, label) in labels.enumerated() {
                let progress = CGFloat(index) / CGFloat(labels.count - 1)
                let x = left + progress * (right - left)
                let height: CGFloat = index == 0 || index == labels.count - 1 ? 8 : 6
                let tick = NSBezierPath()
                tick.move(to: CGPoint(x: x, y: 7))
                tick.line(to: CGPoint(x: x, y: 7 + height))
                KikiPalette.khaki.setStroke()
                tick.lineWidth = 1
                tick.stroke()
                let size = label.size(withAttributes: attributes)
                label.draw(at: CGPoint(x: x - size.width / 2, y: baselineY), withAttributes: attributes)
            }

            let needle = NSBezierPath()
            needle.move(to: CGPoint(x: bounds.midX, y: 4))
            needle.line(to: CGPoint(x: bounds.width * 0.72, y: 15))
            KikiPalette.accentText.setStroke()
            needle.lineWidth = 1.5
            needle.lineCapStyle = .round
            needle.stroke()
        }
    }
}

@MainActor
final class KikiInfoButton: NSButton {
    private let infoTitle: String
    private let infoDetail: String
    private var infoPopover: NSPopover?

    init(title: String, detail: String) {
        infoTitle = title
        infoDetail = detail
        super.init(frame: .zero)
        self.title = ""
        image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: "More about \(title)")
        imagePosition = .imageOnly
        isBordered = false
        focusRingType = .none
        contentTintColor = KikiPalette.secondaryText
        toolTip = detail
        target = self
        action = #selector(showInfo)
        setAccessibilityLabel("More about \(title)")
        widthAnchor.constraint(equalToConstant: 22).isActive = true
        heightAnchor.constraint(equalToConstant: 22).isActive = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var mouseDownCanMoveWindow: Bool { false }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        contentTintColor = KikiPalette.secondaryText
    }

    @objc private func showInfo() {
        let titleLabel = kikiLabel(infoTitle, size: 14, weight: .semibold)
        let detailLabel = kikiLabel(infoDetail, size: 12.5, color: KikiPalette.secondaryText)
        detailLabel.maximumNumberOfLines = 0
        let stack = NSStackView(views: [titleLabel, detailLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 7
        stack.translatesAutoresizingMaskIntoConstraints = false

        let viewController = NSViewController()
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 116))
        content.addSubview(stack)
        viewController.view = content
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -16),
            stack.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            detailLabel.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])

        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentSize = content.frame.size
        popover.contentViewController = viewController
        infoPopover = popover
        popover.show(relativeTo: bounds, of: self, preferredEdge: .maxX)
    }
}

@MainActor
func kikiLabel(
    _ text: String,
    size: CGFloat,
    weight: NSFont.Weight = .regular,
    color: NSColor = KikiPalette.primaryText
) -> NSTextField {
    let label = NSTextField(wrappingLabelWithString: text)
    label.font = .systemFont(ofSize: size, weight: weight)
    label.textColor = color
    label.isSelectable = false
    return label
}
