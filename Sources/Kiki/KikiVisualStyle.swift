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
        dark: NSColor(red: 0.067, green: 0.075, blue: 0.067, alpha: 1),
        light: NSColor(red: 0.957, green: 0.945, blue: 0.910, alpha: 1)
    )
    static let sidebar = adaptive(
        dark: NSColor(red: 0.087, green: 0.097, blue: 0.086, alpha: 1),
        light: NSColor(red: 0.925, green: 0.908, blue: 0.866, alpha: 1)
    )
    static let surface = adaptive(
        dark: NSColor(red: 0.105, green: 0.116, blue: 0.102, alpha: 1),
        light: NSColor(red: 0.985, green: 0.976, blue: 0.949, alpha: 1)
    )
    static let elevatedSurface = adaptive(
        dark: NSColor(red: 0.137, green: 0.151, blue: 0.132, alpha: 1),
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
        dark: NSColor(red: 0.166, green: 0.190, blue: 0.154, alpha: 1),
        light: NSColor(red: 0.855, green: 0.871, blue: 0.824, alpha: 1)
    )
    static let khaki = adaptive(
        dark: NSColor(red: 0.671, green: 0.648, blue: 0.502, alpha: 1),
        light: NSColor(red: 0.565, green: 0.545, blue: 0.420, alpha: 1)
    )
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
    var showsFasteners = false { didSet { updateFasteners() } }
    private let fasteners = (0..<4).map { _ in CALayer() }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        fasteners.forEach {
            $0.cornerRadius = 2
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
        let size: CGFloat = 4
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
                $0.backgroundColor = KikiPalette.khaki.withAlphaComponent(0.72).cgColor
                $0.borderWidth = 0.5
                $0.borderColor = KikiPalette.strongStroke.cgColor
            }
        }
        needsLayout = true
    }

    func updateStyle() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.cornerRadius = 8
            layer?.cornerCurve = .continuous
            layer?.backgroundColor = (selected ? KikiPalette.selectionSurface : KikiPalette.surface).cgColor
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

@MainActor
final class KikiNavButton: NSButton {
    var isSelectedPage = false { didSet { updateStyle() } }
    private let symbolView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let contentStack = NSStackView()
    private let selectionRail = CALayer()

    init(title: String, symbol: String, target: AnyObject?, action: Selector?) {
        super.init(frame: .zero)
        self.title = ""
        isBordered = false
        focusRingType = .exterior
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

        contentStack.setViews([symbolView, titleLabel], in: .leading)
        contentStack.orientation = .horizontal
        contentStack.alignment = .centerY
        contentStack.spacing = 8
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentStack)

        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.cornerCurve = .continuous
        selectionRail.cornerRadius = 1.5
        layer?.addSublayer(selectionRail)
        heightAnchor.constraint(equalToConstant: 42).isActive = true
        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            contentStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -14),
            contentStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            symbolView.widthAnchor.constraint(equalToConstant: 16),
            symbolView.heightAnchor.constraint(equalToConstant: 16),
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

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        selectionRail.frame = CGRect(x: 0, y: 7, width: 3, height: max(0, bounds.height - 14))
        CATransaction.commit()
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard !isHidden, alphaValue > 0.01, frame.contains(point) else { return nil }
        return self
    }

    private func updateStyle() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = isSelectedPage
                ? KikiPalette.selectionSurface.cgColor
                : NSColor.clear.cgColor
            layer?.borderWidth = 0
            selectionRail.backgroundColor = KikiPalette.accent.cgColor
            selectionRail.isHidden = !isSelectedPage
            let color = isSelectedPage ? KikiPalette.accentText : KikiPalette.secondaryText
            symbolView.contentTintColor = color
            titleLabel.textColor = color
        }
    }
}

@MainActor
final class KikiActionButton: NSButton {
    enum Kind { case primary, secondary, quiet, danger }
    private let kind: Kind

    init(_ title: String, kind: Kind = .secondary, target: AnyObject?, action: Selector?) {
        self.kind = kind
        super.init(frame: .zero)
        self.title = title
        self.target = target
        self.action = action
        setButtonType(.momentaryPushIn)
        isBordered = false
        focusRingType = .exterior
        font = .systemFont(ofSize: 13, weight: .semibold)
        lineBreakMode = .byTruncatingTail
        cell?.wraps = false
        setContentCompressionResistancePriority(.required, for: .vertical)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.cornerCurve = .continuous
        alignment = .center
        heightAnchor.constraint(greaterThanOrEqualToConstant: 42).isActive = true
        updateStyle()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isEnabled: Bool { didSet { updateStyle() } }

    override var intrinsicContentSize: NSSize {
        let base = super.intrinsicContentSize
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
                default:
                    layer?.backgroundColor = KikiPalette.elevatedSurface.cgColor
                    layer?.borderWidth = 1
                    layer?.borderColor = KikiPalette.stroke.cgColor
                }
                contentTintColor = KikiPalette.tertiaryText
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
