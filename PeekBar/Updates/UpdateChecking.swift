import Foundation

enum UpdateAutomaticReason: Equatable, Sendable {
    case launch
    case periodic
}

enum UpdateCheckStatus: Equatable, Sendable {
    case idle
    case checking
    case upToDate
    case updateAvailable
    /// Recorded for manual checks; automatic failures stay quiet and return to idle.
    case failed
}

/// Manual update entry points (Settings button, context menu) call through this surface.
@MainActor
protocol ManualUpdateChecking: AnyObject {
    func checkManually()
}

/// Abstraction over Sparkle update checks so tests can run without network access.
@MainActor
protocol UpdateChecking: AnyObject {
    var isSessionInProgress: Bool { get }
    var delegate: UpdateCheckDelegate? { get set }

    func start() throws
    func checkForUpdates(userInitiated: Bool)
}

@MainActor
protocol UpdateCheckDelegate: AnyObject {
    func updateCheckDidFindValidUpdate()
    func updateCheckDidFinish(error: Error?)
}

/// Schedules the shared 6-hour automatic check window.
@MainActor
protocol PeriodicTimerScheduling: AnyObject {
    func schedule(interval: TimeInterval, handler: @escaping @MainActor () -> Void)
    func cancel()
}

@MainActor
final class SystemPeriodicTimerScheduler: PeriodicTimerScheduling {
    private var timer: Timer?

    func schedule(interval: TimeInterval, handler: @escaping @MainActor () -> Void) {
        cancel()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
            Task { @MainActor in
                handler()
            }
        }
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
    }
}
