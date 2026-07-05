import Combine
import Foundation

@MainActor
final class UpdateController: NSObject, UpdateCheckDelegate {
    static let periodicCheckInterval: TimeInterval = 6 * 60 * 60

    private(set) var status: UpdateCheckStatus = .idle

    private let settings: SettingsStore
    private let checker: UpdateChecking
    private let scheduler: PeriodicTimerScheduling
    private let sparkleBridge: SparkleUpdateDelegateBridge
    private var settingsObservation: AnyCancellable?
    private var activeCheckWasUserInitiated = false
    private var foundUpdateDuringActiveCheck = false

    init(
        settings: SettingsStore,
        checker: UpdateChecking,
        scheduler: PeriodicTimerScheduling = SystemPeriodicTimerScheduler(),
        sparkleBridge: SparkleUpdateDelegateBridge? = nil
    ) {
        self.settings = settings
        self.checker = checker
        self.scheduler = scheduler
        self.sparkleBridge = sparkleBridge ?? SparkleUpdateDelegateBridge()
        super.init()
        self.sparkleBridge.owner = self
        self.checker.delegate = self
    }

    convenience init(settings: SettingsStore) {
        let bridge = SparkleUpdateDelegateBridge()
        let checker = SparkleUpdateChecker(
            updaterDelegate: bridge,
            userDriverDelegate: bridge
        )
        self.init(
            settings: settings,
            checker: checker,
            scheduler: SystemPeriodicTimerScheduler(),
            sparkleBridge: bridge
        )
    }

    func start() {
        do {
            try checker.start()
        } catch {
            StartupLog.emit("PeekBar: failed to start update checker — \(error.localizedDescription)")
        }

        settingsObservation = settings.$automaticallyCheckForUpdates
            .removeDuplicates()
            .sink { [weak self] enabled in
                self?.setAutomaticChecksEnabled(enabled)
            }

        setAutomaticChecksEnabled(settings.automaticallyCheckForUpdates)

        if settings.automaticallyCheckForUpdates {
            checkAutomatically(reason: .launch)
        }
    }

    func checkAutomatically(reason: UpdateAutomaticReason) {
        guard settings.automaticallyCheckForUpdates else {
            return
        }
        performCheck(userInitiated: false, reason: reason)
    }

    func checkManually() {
        performCheck(userInitiated: true, reason: nil)
    }

    func setAutomaticChecksEnabled(_ enabled: Bool) {
        if enabled {
            scheduleNextPeriodicCheck()
        } else {
            scheduler.cancel()
        }
    }

    // MARK: - UpdateCheckDelegate

    func updateCheckDidFindValidUpdate() {
        foundUpdateDuringActiveCheck = true
    }

    func updateCheckDidFinish(error: Error?) {
        finishActiveCheck(error: error)
    }

    // MARK: - Private

    private func performCheck(userInitiated: Bool, reason: UpdateAutomaticReason?) {
        guard !checker.isSessionInProgress else {
            return
        }

        activeCheckWasUserInitiated = userInitiated
        foundUpdateDuringActiveCheck = false
        status = .checking

        if !userInitiated, let reason {
            StartupLog.emit("PeekBar: automatic update check (\(reason.logLabel))")
        }

        checker.checkForUpdates(userInitiated: userInitiated)
    }

    private func refreshPeriodicTimer() {
        guard settings.automaticallyCheckForUpdates else {
            return
        }
        scheduleNextPeriodicCheck()
    }

    private func scheduleNextPeriodicCheck() {
        scheduler.schedule(interval: Self.periodicCheckInterval) { [weak self] in
            self?.checkAutomatically(reason: .periodic)
            self?.scheduleNextPeriodicCheck()
        }
    }

    private func finishActiveCheck(error: Error?) {
        defer {
            activeCheckWasUserInitiated = false
            foundUpdateDuringActiveCheck = false
            refreshPeriodicTimer()
        }

        if let error, !Self.isBenignUpdateOutcome(error) {
            if activeCheckWasUserInitiated {
                status = .failed
            } else {
                StartupLog.emit(
                    "PeekBar: automatic update check failed — \(error.localizedDescription)"
                )
                status = .idle
            }
            return
        }

        if foundUpdateDuringActiveCheck {
            status = .updateAvailable
        } else {
            status = .upToDate
        }
    }

    private static func isBenignUpdateOutcome(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == "SUSparkleErrorDomain" && nsError.code == 1001
    }
}

extension UpdateController: ManualUpdateChecking {}

private extension UpdateAutomaticReason {
    var logLabel: String {
        switch self {
        case .launch: "launch"
        case .periodic: "periodic"
        }
    }
}
