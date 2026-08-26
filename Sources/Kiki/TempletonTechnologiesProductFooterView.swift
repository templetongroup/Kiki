import AppKit

@MainActor
final class TempletonTechnologiesProductFooterView: NSView {
    enum Placement {
        case about
        case sidebar

        var identifierPrefix: String {
            switch self {
            case .about: "kiki.workbench.about.templeton"
            case .sidebar: "kiki.workbench.sidebar.templeton"
            }
        }
    }

    init(placement: Placement = .about) {
        super.init(frame: .zero)
        identifier = NSUserInterfaceItemIdentifier("\(placement.identifierPrefix)-footer")
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor

        let productLabel = kikiLabel(
            placement == .sidebar
                ? "Kiki is a Templeton Technologies product."
                : "A Templeton Technologies Product",
            size: placement == .sidebar ? 9.5 : 12,
            weight: .regular,
            color: KikiPalette.secondaryText
        )
        productLabel.identifier = NSUserInterfaceItemIdentifier("\(placement.identifierPrefix)-product-label")
        productLabel.alignment = .center
        productLabel.lineBreakMode = .byTruncatingTail
        productLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(productLabel)

        let logoButton = NSButton()
        logoButton.identifier = NSUserInterfaceItemIdentifier("\(placement.identifierPrefix)-logo")
        logoButton.isBordered = false
        logoButton.imagePosition = .imageOnly
        logoButton.imageScaling = .scaleProportionallyUpOrDown
        logoButton.target = self
        logoButton.action = #selector(openTempletonTechnologies)
        logoButton.toolTip = "Visit templetontech.com"
        logoButton.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        logoButton.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        logoButton.translatesAutoresizingMaskIntoConstraints = false
        if let url = Bundle.main.url(forResource: "TempletonTechnologies", withExtension: "png") {
            logoButton.image = NSImage(contentsOf: url)
        }
        logoButton.setAccessibilityLabel("Open the Templeton Technologies website")
        addSubview(logoButton)

        switch placement {
        case .about:
            installAboutConstraints(productLabel: productLabel, logoButton: logoButton)
        case .sidebar:
            installSidebarConstraints(productLabel: productLabel, logoButton: logoButton)
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func installAboutConstraints(productLabel: NSTextField, logoButton: NSButton) {
        let responsiveLogoWidth = logoButton.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.34)
        responsiveLogoWidth.priority = .init(998)
        let minimumLogoWidth = logoButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 220)
        minimumLogoWidth.priority = .init(999)

        NSLayoutConstraint.activate([
            productLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            productLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            productLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            productLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24),
            logoButton.topAnchor.constraint(equalTo: productLabel.bottomAnchor, constant: 14),
            logoButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            responsiveLogoWidth,
            minimumLogoWidth,
            logoButton.widthAnchor.constraint(lessThanOrEqualToConstant: 285),
            logoButton.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, constant: -48),
            logoButton.heightAnchor.constraint(equalTo: logoButton.widthAnchor, multiplier: 192.0 / 900.0),
            logoButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -24),
        ])
    }

    private func installSidebarConstraints(productLabel: NSTextField, logoButton: NSButton) {
        NSLayoutConstraint.activate([
            productLabel.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            productLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            productLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            logoButton.topAnchor.constraint(equalTo: productLabel.bottomAnchor, constant: 14),
            logoButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            logoButton.widthAnchor.constraint(equalToConstant: 138),
            logoButton.heightAnchor.constraint(equalTo: logoButton.widthAnchor, multiplier: 192.0 / 900.0),
            logoButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
        ])
    }

    @objc private func openTempletonTechnologies() {
        guard let url = URL(string: "https://templetontech.com") else { return }
        NSWorkspace.shared.open(url)
    }
}
