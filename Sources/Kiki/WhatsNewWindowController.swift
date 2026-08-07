import AppKit

@MainActor
final class WhatsNewWindowController: NSWindowController, NSWindowDelegate {
    var onExplore: (() -> Void)?
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "New"
    }

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 610),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "What’s New in Kiki"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
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
        if let url = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png") {
            icon.image = NSImage(contentsOf: url)
        }
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.wantsLayer = true
        icon.layer?.cornerRadius = 17
        icon.layer?.masksToBounds = true

        let badge = kikiLabel("", size: 11, weight: .semibold, color: KikiPalette.cyan)
        badge.alignment = .center
        badge.attributedStringValue = NSAttributedString(
            string: "NEW IN \(version)",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: KikiPalette.cyan,
                .kern: 1.5,
            ]
        )

        let title = kikiLabel("Your voice has a new home.", size: 30, weight: .bold)
        title.alignment = .center
        let detail = kikiLabel(
            "Designed around speed, privacy, and the way you actually work.",
            size: 14,
            color: KikiPalette.secondaryText
        )
        detail.alignment = .center

        let features = NSStackView(views: [
            featureCard(symbol: "waveform", title: "Faster flow", detail: "Live words, zero-wait chaining, and a HUD that stays near your cursor.", tint: KikiPalette.cyan),
            featureCard(symbol: "brain.head.profile", title: "Learns you", detail: "Approved corrections, vocabulary, snippets, and private zones—all local.", tint: KikiPalette.violet),
            featureCard(symbol: "person.2.wave.2", title: "Meeting Mode", detail: "Capture both sides, create chapters, and export clean captions.", tint: KikiPalette.magenta),
        ])
        features.orientation = .horizontal
        features.alignment = .top
        features.distribution = .fillEqually
        features.spacing = 12

        let explore = KikiActionButton("Explore the new Kiki", kind: .primary, target: self, action: #selector(explorePressed))
        let later = KikiActionButton("Not now", kind: .quiet, target: self, action: #selector(closePressed))
        let actions = NSStackView(views: [explore, later])
        actions.orientation = .vertical
        actions.alignment = .centerX
        actions.spacing = 8

        let stack = NSStackView(views: [icon, badge, title, detail, features, actions])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 12
        stack.setCustomSpacing(20, after: icon)
        stack.setCustomSpacing(12, after: badge)
        stack.setCustomSpacing(8, after: title)
        stack.setCustomSpacing(24, after: detail)
        stack.setCustomSpacing(22, after: features)
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 68),
            icon.heightAnchor.constraint(equalToConstant: 68),
            detail.widthAnchor.constraint(equalToConstant: 510),
            features.widthAnchor.constraint(equalToConstant: 640),
            features.heightAnchor.constraint(equalToConstant: 158),
            explore.widthAnchor.constraint(greaterThanOrEqualToConstant: 200),
            stack.centerXAnchor.constraint(equalTo: content.centerXAnchor),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 48),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -28),
        ])
    }

    private func featureCard(
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
        detailLabel.alignment = .center
        detailLabel.maximumNumberOfLines = 4
        let stack = NSStackView(views: [image, titleLabel, detailLabel])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 9
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            image.widthAnchor.constraint(equalToConstant: 28),
            image.heightAnchor.constraint(equalToConstant: 28),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -12),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 17),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: card.bottomAnchor, constant: -14),
        ])
        return card
    }

    @objc private func explorePressed() {
        close()
        onExplore?()
    }

    @objc private func closePressed() { close() }
}
