import Foundation
import Sparkle

/// Production `UpdateChecking` adapter around Sparkle's standard updater controller.
@MainActor
final class SparkleUpdateChecker: NSObject, UpdateChecking {
    weak var delegate: UpdateCheckDelegate?

    private let controller: SPUStandardUpdaterController

    var isSessionInProgress: Bool {
        controller.updater.sessionInProgress
    }

    init(
        updaterDelegate: SPUUpdaterDelegate,
        userDriverDelegate: SPUStandardUserDriverDelegate
    ) {
        controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: updaterDelegate,
            userDriverDelegate: userDriverDelegate
        )
        // PeekBar owns automatic scheduling via `UpdateController` and `SettingsStore`.
        controller.updater.automaticallyChecksForUpdates = false
        super.init()
    }

    func start() throws {
        try controller.updater.start()
    }

    func checkForUpdates(userInitiated: Bool) {
        if userInitiated {
            controller.updater.checkForUpdates()
        } else {
            controller.updater.checkForUpdatesInBackground()
        }
    }
}
