import AppKit

/// Small floating pill near the bottom of the screen showing recording state.
final class HUDPanel {
    private let panel: NSPanel
    private let label: NSTextField

    init() {
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 200, height: 44),
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
        effect.layer?.cornerRadius = 12
        effect.layer?.masksToBounds = true

        label = NSTextField(labelWithString: "")
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.alignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: effect.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: effect.centerYAnchor),
        ])

        panel.contentView = effect
    }

    func show(_ text: String) {
        label.stringValue = text
        guard let screen = NSScreen.main else { return }
        let visible = screen.visibleFrame
        let width = max(160, label.intrinsicContentSize.width + 48)
        let frame = NSRect(x: visible.midX - width / 2,
                           y: visible.minY + 60,
                           width: width,
                           height: 44)
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }
}
