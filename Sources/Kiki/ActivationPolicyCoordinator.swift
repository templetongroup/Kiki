import AppKit

/// Keeps Kiki menu-bar-only until a real management window is open.
@MainActor
final class ActivationPolicyCoordinator: NSObject {
    private var openManagementWindows: Set<ObjectIdentifier> = []
    private var isObserving = false

    func start() {
        guard !isObserving else { return }
        isObserving = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeKey(_:)),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: nil
        )

        for window in NSApp.windows where window.isVisible || window.isMiniaturized {
            trackIfManagementWindow(window)
        }
        reconcileActivationPolicy()
    }

    func prepareToPresentManagementWindow(_ window: NSWindow?) {
        guard let window else { return }
        trackIfManagementWindow(window)
        reconcileActivationPolicy()
    }

    func stop() {
        guard isObserving else { return }
        NotificationCenter.default.removeObserver(self)
        openManagementWindows.removeAll()
        isObserving = false
    }

    @objc private func windowDidBecomeKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        trackIfManagementWindow(window)
        reconcileActivationPolicy()
    }

    @objc private func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        openManagementWindows.remove(ObjectIdentifier(window))
        reconcileActivationPolicy()
    }

    private func trackIfManagementWindow(_ window: NSWindow) {
        guard Self.isManagementWindow(window) else { return }
        openManagementWindows.insert(ObjectIdentifier(window))
    }

    private func reconcileActivationPolicy() {
        let target: NSApplication.ActivationPolicy = openManagementWindows.isEmpty
            ? .accessory
            : .regular
        guard NSApp.activationPolicy() != target else { return }
        guard NSApp.setActivationPolicy(target) else { return }
        if target == .regular {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private static func isManagementWindow(_ window: NSWindow) -> Bool {
        window.styleMask.contains(.titled)
            && !window.styleMask.contains(.nonactivatingPanel)
    }
}
