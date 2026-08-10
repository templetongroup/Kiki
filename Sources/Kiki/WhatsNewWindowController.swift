import AppKit

@MainActor
final class WhatsNewWindowController: NSWindowController, NSWindowDelegate {
    var onExplore: (() -> Void)?
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "New"
    }

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1_040, height: 620),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "What’s New in Kiki"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = false
        window.isReleasedWhenClosed = false
        super.init(window: window)
        window.delegate = self
        buildContent()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func showIfNeeded(force: Bool = false) {
        let key = "lastSeenWhatsNewVersion"
        guard force || UserDefaults.standard.string(forKey: key) != version else { return }
        UserDefaults.standard.set(version, forKey: key)
        showWindow(nil)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildContent() {
        guard let content = window?.contentView else { return }
        let backdrop = KikiBackdropView()
        backdrop.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(backdrop)
        NSLayoutConstraint.activate([
            backdrop.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            backdrop.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            backdrop.topAnchor.constraint(equalTo: content.topAnchor),
            backdrop.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])

        let icon = NSImageView()
        if let url = Bundle.main.url(forResource: "SplashArtwork", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            icon.image = image
        } else {
            assertionFailure("SplashArtwork.png is missing from the Kiki app bundle")
            icon.image = NSApp.applicationIconImage
        }
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.identifier = NSUserInterfaceItemIdentifier("kiki.whats-new.splash-artwork")
        icon.wantsLayer = true
        icon.layer?.cornerRadius = 30
        icon.layer?.masksToBounds = true

        let badge = kikiLabel("", size: 11, weight: .semibold, color: KikiPalette.accentText)
        badge.alignment = .left
        badge.attributedStringValue = NSAttributedString(
            string: "NEW IN \(version)",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: KikiPalette.accentText,
                .kern: 1.5,
            ]
        )

        let title = kikiLabel("Meet Kiki Voice Studio.", size: 30, weight: .bold)
        title.alignment = .left
        let detail = kikiLabel(
            "Create speech in your own voice—fully local, private, and ready to export.",
            size: 14,
            color: KikiPalette.secondaryText
        )
        detail.alignment = .left
        detail.maximumNumberOfLines = 2

        let features = NSStackView(views: [
            featureRow(symbol: "mic.badge.plus", title: "Create your voice", detail: "Read one guided passage. Recording-quality checks help capture a clean private reference.", tint: KikiPalette.accentText),
            featureRow(symbol: "text.bubble", title: "Write and listen", detail: "Turn short notes or long scripts into natural speech without sending text or audio anywhere.", tint: KikiPalette.violet),
            featureRow(symbol: "square.and.arrow.up", title: "Export anywhere", detail: "Play the result in Kiki or save a polished WAV or M4A audio file.", tint: KikiPalette.magenta),
        ])
        features.orientation = .vertical
        features.alignment = .leading
        features.distribution = .fillEqually
        features.spacing = 10

        let explore = KikiActionButton("Open Voice Studio", kind: .primary, target: self, action: #selector(explorePressed))
        let later = KikiActionButton("Not now", kind: .quiet, target: self, action: #selector(closePressed))
        let actions = NSStackView(views: [explore, later])
        actions.orientation = .horizontal
        actions.alignment = .centerY
        actions.spacing = 12

        let copy = NSStackView(views: [badge, title, detail, features, actions])
        copy.orientation = .vertical
        copy.alignment = .leading
        copy.spacing = 10
        copy.setCustomSpacing(12, after: badge)
        copy.setCustomSpacing(8, after: title)
        copy.setCustomSpacing(22, after: detail)
        copy.setCustomSpacing(24, after: features)
        copy.identifier = NSUserInterfaceItemIdentifier("kiki.whats-new.copy")

        let hero = NSStackView(views: [icon, copy])
        hero.orientation = .horizontal
        hero.alignment = .centerY
        hero.spacing = 44
        hero.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(hero)
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 340),
            icon.heightAnchor.constraint(equalToConstant: 340),
            copy.widthAnchor.constraint(equalToConstant: 530),
            detail.widthAnchor.constraint(equalToConstant: 500),
            features.widthAnchor.constraint(equalToConstant: 530),
            features.heightAnchor.constraint(equalToConstant: 240),
            explore.widthAnchor.constraint(greaterThanOrEqualToConstant: 210),
            hero.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            hero.centerYAnchor.constraint(equalTo: content.centerYAnchor),
            hero.leadingAnchor.constraint(greaterThanOrEqualTo: content.leadingAnchor, constant: 48),
            hero.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -48),
            hero.topAnchor.constraint(greaterThanOrEqualTo: content.topAnchor, constant: 38),
            hero.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -38),
        ])
    }

    private func featureRow(
        symbol: String,
        title: String,
        detail: String,
        tint: NSColor
    ) -> NSView {
        let card = KikiCardView()
        let image = NSImageView(image: NSImage(systemSymbolName: symbol, accessibilityDescription: title) ?? NSImage())
        image.contentTintColor = tint
        let titleLabel = kikiLabel(title, size: 14.5, weight: .semibold)
        let detailLabel = kikiLabel(detail, size: 11.5, color: KikiPalette.secondaryText)
        detailLabel.alignment = .left
        detailLabel.maximumNumberOfLines = 2
        let labels = NSStackView(views: [titleLabel, detailLabel])
        labels.orientation = .vertical
        labels.alignment = .leading
        labels.spacing = 4
        let stack = NSStackView(views: [image, labels])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            image.widthAnchor.constraint(equalToConstant: 26),
            image.heightAnchor.constraint(equalToConstant: 26),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
        ])
        return card
    }

    @objc private func explorePressed() {
        close()
        onExplore?()
    }

    @objc private func closePressed() { close() }
}
