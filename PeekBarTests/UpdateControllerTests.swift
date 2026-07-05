import XCTest
@testable import PeekBar

@MainActor
final class UpdateControllerTests: XCTestCase {
    private var suiteName: String!
    private var suite: UserDefaults!
    private var settings: SettingsStore!
    private var checker: MockUpdateChecker!
    private var scheduler: MockPeriodicScheduler!
    private var controller: UpdateController!

    override func setUp() async throws {
        try await super.setUp()
        suiteName = "UpdateControllerTests.\(UUID().uuidString)"
        suite = UserDefaults(suiteName: suiteName)!
        suite.removePersistentDomain(forName: suiteName)
        settings = SettingsStore(userDefaults: suite)
        checker = MockUpdateChecker()
        scheduler = MockPeriodicScheduler()
        controller = UpdateController(
            settings: settings,
            checker: checker,
            scheduler: scheduler
        )
    }

    override func tearDown() async throws {
        controller = nil
        scheduler = nil
        checker = nil
        settings = nil
        suite.removePersistentDomain(forName: suiteName)
        suite = nil
        suiteName = nil
        try await super.tearDown()
    }

    func testLaunchCheckRunsWhenAutomaticChecksAreEnabled() {
        settings.automaticallyCheckForUpdates = true

        controller.start()

        XCTAssertEqual(checker.checkCallCount, 1)
        XCTAssertEqual(checker.lastUserInitiated, false)
        XCTAssertTrue(scheduler.isScheduled)
        XCTAssertEqual(scheduler.lastInterval, UpdateController.periodicCheckInterval)
    }

    func testLaunchCheckSkippedWhenAutomaticChecksAreDisabled() {
        settings.automaticallyCheckForUpdates = false

        controller.start()

        XCTAssertEqual(checker.checkCallCount, 0)
        XCTAssertFalse(scheduler.isScheduled)
    }

    func testPeriodicCheckHonorsAutomaticSetting() {
        settings.automaticallyCheckForUpdates = true
        controller.start()
        checker.completeActiveCheck()

        scheduler.fire()

        XCTAssertEqual(checker.checkCallCount, 2)
        XCTAssertEqual(checker.lastUserInitiated, false)
    }

    func testPeriodicCheckSkippedWhenAutomaticChecksAreDisabled() {
        settings.automaticallyCheckForUpdates = true
        controller.start()
        checker.completeActiveCheck()

        settings.automaticallyCheckForUpdates = false
        scheduler.fire()

        XCTAssertEqual(checker.checkCallCount, 1)
    }

    func testManualCheckWorksWhenAutomaticChecksAreDisabled() {
        settings.automaticallyCheckForUpdates = false
        controller.start()

        controller.checkManually()

        XCTAssertEqual(checker.checkCallCount, 1)
        XCTAssertEqual(checker.lastUserInitiated, true)
    }

    func testManualCheckRefreshesPeriodicTimer() {
        settings.automaticallyCheckForUpdates = true
        controller.start()
        checker.completeActiveCheck()

        let scheduleCountBeforeManual = scheduler.scheduleCallCount

        controller.checkManually()
        checker.completeActiveCheck()

        XCTAssertGreaterThan(scheduler.scheduleCallCount, scheduleCountBeforeManual)
        XCTAssertTrue(scheduler.isScheduled)
        XCTAssertEqual(scheduler.lastInterval, UpdateController.periodicCheckInterval)
    }

    func testConcurrentTriggersDedupeIntoSharedState() {
        settings.automaticallyCheckForUpdates = true
        controller.start()

        XCTAssertEqual(controller.status, .checking)
        XCTAssertEqual(checker.checkCallCount, 1)

        controller.checkAutomatically(reason: .periodic)
        controller.checkManually()

        XCTAssertEqual(checker.checkCallCount, 1)
        XCTAssertEqual(controller.status, .checking)
    }

    func testFailedAutomaticCheckRefreshesTimerWithoutSurfacingError() {
        settings.automaticallyCheckForUpdates = true
        controller.start()

        checker.completeActiveCheck(error: MockUpdateError.network)

        XCTAssertEqual(controller.status, .idle)
        XCTAssertTrue(scheduler.isScheduled)
        XCTAssertEqual(scheduler.lastInterval, UpdateController.periodicCheckInterval)
    }

    func testFailedManualCheckRecordsFailureStatus() {
        settings.automaticallyCheckForUpdates = false
        controller.start()

        controller.checkManually()
        checker.completeActiveCheck(error: MockUpdateError.network)

        XCTAssertEqual(controller.status, .failed)
    }

    func testDisablingAutomaticChecksCancelsPeriodicTimer() {
        settings.automaticallyCheckForUpdates = true
        controller.start()
        checker.completeActiveCheck()
        XCTAssertTrue(scheduler.isScheduled)

        settings.automaticallyCheckForUpdates = false

        XCTAssertFalse(scheduler.isScheduled)
    }

    func testEnablingAutomaticChecksSchedulesPeriodicTimer() {
        settings.automaticallyCheckForUpdates = false
        controller.start()
        XCTAssertFalse(scheduler.isScheduled)

        settings.automaticallyCheckForUpdates = true

        XCTAssertTrue(scheduler.isScheduled)
        XCTAssertEqual(scheduler.lastInterval, UpdateController.periodicCheckInterval)
    }
}

// MARK: - Test doubles

@MainActor
private final class MockUpdateChecker: UpdateChecking {
    weak var delegate: UpdateCheckDelegate?

    private(set) var checkCallCount = 0
    private(set) var lastUserInitiated: Bool?
    private(set) var isSessionInProgress = false

    func start() throws {}

    func checkForUpdates(userInitiated: Bool) {
        guard !isSessionInProgress else {
            return
        }
        checkCallCount += 1
        lastUserInitiated = userInitiated
        isSessionInProgress = true
    }

    func completeActiveCheck(foundUpdate: Bool = false, error: Error? = nil) {
        guard isSessionInProgress else {
            return
        }
        isSessionInProgress = false

        if foundUpdate {
            delegate?.updateCheckDidFindValidUpdate()
        }
        delegate?.updateCheckDidFinish(error: error)
    }
}

@MainActor
private final class MockPeriodicScheduler: PeriodicTimerScheduling {
    private(set) var scheduleCallCount = 0
    private(set) var lastInterval: TimeInterval?
    private(set) var isScheduled = false
    private var handler: (() -> Void)?

    func schedule(interval: TimeInterval, handler: @escaping @MainActor () -> Void) {
        scheduleCallCount += 1
        lastInterval = interval
        isScheduled = true
        self.handler = handler
    }

    func cancel() {
        isScheduled = false
        handler = nil
    }

    func fire() {
        handler?()
    }
}

private enum MockUpdateError: LocalizedError {
    case network

    var errorDescription: String? {
        switch self {
        case .network: "network unavailable"
        }
    }
}
