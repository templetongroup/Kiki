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
    static let electricBlue = adaptive(
        dark: NSColor(red: 0.035, green: 0.430, blue: 0.345, alpha: 1),
        light: NSColor(red: 0.045, green: 0.475, blue: 0.380, alpha: 1)
    )
    static let cyan = adaptive(
        dark: NSColor(red: 0.545, green: 0.755, blue: 0.690, alpha: 1),
        light: NSColor(red: 0.035, green: 0.420, blue: 0.345, alpha: 1)
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
                KikiPalette.electricBlue.withAlphaComponent(0.035).cgColor,
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
            layer?.backgroundColor = (selected ? KikiPalette.elevatedSurface : KikiPalette.surface).cgColor
            layer?.borderWidth = selected ? 1.5 : 1
            layer?.borderColor = (selected ? KikiPalette.electricBlue.withAlphaComponent(0.78) : KikiPalette.stroke).cgColor
            layer?.shadowColor = (selected ? KikiPalette.electricBlue : NSColor.black).cgColor
            layer?.shadowOpacity = selected ? 0.18 : 0.12
            layer?.shadowRadius = selected ? 20 : 12
            layer?.shadowOffset = CGSize(width: 0, height: -5)
        }
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

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateStyle()
    }

    private func updateStyle() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = isSelectedPage
                ? KikiPalette.electricBlue.withAlphaComponent(0.18).cgColor
                : NSColor.clear.cgColor
            layer?.borderWidth = isSelectedPage ? 1 : 0
            layer?.borderColor = KikiPalette.electricBlue.withAlphaComponent(0.35).cgColor
            contentTintColor = isSelectedPage ? KikiPalette.primaryText : KikiPalette.secondaryText
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
        layer?.cornerRadius = 9
        layer?.cornerCurve = .continuous
        heightAnchor.constraint(greaterThanOrEqualToConstant: 34).isActive = true
        updateStyle()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var isEnabled: Bool { didSet { updateStyle() } }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateStyle()
    }

    private func updateStyle() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            alphaValue = isEnabled ? 1 : 0.48
            switch kind {
            case .primary:
                layer?.backgroundColor = KikiPalette.electricBlue.cgColor
                layer?.borderWidth = 1
                layer?.borderColor = KikiPalette.cyan.withAlphaComponent(0.52).cgColor
                contentTintColor = .white
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
