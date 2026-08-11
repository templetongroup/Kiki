import AppKit
import QuartzCore

enum KikiPalette {
    private static func adaptive(dark: NSColor, light: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        }
    }

    // Studio Hardware geometry and material treatment stay unchanged. The neutral
    // ramp comes directly from Templeton Slate; sage remains Kiki's highlight.
    static let canvas = adaptive(
        dark: NSColor(red: 0.212, green: 0.235, blue: 0.271, alpha: 1), // #363c45
        light: NSColor(red: 0.957, green: 0.945, blue: 0.918, alpha: 1) // #f4f1ea
    )
    static let sidebar = adaptive(
        dark: NSColor(red: 0.180, green: 0.204, blue: 0.235, alpha: 1), // #2e343c
        light: NSColor(red: 0.914, green: 0.898, blue: 0.859, alpha: 1) // #e9e5db
    )
    static let surface = adaptive(
        dark: NSColor(red: 0.192, green: 0.216, blue: 0.251, alpha: 1), // #313740
        light: NSColor(red: 0.925, green: 0.910, blue: 0.875, alpha: 1) // #ece8df
    )
    static let cardTopTint = adaptive(
        dark: NSColor.white.withAlphaComponent(0.025),
        light: NSColor.white.withAlphaComponent(0.06)
    )
    static let cardBottomShade = adaptive(
        dark: NSColor.black.withAlphaComponent(0.10),
        light: NSColor.black.withAlphaComponent(0.025)
    )
    static let cardInnerStroke = adaptive(
        dark: NSColor.white.withAlphaComponent(0.035),
        light: NSColor.white.withAlphaComponent(0.20)
    )
    static let elevatedSurface = adaptive(
        dark: NSColor(red: 0.251, green: 0.278, blue: 0.318, alpha: 1), // #404751
        light: NSColor(red: 0.886, green: 0.867, blue: 0.820, alpha: 1) // #e2ddd1
    )
    static let stroke = adaptive(
        dark: NSColor(red: 0.271, green: 0.298, blue: 0.337, alpha: 1), // #454c56
        light: NSColor(red: 0.839, green: 0.816, blue: 0.761, alpha: 1) // #d6d0c2
    )
    static let strongStroke = adaptive(
        dark: NSColor(red: 0.655, green: 0.753, blue: 0.502, alpha: 0.48),
        light: NSColor(red: 0.306, green: 0.357, blue: 0.282, alpha: 0.38)
    )
    static let primaryText = adaptive(
        dark: NSColor(red: 0.906, green: 0.871, blue: 0.784, alpha: 1), // #e7dec8
        light: NSColor(red: 0.204, green: 0.196, blue: 0.173, alpha: 1) // #34322c
    )
    static let secondaryText = adaptive(
        dark: NSColor(red: 0.702, green: 0.667, blue: 0.588, alpha: 1), // #b3aa96
        light: NSColor(red: 0.420, green: 0.404, blue: 0.341, alpha: 1) // #6b6757
    )
    static let tertiaryText = adaptive(
        dark: NSColor(red: 0.514, green: 0.486, blue: 0.424, alpha: 1), // #837c6c
        light: NSColor(red: 0.604, green: 0.584, blue: 0.525, alpha: 1) // #9a9586
    )
    static let accent = adaptive(
        dark: NSColor(red: 0.322, green: 0.400, blue: 0.239, alpha: 1), // #52663d
        light: NSColor(red: 0.376, green: 0.424, blue: 0.349, alpha: 1) // #606c59
    )
    static let onAccentText = adaptive(
        dark: NSColor(red: 0.906, green: 0.871, blue: 0.784, alpha: 1),
        light: NSColor(red: 0.957, green: 0.945, blue: 0.918, alpha: 1)
    )
    static let accentText = adaptive(
        dark: NSColor(red: 0.655, green: 0.753, blue: 0.502, alpha: 1), // #a7c080
        light: NSColor(red: 0.306, green: 0.357, blue: 0.282, alpha: 1) // #4e5b48
    )
    static let selectionSurface = adaptive(
        dark: NSColor(red: 0.251, green: 0.278, blue: 0.318, alpha: 1), // #404751
        light: NSColor(red: 0.886, green: 0.867, blue: 0.820, alpha: 1) // #e2ddd1
    )
    static let khaki = adaptive(
        dark: NSColor(red: 0.671, green: 0.648, blue: 0.502, alpha: 1),
        light: NSColor(red: 0.565, green: 0.545, blue: 0.420, alpha: 1)
    )
    static let hardwareControl = NSColor(red: 0.165, green: 0.184, blue: 0.216, alpha: 1) // #2a2f37
    static let hardwareControlText = NSColor(red: 0.906, green: 0.871, blue: 0.784, alpha: 1) // #e7dec8
    static let hardwareButtonSurface = adaptive(
        dark: NSColor(red: 0.165, green: 0.184, blue: 0.216, alpha: 1),
        light: NSColor(red: 0.165, green: 0.184, blue: 0.216, alpha: 1)
    )
    static let hardwareButtonBorder = adaptive(
        dark: NSColor(red: 0.271, green: 0.298, blue: 0.337, alpha: 1),
        light: NSColor(red: 0.271, green: 0.298, blue: 0.337, alpha: 1)
    )
    static let meterTrack = adaptive(
        dark: NSColor(red: 0.165, green: 0.184, blue: 0.216, alpha: 1),
        light: NSColor(red: 0.839, green: 0.816, blue: 0.761, alpha: 1)
    )
    static let meterAccent = adaptive(
        dark: NSColor(red: 0.655, green: 0.753, blue: 0.502, alpha: 1),
        light: NSColor(red: 0.306, green: 0.357, blue: 0.282, alpha: 1)
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
    var usesSelectionBorder = true { didSet { updateStyle() } }
    var cardCornerRadius: CGFloat = 8 { didSet { updateStyle() } }
    var usesHardwareDepth = true { didSet { updateStyle() } }
    private let verticalDepth = CAGradientLayer()
    private let innerBorder = CAShapeLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        verticalDepth.startPoint = CGPoint(x: 0.5, y: 0)
        verticalDepth.endPoint = CGPoint(x: 0.5, y: 1)
        verticalDepth.name = "kiki.card.matte-depth"
        innerBorder.fillColor = nil
        innerBorder.lineWidth = 1
        innerBorder.name = "kiki.card.inner-border"
        layer?.addSublayer(verticalDepth)
        layer?.addSublayer(innerBorder)
        updateStyle()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateStyle()
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        verticalDepth.frame = bounds
        verticalDepth.cornerRadius = cardCornerRadius
        innerBorder.frame = bounds
        innerBorder.path = CGPath(
            roundedRect: bounds.insetBy(dx: 1.5, dy: 1.5),
            cornerWidth: max(0, cardCornerRadius - 1.5),
            cornerHeight: max(0, cardCornerRadius - 1.5),
            transform: nil
        )
        layer?.shadowPath = CGPath(
            roundedRect: bounds,
            cornerWidth: cardCornerRadius,
            cornerHeight: cardCornerRadius,
            transform: nil
        )
        CATransaction.commit()
    }

    func updateStyle() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.cornerRadius = cardCornerRadius
            layer?.cornerCurve = .continuous
            layer?.backgroundColor = (selected && usesSelectionFill ? KikiPalette.selectionSurface : KikiPalette.surface).cgColor
            verticalDepth.isHidden = !usesHardwareDepth
            verticalDepth.colors = [
                KikiPalette.cardTopTint.cgColor,
                NSColor.clear.cgColor,
                KikiPalette.cardBottomShade.cgColor,
            ]
            verticalDepth.locations = [0, 0.55, 1]
            innerBorder.isHidden = !usesHardwareDepth
            innerBorder.strokeColor = KikiPalette.cardInnerStroke.cgColor
            layer?.borderWidth = 1
            layer?.borderColor = (selected && usesSelectionBorder ? KikiPalette.strongStroke : KikiPalette.stroke).cgColor
            layer?.shadowColor = NSColor.black.cgColor
            let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            layer?.shadowOpacity = isDark ? (selected ? 0.24 : 0.18) : (selected ? 0.12 : 0.08)
            layer?.shadowRadius = selected ? 8 : 4
            layer?.shadowOffset = CGSize(width: 0, height: -1)
        }
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
        font = .systemFont(ofSize: kind == .hardware ? 11.5 : 13, weight: kind == .hardware ? .regular : .semibold)
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

    override var title: String { didSet { updateStyle() } }
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
                alphaValue = 1
                switch kind {
                case .quiet:
                    layer?.backgroundColor = NSColor.clear.cgColor
                    layer?.borderWidth = 0
                    applyTitleColor(KikiPalette.secondaryText.withAlphaComponent(0.86))
                case .hardware:
                    layer?.backgroundColor = KikiPalette.hardwareButtonSurface.cgColor
                    layer?.borderWidth = 1
                    layer?.borderColor = KikiPalette.hardwareButtonBorder.cgColor
                    applyTitleColor(KikiPalette.hardwareControlText.withAlphaComponent(0.88))
                default:
                    layer?.backgroundColor = KikiPalette.elevatedSurface.cgColor
                    layer?.borderWidth = 1
                    layer?.borderColor = KikiPalette.stroke.cgColor
                    applyTitleColor(KikiPalette.primaryText.withAlphaComponent(0.70))
                }
                return
            }
            alphaValue = 1
            switch kind {
            case .primary:
                layer?.backgroundColor = KikiPalette.accent.cgColor
                layer?.borderWidth = 1
                layer?.borderColor = KikiPalette.accentText.withAlphaComponent(0.55).cgColor
                applyTitleColor(KikiPalette.onAccentText)
            case .secondary:
                layer?.backgroundColor = KikiPalette.elevatedSurface.cgColor
                layer?.borderWidth = 1
                layer?.borderColor = KikiPalette.strongStroke.cgColor
                applyTitleColor(KikiPalette.primaryText)
            case .hardware:
                layer?.backgroundColor = KikiPalette.hardwareButtonSurface.cgColor
                layer?.borderWidth = 1
                layer?.borderColor = KikiPalette.hardwareButtonBorder.cgColor
                layer?.shadowColor = NSColor.black.cgColor
                layer?.shadowOpacity = 0.28
                layer?.shadowRadius = 2
                layer?.shadowOffset = CGSize(width: 0, height: -1)
                applyTitleColor(KikiPalette.hardwareControlText)
            case .quiet:
                layer?.backgroundColor = NSColor.clear.cgColor
                layer?.borderWidth = 0
                applyTitleColor(KikiPalette.secondaryText)
            case .danger:
                layer?.backgroundColor = NSColor.systemRed.withAlphaComponent(0.88).cgColor
                layer?.borderWidth = 0
                applyTitleColor(.white)
            }
        }
    }

    private func applyTitleColor(_ color: NSColor) {
        contentTintColor = color
        var attributes: [NSAttributedString.Key: Any] = [.foregroundColor: color]
        if let font { attributes[.font] = font }
        attributedTitle = NSAttributedString(string: title, attributes: attributes)
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
        identifier = NSUserInterfaceItemIdentifier("kiki.model.dial")
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
            let housing = CGRect(x: bounds.midX - 17, y: bounds.midY - 17, width: 34, height: 34)
            let shadow = NSBezierPath(roundedRect: housing.offsetBy(dx: 0, dy: -1), xRadius: 6, yRadius: 6)
            NSColor.black.withAlphaComponent(0.68).setFill()
            shadow.fill()

            let face = NSBezierPath(roundedRect: housing, xRadius: 6, yRadius: 6)
            KikiPalette.hardwareControl.setFill()
            face.fill()
            KikiPalette.strongStroke.setStroke()
            face.lineWidth = 1
            face.stroke()

            let insetPanel = NSBezierPath(roundedRect: housing.insetBy(dx: 4, dy: 4), xRadius: 5, yRadius: 5)
            NSColor.black.withAlphaComponent(0.52).setFill()
            insetPanel.fill()
            KikiPalette.stroke.setStroke()
            insetPanel.lineWidth = 1
            insetPanel.stroke()

            let knobRect = housing.insetBy(dx: 8, dy: 8)
            let knob = NSBezierPath(ovalIn: knobRect)
            (isActive
                ? KikiPalette.primaryText
                : NSColor(red: 0.205, green: 0.205, blue: 0.205, alpha: 1)
            ).setFill()
            knob.fill()
            NSColor.black.withAlphaComponent(0.72).setStroke()
            knob.lineWidth = 1
            knob.stroke()

            let highlightRect = CGRect(
                x: knobRect.minX + 3,
                y: knobRect.maxY - 6,
                width: 5,
                height: 3
            )
            NSColor.white.withAlphaComponent(isActive ? 0.26 : 0.14).setFill()
            NSBezierPath(ovalIn: highlightRect).fill()
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
                .font: NSFont.monospacedDigitSystemFont(ofSize: 8.5, weight: .medium),
                .foregroundColor: KikiPalette.meterAccent,
            ]
            let baselineY: CGFloat = 18.5
            let arcLeft: CGFloat = 17
            let arcRight = bounds.width - 8
            let labelPositions: [CGFloat] = [14, 35, 56, 76, 93]

            let arc = NSBezierPath()
            arc.move(to: CGPoint(x: arcLeft, y: 7.5))
            arc.curve(
                to: CGPoint(x: arcRight, y: 7.5),
                controlPoint1: CGPoint(x: 36, y: 18),
                controlPoint2: CGPoint(x: 71, y: 18)
            )
            KikiPalette.meterAccent.setStroke()
            arc.lineWidth = 1.2
            arc.stroke()

            for (index, label) in labels.enumerated() {
                let progress = CGFloat(index) / CGFloat(labels.count - 1)
                let x = labelPositions[index]
                let curveY = 7.5 + sin(progress * .pi) * 7
                let tick = NSBezierPath()
                if index == 0 {
                    tick.move(to: CGPoint(x: arcLeft, y: 7.5))
                    tick.line(to: CGPoint(x: 9, y: 14))
                } else if index == labels.count - 1 {
                    tick.move(to: CGPoint(x: arcRight, y: 7.5))
                    tick.line(to: CGPoint(x: bounds.width - 3, y: 14.5))
                } else {
                    tick.move(to: CGPoint(x: x, y: curveY))
                    tick.line(to: CGPoint(x: x, y: curveY + 5.5))
                }
                KikiPalette.meterAccent.setStroke()
                tick.lineWidth = 1
                tick.stroke()
                let size = label.size(withAttributes: attributes)
                label.draw(at: CGPoint(x: x - size.width / 2, y: baselineY), withAttributes: attributes)
            }
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
final class KikiEmptyStateView: NSView {
    private let symbolView = NSImageView()
    private let titleLabel: NSTextField
    private let detailLabel: NSTextField

