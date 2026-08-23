import AppKit
import Sparkle

@MainActor
final class UpdateController: NSObject, @preconcurrency SPUStandardUserDriverDelegate {
    var onUpdateAvailable: (@MainActor (Bool) -> Void)?

    private lazy var controller = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: self
    )

    var automaticallyChecksForUpdates: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }

    var automaticallyDownloadsUpdates: Bool {
        get { controller.updater.automaticallyDownloadsUpdates }
        set { controller.updater.automaticallyDownloadsUpdates = newValue }
    }

    @objc func checkForUpdates(_ sender: Any?) {
        controller.checkForUpdates(sender)
    }

    // Kiki has no Dock icon, so scheduled update alerts should not suddenly
    // jump in front of the user's current app. Sparkle shows urgent reminders;
    // otherwise Kiki marks its menu item until the user opens the update UI.
    var supportsGentleScheduledUpdateReminders: Bool { true }

    func standardUserDriverShouldHandleShowingScheduledUpdate(
        _ update: SUAppcastItem,
        andInImmediateFocus immediateFocus: Bool
    ) -> Bool {
        immediateFocus
    }

    func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        onUpdateAvailable?(!handleShowingUpdate)
    }

    func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        onUpdateAvailable?(false)
    }

    func standardUserDriverWillFinishUpdateSession() {
        onUpdateAvailable?(false)
    }
}
