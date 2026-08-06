import AppKit

/// Small floating pill near the bottom of the screen showing recording state.
final class HUDPanel {
    private let panel: NSPanel
    private let logoView: NSImageView
    private let label: NSTextField

    init() {
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 220, height: 48),
                        styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered,
                        defer: true)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let effect = NSVisualEffectView()
        effect.material = .hudWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 14
        effect.layer?.masksToBounds = true

        logoView = NSImageView()
        logoView.imageScaling = .scaleProportionallyUpOrDown
        if let url = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png") {
            logoView.image = NSImage(contentsOf: url)
        }
        logoView.isHidden = logoView.image == nil

        label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.alignment = .center

        let content = NSStackView(views: [logoView, label])
        content.orientation = .horizontal
        content.alignment = .centerY
        content.spacing = 9
        content.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(content)
        NSLayoutConstraint.activate([
            logoView.widthAnchor.constraint(equalToConstant: 28),
            logoView.heightAnchor.constraint(equalToConstant: 28),
            content.centerXAnchor.constraint(equalTo: effect.centerXAnchor),
            content.centerYAnchor.constraint(equalTo: effect.centerYAnchor),
        ])

        panel.contentView = effect
    }

    func show(_ text: String) {
        label.stringValue = text
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let logoWidth: CGFloat = logoView.isHidden ? 0 : 37
        let width = max(180, label.intrinsicContentSize.width + logoWidth + 48)
        let frame = NSRect(x: visible.midX - width / 2,
                           y: visible.minY + 60,
                           width: width,
                           height: 48)
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }
}