    init(symbol: String, title: String, detail: String) {
        titleLabel = kikiLabel(title, size: 14, weight: .semibold)
        detailLabel = kikiLabel(detail, size: 12, color: KikiPalette.secondaryText)
        super.init(frame: .zero)

        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel(title)
        setAccessibilityHelp(detail)

        symbolView.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        symbolView.contentTintColor = KikiPalette.accentText
        symbolView.imageScaling = .scaleProportionallyDown
        symbolView.setAccessibilityElement(false)
        detailLabel.alignment = .center
        detailLabel.maximumNumberOfLines = 3

        let stack = NSStackView(views: [symbolView, titleLabel, detailLabel])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 7
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            symbolView.widthAnchor.constraint(equalToConstant: 28),
            symbolView.heightAnchor.constraint(equalToConstant: 28),
            detailLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 320),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -20),
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        symbolView.contentTintColor = KikiPalette.accentText
    }
}

@MainActor
final class KikiDataSurfaceView: KikiCardView {
    let scrollView = KikiScrollView()
    let emptyState: KikiEmptyStateView

    var isEmpty = true {
        didSet {
            emptyState.isHidden = !isEmpty
            scrollView.isHidden = isEmpty
        }
    }

    init(table: NSTableView, emptySymbol: String, emptyTitle: String, emptyDetail: String) {
        emptyState = KikiEmptyStateView(symbol: emptySymbol, title: emptyTitle, detail: emptyDetail)
        super.init(frame: .zero)
        if let tableIdentifier = table.identifier?.rawValue {
            identifier = NSUserInterfaceItemIdentifier("\(tableIdentifier).surface")
            emptyState.identifier = NSUserInterfaceItemIdentifier("\(tableIdentifier).empty")
        }
        usesHardwareDepth = false
        cardCornerRadius = 7

        scrollView.documentView = table
        scrollView.hasVerticalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        emptyState.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)
        addSubview(emptyState)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 1),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -1),
            scrollView.topAnchor.constraint(equalTo: topAnchor, constant: 1),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -1),
            emptyState.leadingAnchor.constraint(equalTo: leadingAnchor),
            emptyState.trailingAnchor.constraint(equalTo: trailingAnchor),
            emptyState.topAnchor.constraint(equalTo: topAnchor),
            emptyState.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        isEmpty = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

