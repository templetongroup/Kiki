import AppKit
import QuartzCore

enum KikiPalette {
    static let canvas = NSColor(red: 0.025, green: 0.028, blue: 0.075, alpha: 1)
    static let sidebar = NSColor(red: 0.035, green: 0.038, blue: 0.09, alpha: 0.96)
    static let surface = NSColor(red: 0.07, green: 0.075, blue: 0.14, alpha: 0.82)
    static let elevatedSurface = NSColor(red: 0.095, green: 0.10, blue: 0.19, alpha: 0.94)
    static let stroke = NSColor.white.withAlphaComponent(0.11)
    static let strongStroke = NSColor.white.withAlphaComponent(0.20)
    static let primaryText = NSColor(white: 0.97, alpha: 1)
    static let secondaryText = NSColor(white: 0.68, alpha: 1)
    static let tertiaryText = NSColor(white: 0.48, alpha: 1)
    static let electricBlue = NSColor(red: 0.16, green: 0.48, blue: 1.0, alpha: 1)
    static let cyan = NSColor(red: 0.16, green: 0.82, blue: 1.0, alpha: 1)
    static let violet = NSColor(red: 0.52, green: 0.31, blue: 1.0, alpha: 1)
    static let magenta = NSColor(red: 0.87, green: 0.25, blue: 1.0, alpha: 1)
    static let success = NSColor(red: 0.27, green: 0.88, blue: 0.58, alpha: 1)
}

@MainActor
final class KikiFlippedView: NSView {
    override var isFlipped: Bool { true }
}

@MainActor
final class KikiBackdropView: NSView {
    private let baseGradient = CAGradientLayer()
    private let blueGlow = CAGradientLayer()
    private let violetGlow = CAGradientLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = KikiPalette.canvas.cgColor

        baseGradient.colors = [
            KikiPalette.canvas.cgColor,
            NSColor(red: 0.035, green: 0.04, blue: 0.12, alpha: 1).cgColor,
            KikiPalette.canvas.cgColor,
        ]
        baseGradient.locations = [0, 0.52, 1]
        baseGradient.startPoint = CGPoint(x: 0.05, y: 1)
        baseGradient.endPoint = CGPoint(x: 0.95, y: 0)

        blueGlow.type = .radial
        blueGlow.colors = [
            KikiPalette.electricBlue.withAlphaComponent(0.30).cgColor,
            KikiPalette.cyan.withAlphaComponent(0.08).cgColor,
            NSColor.clear.cgColor,
        ]
        blueGlow.locations = [0, 0.42, 1]
        blueGlow.startPoint = CGPoint(x: 0.5, y: 0.5)
        blueGlow.endPoint = CGPoint(x: 1, y: 1)

        violetGlow.type = .radial
        violetGlow.colors = [
            KikiPalette.violet.withAlphaComponent(0.26).cgColor,
            KikiPalette.magenta.withAlphaComponent(0.06).cgColor,
            NSColor.clear.cgColor,
        ]
        violetGlow.locations = [0, 0.38, 1]
        violetGlow.startPoint = CGPoint(x: 0.5, y: 0.5)
        violetGlow.endPoint = CGPoint(x: 1, y: 1)

        layer?.addSublayer(baseGradient)
        layer?.addSublayer(blueGlow)
        layer?.addSublayer(violetGlow)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        baseGradient.frame = bounds
        blueGlow.frame = CGRect(
            x: bounds.width * 0.38,
            y: bounds.height * 0.34,
            width: bounds.width * 0.88,
            height: bounds.height * 1.05
        )
        violetGlow.frame = CGRect(
            x: bounds.width * -0.28,
            y: bounds.height * -0.42,
            width: bounds.width * 0.95,
            height: bounds.height * 1.05
        )
        CATransaction.commit()
    }
}

@MainActor
final class KikiSidebarView: NSView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = KikiPalette.sidebar.cgColor
        layer?.borderColor = KikiPalette.stroke.cgColor
        layer?.borderWidth = 1
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
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

    func updateStyle() {
        layer?.cornerRadius = 16
        layer?.cornerCurve = .continuous
        layer?.backgroundColor = (selected ? KikiPalette.elevatedSurface : KikiPalette.surface).cgColor
        layer?.borderWidth = selected ? 1.5 : 1
        layer?.borderColor = (selected ? KikiPalette.electricBlue.withAlphaComponent(0.78) : KikiPalette.stroke).cgColor
        layer?.shadowColor = (selected ? KikiPalette.electricBlue : NSColor.black).cgColor
        layer?.shadowOpacity = selected ? 0.18 : 0.12
        layer?.shadowRadius = selected ? 20 : 12
        layer?.shadowOffset = CGSize(width: 0, height: -5)
    }
}

@MainActor
final class KikiNavButton: NSButton {
    var isSelectedPage = false { didSet { updateStyle() } }

    init(title: String, symbol: String, target: AnyObject?, action: Selector?) {
        super.init(frame: .zero)
        self.title = title
        image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        imagePosition = .imageLeading
        imageHugsTitle = true
        alignment = .left
        font = .systemFont(ofSize: 13.5, weight: .medium)
        isBordered = false
        focusRingType = .none
        self.target = target
        self.action = action
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.cornerCurve = .continuous
        contentTintColor = KikiPalette.secondaryText
        heightAnchor.constraint(equalToConstant: 42).isActive = true
        updateStyle()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func updateStyle() {
        layer?.backgroundColor = isSelectedPage
            ? KikiPalette.electricBlue.withAlphaComponent(0.18).cgColor
            : NSColor.clear.cgColor
        layer?.borderWidth = isSelectedPage ? 1 : 0
        layer?.borderColor = KikiPalette.electricBlue.withAlphaComponent(0.35).cgColor
        contentTintColor = isSelectedPage ? KikiPalette.primaryText : KikiPalette.secondaryText
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
        layer?.cornerRadius = 9
        layer?.cornerCurve = .continuous
        heightAnchor.constraint(greaterThanOrEqualToConstant: 34).isActive = true
        updateStyle()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isEnabled: Bool { didSet { updateStyle() } }

    private func updateStyle() {
        alphaValue = isEnabled ? 1 : 0.48
        switch kind {
        case .primary:
            layer?.backgroundColor = KikiPalette.electricBlue.cgColor
            layer?.borderWidth = 1
            layer?.borderColor = KikiPalette.cyan.withAlphaComponent(0.52).cgColor
            contentTintColor = .white
        case .secondary:
            layer?.backgroundColor = NSColor.white.withAlphaComponent(0.075).cgColor
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
