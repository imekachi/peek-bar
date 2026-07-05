import XCTest
@testable import PeekBar

@MainActor
final class UpdateEntryPointTests: XCTestCase {
    private var suiteName: String!
    private var suite: UserDefaults!
    private var settings: SettingsStore!
    private var manualChecker: ManualUpdateCheckSpy!

    override func setUp() async throws {
        try await super.setUp()
        suiteName = "UpdateEntryPointTests.\(UUID().uuidString)"
        suite = UserDefaults(suiteName: suiteName)!
        suite.removePersistentDomain(forName: suiteName)
        settings = SettingsStore(userDefaults: suite)
        manualChecker = ManualUpdateCheckSpy()
    }

    override func tearDown() async throws {
        manualChecker = nil
        settings = nil
        suite.removePersistentDomain(forName: suiteName)
        suite = nil
        suiteName = nil
        try await super.tearDown()
    }

    func testSettingsCheckForUpdatesUsesSharedManualChecker() {
        let view = SettingsView(settings: settings, manualUpdateChecker: manualChecker)

        view.performManualUpdateCheck()

        XCTAssertEqual(manualChecker.checkManuallyCallCount, 1)
    }

    func testContextMenuCheckForUpdatesIsEnabledAndWiredToSharedChecker() {
        let settingsPresenter = StubSettingsPresenter()
        let menuBundle = StatusItemMenu.makeMenu(
            settingsPresenter: settingsPresenter,
            manualUpdateChecker: manualChecker
        )

        let updateItem = menuBundle.menu.items.first { $0.title == "Check for updates…" }
        XCTAssertNotNil(updateItem)
        XCTAssertTrue(updateItem?.isEnabled == true)
        XCTAssertEqual(updateItem?.action, NSSelectorFromString("checkForUpdates:"))
        XCTAssertIdentical(updateItem?.target as AnyObject?, menuBundle.target)
    }

    func testUpdateControllerSatisfiesManualUpdateChecking() {
        let checker = MockUpdateChecker()
        let controller = UpdateController(
            settings: settings,
            checker: checker,
            scheduler: MockPeriodicScheduler()
        )

        controller.checkManually()

        XCTAssertEqual(checker.checkCallCount, 1)
        XCTAssertEqual(checker.lastUserInitiated, true)
    }
}

@MainActor
private final class ManualUpdateCheckSpy: NSObject, ManualUpdateChecking {
    private(set) var checkManuallyCallCount = 0

    func checkManually() {
        checkManuallyCallCount += 1
    }
}

@MainActor
private final class StubSettingsPresenter: NSObject, SettingsPresenting {
    func show() {}
}

@MainActor
private final class MockUpdateChecker: UpdateChecking {
    weak var delegate: UpdateCheckDelegate?

    private(set) var checkCallCount = 0
    private(set) var lastUserInitiated: Bool?
    private(set) var isSessionInProgress = false

    func start() throws {}

    func checkForUpdates(userInitiated: Bool) {
        checkCallCount += 1
        lastUserInitiated = userInitiated
    }
}

@MainActor
private final class MockPeriodicScheduler: PeriodicTimerScheduling {
    func schedule(interval: TimeInterval, handler: @escaping @MainActor () -> Void) {}

    func cancel() {}
}
