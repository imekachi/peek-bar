import Foundation
import Sparkle

/// Forwards Sparkle delegate callbacks onto the main-actor `UpdateController`.
final class SparkleUpdateDelegateBridge: NSObject, SPUUpdaterDelegate, SPUStandardUserDriverDelegate {
    weak var owner: UpdateController?

    private var pendingManualFeedCacheBust = false

    func updater(_ updater: SPUUpdater, mayPerform updateCheck: SPUUpdateCheck) throws {
        pendingManualFeedCacheBust = (updateCheck == .updates)
    }

    func feedParameters(
        for updater: SPUUpdater,
        sendingSystemProfile: Bool
    ) -> [[String: String]] {
        guard pendingManualFeedCacheBust else {
            return []
        }
        pendingManualFeedCacheBust = false

        let token = String(UInt64(Date().timeIntervalSince1970 * 1000))
        return [[
            "key": "peekbar_nocache",
            "value": token,
            "displayKey": "",
            "displayValue": "",
        ]]
    }

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
        pendingManualFeedCacheBust = false
        Task { @MainActor [weak owner] in
            owner?.updateCheckDidFinish(error: error)
        }
    }
}
