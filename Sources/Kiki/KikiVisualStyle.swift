import AppKit
import QuartzCore

enum KikiPalette {
    private static func adaptive(dark: NSColor, light: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
        }
    }

    // Quiet, slightly warm neutrals inspired by ChatGPT's desktop workspace.
    static let canvas = adaptive(
        dark: NSColor(red: 0.165, green: 0.200, blue: 0.216, alpha: 1),
        light: NSColor(red: 0.969, green: 0.969, blue: 0.953, alpha: 1)
    )
    static let sidebar = adaptive(
        dark: NSColor(red: 0.137, green: 0.165, blue: 0.176, alpha: 0.98),
        light: NSColor(red: 0.925, green: 0.925, blue: 0.902, alpha: 0.98)
    )
    static let surface = adaptive(
        dark: NSColor(red: 0.194, green: 0.229, blue: 0.242, alpha: 0.96),
        light: NSColor(red: 0.995, green: 0.995, blue: 0.985, alpha: 0.98)
    )
    static let elevatedSurface = adaptive(
        dark: NSColor(red: 0.220, green: 0.255, blue: 0.267, alpha: 1),
        light: NSColor(red: 0.945, green: 0.953, blue: 0.941, alpha: 1)
    )
    static let stroke = adaptive(
        dark: NSColor.white.withAlphaComponent(0.09),
        light: NSColor.black.withAlphaComponent(0.10)
    )
    static let strongStroke = adaptive(
        dark: NSColor.white.withAlphaComponent(0.17),
        light: NSColor.black.withAlphaComponent(0.18)
    )
    static let primaryText = adaptive(
        dark: NSColor(red: 0.925, green: 0.910, blue: 0.866, alpha: 1),
        light: NSColor(red: 0.105, green: 0.118, blue: 0.114, alpha: 1)
    )
    static let secondaryText = adaptive(
        dark: NSColor(red: 0.710, green: 0.690, blue: 0.635, alpha: 1),
        light: NSColor(red: 0.340, green: 0.365, blue: 0.353, alpha: 1)
    )
    static let tertiaryText = adaptive(
        dark: NSColor(red: 0.545, green: 0.535, blue: 0.500, alpha: 1),
        light: NSColor(red: 0.475, green: 0.495, blue: 0.482, alpha: 1)
    )
    static let accent = adaptive(
        dark: NSColor(red: 1.000, green: 0.620, blue: 0.220, alpha: 1),
        light: NSColor(red: 0.820, green: 0.310, blue: 0.055, alpha: 1)
    )
    static let onAccentText = adaptive(
        dark: NSColor(red: 0.110, green: 0.075, blue: 0.035, alpha: 1),
        light: .white
    )
    static let accentText = adaptive(
        dark: NSColor(red: 1.000, green: 0.705, blue: 0.365, alpha: 1),
        light: NSColor(red: 0.690, green: 0.245, blue: 0.035, alpha: 1)
    )
    static let selectionSurface = adaptive(
        dark: NSColor(red: 0.290, green: 0.235, blue: 0.195, alpha: 1),
        light: NSColor(red: 0.955, green: 0.850, blue: 0.735, alpha: 1)
    )
    static let violet = adaptive(
        dark: NSColor(red: 0.755, green: 0.665, blue: 0.505, alpha: 1),
        light: NSColor(red: 0.455, green: 0.335, blue: 0.145, alpha: 1)
    )
    static let magenta = adaptive(
        dark: NSColor(red: 0.765, green: 0.565, blue: 0.545, alpha: 1),
        light: NSColor(red: 0.565, green: 0.270, blue: 0.250, alpha: 1)
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
    private let baseGradient = CAGradientLayer()
    private let softGlow = CAGradientLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        baseGradient.startPoint = CGPoint(x: 0.5, y: 1)
        baseGradient.endPoint = CGPoint(x: 0.5, y: 0)

        softGlow.type = .radial
        softGlow.locations = [0, 1]
        softGlow.startPoint = CGPoint(x: 0.5, y: 0.5)
        softGlow.endPoint = CGPoint(x: 1, y: 1)

        layer?.addSublayer(baseGradient)
        layer?.addSublayer(softGlow)
        updateColors()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        baseGradient.frame = bounds
        softGlow.frame = CGRect(
            x: bounds.width * 0.38,
            y: bounds.height * 0.36,
            width: bounds.width * 0.72,
            height: bounds.height * 0.74
        )
        CATransaction.commit()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }

    private func updateColors() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = KikiPalette.canvas.cgColor
            baseGradient.colors = [
                KikiPalette.canvas.blended(withFraction: 0.035, of: KikiPalette.primaryText)?.cgColor ?? KikiPalette.canvas.cgColor,
                KikiPalette.canvas.cgColor,
            ]
            baseGradient.locations = [0, 1]
            softGlow.colors = [
                KikiPalette.accent.withAlphaComponent(0.035).cgColor,
                NSColor.clear.cgColor,
            ]
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

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        updateStyle()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateStyle()
    }

    func updateStyle() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.cornerRadius = 16
            layer?.cornerCurve = .continuous
            layer?.backgroundColor = (selected ? KikiPalette.selectionSurface : KikiPalette.surface).cgColor
            layer?.borderWidth = 1
            layer?.borderColor = (selected ? KikiPalette.strongStroke : KikiPalette.stroke).cgColor
            layer?.shadowColor = NSColor.black.cgColor
            layer?.shadowOpacity = selected ? 0.15 : 0.10
            layer?.shadowRadius = selected ? 14 : 10
            layer?.shadowOffset = CGSize(width: 0, height: -4)
        }
    }
}

@MainActor
final class KikiNavButton: NSButton {
    var isSelectedPage = false { didSet { updateStyle() } }
    private let symbolView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
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

        contentStack.setViews([symbolView, titleLabel], in: .leading)
        contentStack.orientation = .horizontal
        contentStack.alignment = .centerY
        contentStack.spacing = 8
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(contentStack)

        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.cornerCurve = .continuous
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

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled, let action else { return }
        NSApp.sendAction(action, to: target, from: self)
    }

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
            let color = isSelectedPage ? KikiPalette.primaryText : KikiPalette.secondaryText
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
        isBordered = false
        focusRingType = .none
        font = .systemFont(ofSize: 13, weight: .semibold)
        wantsLayer = true
        layer?.cornerRadius = 10
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
            alphaValue = isEnabled ? 1 : 0.48
            switch kind {
            case .primary:
                layer?.backgroundColor = KikiPalette.accent.cgColor
                layer?.borderWidth = 0
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
        layer?.cornerRadius = 12
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
            layer?.backgroundColor = KikiPalette.canvas.withAlphaComponent(0.54).cgColor
            layer?.borderColor = KikiPalette.stroke.cgColor
            let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            scrollerKnobStyle = isDark ? .light : .dark
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
