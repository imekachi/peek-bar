import Foundation
import Sparkle

/// Forwards Sparkle delegate callbacks onto the main-actor `UpdateController`.
final class SparkleUpdateDelegateBridge: NSObject, SPUUpdaterDelegate, SPUStandardUserDriverDelegate {
    weak var owner: UpdateController?

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        Task { @MainActor [weak owner] in
            owner?.updateCheckDidFindValidUpdate()
        }
    }

    func updater(
        _ updater: SPUUpdater,
        didFinishUpdateCycleFor updateCheck: SPUUpdateCheck,
        error: (any Error)?
    ) {
        Task { @MainActor [weak owner] in
            owner?.updateCheckDidFinish(error: error)
        }
    }
}