@MainActor
final class KikiGuidedStepView: KikiCardView {
    init(number: Int, title: String, detail: String, trailing: NSView? = nil) {
        super.init(frame: .zero)

        let numberLabel = kikiLabel("\(number)", size: 12, weight: .semibold, color: KikiPalette.accentText)
        numberLabel.alignment = .center
        numberLabel.wantsLayer = true
        numberLabel.layer?.cornerRadius = 15
        numberLabel.layer?.borderWidth = 1
        numberLabel.layer?.borderColor = KikiPalette.strongStroke.cgColor

        let titleLabel = kikiLabel(title, size: 14, weight: .semibold)
        titleLabel.maximumNumberOfLines = 2
        let detailLabel = kikiLabel(detail, size: 11.5, color: KikiPalette.secondaryText)
        detailLabel.maximumNumberOfLines = 3
        let copy = NSStackView(views: [titleLabel, detailLabel])
        copy.orientation = .vertical
        copy.alignment = .leading
        copy.spacing = 4

        numberLabel.translatesAutoresizingMaskIntoConstraints = false
        copy.translatesAutoresizingMaskIntoConstraints = false
        addSubview(numberLabel)
        addSubview(copy)
        var constraints = [
            numberLabel.widthAnchor.constraint(equalToConstant: 30),
            numberLabel.heightAnchor.constraint(equalToConstant: 30),
            numberLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            numberLabel.topAnchor.constraint(equalTo: topAnchor, constant: 14),
            copy.leadingAnchor.constraint(equalTo: numberLabel.trailingAnchor, constant: 12),
            copy.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            copy.topAnchor.constraint(equalTo: topAnchor, constant: 12),
        ]
        if let trailing {
            trailing.translatesAutoresizingMaskIntoConstraints = false
            addSubview(trailing)
            constraints += [
                trailing.leadingAnchor.constraint(equalTo: copy.leadingAnchor),
                trailing.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -14),
                trailing.topAnchor.constraint(equalTo: copy.bottomAnchor, constant: 10),
                trailing.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            ]
        } else {
            constraints.append(copy.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12))
        }
        NSLayoutConstraint.activate(constraints)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

@MainActor
func kikiFieldGroup(
    _ title: String,
    detail: String? = nil,
    control: NSView
) -> NSStackView {
    let titleLabel = kikiLabel(title, size: 11.5, weight: .semibold)
    let views: [NSView]
    if let detail {
        let detailLabel = kikiLabel(detail, size: 10.5, color: KikiPalette.secondaryText)
        detailLabel.maximumNumberOfLines = 2
        views = [titleLabel, detailLabel, control]
    } else {
        views = [titleLabel, control]
    }
    let stack = NSStackView(views: views)
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.spacing = 5
    control.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    return stack
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
