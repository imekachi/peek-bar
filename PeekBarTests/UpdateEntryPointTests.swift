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
            settings: settings,
            settingsPresenter: settingsPresenter,
            manualUpdateChecker: manualChecker
        )

        let updateItem = menuBundle.menu.items.first { $0.title == "Check for updates…" }
        XCTAssertNotNil(updateItem)
        XCTAssertTrue(updateItem?.isEnabled == true)
        XCTAssertEqual(updateItem?.action, NSSelectorFromString("checkForUpdates:"))
        XCTAssertIdentical(updateItem?.target as AnyObject?, menuBundle.target)
    }

    func testContextMenuAlwaysHiddenActionIsHiddenWhenFeatureIsDisabled() {
        settings.alwaysHiddenEnabled = false
        let menuBundle = StatusItemMenu.makeMenu(
            settings: settings,
            settingsPresenter: StubSettingsPresenter(),
            manualUpdateChecker: manualChecker
        )

        menuBundle.menu.delegate?.menuWillOpen?(menuBundle.menu)

        let alwaysHiddenItem = menuBundle.menu.items.first {
            $0.title == "Show Always Hidden Icons" || $0.title == "Hide Always Hidden Icons"
        }
        XCTAssertNotNil(alwaysHiddenItem)
        XCTAssertTrue(alwaysHiddenItem?.isHidden == true)
    }

    func testContextMenuShowsHideAfterAlwaysHiddenIsEnabled() throws {
        settings.isAlwaysHiddenRevealed = false
        settings.alwaysHiddenEnabled = true
        let menuBundle = StatusItemMenu.makeMenu(
            settings: settings,
            settingsPresenter: StubSettingsPresenter(),
            manualUpdateChecker: manualChecker
        )

        menuBundle.menu.delegate?.menuWillOpen?(menuBundle.menu)

        let alwaysHiddenItem = try XCTUnwrap(menuBundle.menu.items.first {
            $0.title == "Show Always Hidden Icons" || $0.title == "Hide Always Hidden Icons"
        })
        XCTAssertFalse(alwaysHiddenItem.isHidden)
        XCTAssertEqual(alwaysHiddenItem.title, "Hide Always Hidden Icons")
    }

    func testContextMenuAlwaysHiddenActionTogglesRevealStateAndLabel() throws {
        settings.alwaysHiddenEnabled = true
        settings.isAlwaysHiddenRevealed = false
        let menuBundle = StatusItemMenu.makeMenu(
            settings: settings,
            settingsPresenter: StubSettingsPresenter(),
            manualUpdateChecker: manualChecker
        )

        menuBundle.menu.delegate?.menuWillOpen?(menuBundle.menu)

        let alwaysHiddenItem = try XCTUnwrap(menuBundle.menu.items.first {
            $0.title == "Show Always Hidden Icons" || $0.title == "Hide Always Hidden Icons"
        })
        XCTAssertFalse(alwaysHiddenItem.isHidden)
        XCTAssertEqual(alwaysHiddenItem.title, "Show Always Hidden Icons")
        XCTAssertEqual(alwaysHiddenItem.action, NSSelectorFromString("toggleAlwaysHidden:"))
        XCTAssertIdentical(alwaysHiddenItem.target as AnyObject?, menuBundle.target)

        let target = try XCTUnwrap(alwaysHiddenItem.target as? NSObject)
        let action = try XCTUnwrap(alwaysHiddenItem.action)
        target.perform(action, with: alwaysHiddenItem)

        XCTAssertTrue(settings.isAlwaysHiddenRevealed)
        XCTAssertEqual(alwaysHiddenItem.title, "Hide Always Hidden Icons")

        target.perform(action, with: alwaysHiddenItem)

        XCTAssertFalse(settings.isAlwaysHiddenRevealed)
        XCTAssertEqual(alwaysHiddenItem.title, "Show Always Hidden Icons")
    }

    func testContextMenuRevealAlwaysHiddenCanExpandNormalCollapseForTruthfulState() throws {
        settings.alwaysHiddenEnabled = true
        settings.isAlwaysHiddenRevealed = false
        settings.isCollapsed = true
        var expandCallCount = 0
        let menuBundle = StatusItemMenu.makeMenu(
            settings: settings,
            revealAlwaysHidden: { [settings] in
                guard let settings else { return }
                AlwaysHiddenVisibilityState.reveal(settings: settings) {
                    XCTAssertFalse(settings.isAlwaysHiddenRevealed)
                    expandCallCount += 1
                    settings.isCollapsed = false
                }
            },
            settingsPresenter: StubSettingsPresenter(),
            manualUpdateChecker: manualChecker
        )

        menuBundle.menu.delegate?.menuWillOpen?(menuBundle.menu)

        let alwaysHiddenItem = try XCTUnwrap(menuBundle.menu.items.first {
            $0.title == "Show Always Hidden Icons" || $0.title == "Hide Always Hidden Icons"
        })
        let target = try XCTUnwrap(alwaysHiddenItem.target as? NSObject)
        let action = try XCTUnwrap(alwaysHiddenItem.action)
        target.perform(action, with: alwaysHiddenItem)

        XCTAssertEqual(expandCallCount, 1)
        XCTAssertFalse(settings.isCollapsed)
        XCTAssertTrue(settings.isAlwaysHiddenRevealed)
        XCTAssertEqual(alwaysHiddenItem.title, "Hide Always Hidden Icons")
    }

    func testNormalCollapseMarksAlwaysHiddenAsHiddenForTruthfulMenuState() {
        settings.alwaysHiddenEnabled = true
        settings.isAlwaysHiddenRevealed = true

        AlwaysHiddenVisibilityState.markHiddenByNormalCollapse(settings: settings)

        XCTAssertFalse(settings.isAlwaysHiddenRevealed)
        let menuBundle = StatusItemMenu.makeMenu(
            settings: settings,
            settingsPresenter: StubSettingsPresenter(),
            manualUpdateChecker: manualChecker
        )
        menuBundle.menu.delegate?.menuWillOpen?(menuBundle.menu)

        let alwaysHiddenItem = menuBundle.menu.items.first {
            $0.title == "Show Always Hidden Icons" || $0.title == "Hide Always Hidden Icons"
        }
        XCTAssertEqual(alwaysHiddenItem?.title, "Show Always Hidden Icons")
    }

    func testRefusedSecondaryHideDuringNormalCollapseDoesNotRestoreRevealedMenuState() throws {
        settings.alwaysHiddenEnabled = true
        settings.isAlwaysHiddenRevealed = true
        settings.isCollapsed = true
        let menuBundle = StatusItemMenu.makeMenu(
            settings: settings,
            hideAlwaysHidden: { [settings] in
                guard let settings else { return }
                settings.isAlwaysHiddenRevealed = false
                AlwaysHiddenVisibilityState.restoreRevealAfterRefusedHideIfVisible(settings: settings)
            },
            settingsPresenter: StubSettingsPresenter(),
            manualUpdateChecker: manualChecker
        )

        menuBundle.menu.delegate?.menuWillOpen?(menuBundle.menu)

        let alwaysHiddenItem = try XCTUnwrap(menuBundle.menu.items.first {
            $0.title == "Show Always Hidden Icons" || $0.title == "Hide Always Hidden Icons"
        })
        XCTAssertEqual(alwaysHiddenItem.title, "Hide Always Hidden Icons")

        let target = try XCTUnwrap(alwaysHiddenItem.target as? NSObject)
        let action = try XCTUnwrap(alwaysHiddenItem.action)
        target.perform(action, with: alwaysHiddenItem)

        XCTAssertFalse(settings.isAlwaysHiddenRevealed)
        XCTAssertEqual(alwaysHiddenItem.title, "Show Always Hidden Icons")
    }

    func testStatusBarControllerShowsSecondaryAndAppliesRevealWhenFeatureEnabled() {
        var secondaryVisibilityChanges: [Bool] = []
        var alwaysHiddenApplyCalls: [Bool] = []
        settings.alwaysHiddenEnabled = true

        StatusBarController.applyAlwaysHiddenStateForTesting(
            settings: settings,
            setSecondarySeparatorVisible: { secondaryVisibilityChanges.append($0) },
            applyAlwaysHiddenStrategy: {
                alwaysHiddenApplyCalls.append($0)
                return true
            },
            expandNormalCollapse: { XCTFail("Enable-to-revealed should not expand an already expanded bar") }
        )

        XCTAssertTrue(settings.isAlwaysHiddenRevealed)
        XCTAssertEqual(secondaryVisibilityChanges.last, true)
        XCTAssertEqual(alwaysHiddenApplyCalls.last, false)
    }

    func testStatusBarControllerNormalCollapseKeepsAlwaysHiddenHiddenWhenSecondaryHideRefuses() {
        var secondaryVisibilityChanges: [Bool] = []
        var alwaysHiddenApplyCalls: [Bool] = []
        settings.alwaysHiddenEnabled = true
        XCTAssertTrue(settings.isAlwaysHiddenRevealed)

        settings.isCollapsed = true
        AlwaysHiddenVisibilityState.markHiddenByNormalCollapse(settings: settings)
        StatusBarController.applyAlwaysHiddenStateForTesting(
            settings: settings,
            setSecondarySeparatorVisible: { secondaryVisibilityChanges.append($0) },
            applyAlwaysHiddenStrategy: {
                alwaysHiddenApplyCalls.append($0)
                return false
            },
            expandNormalCollapse: { XCTFail("Hidden always-hidden state should not expand normal collapse") }
        )

        XCTAssertTrue(settings.isCollapsed)
        XCTAssertFalse(settings.isAlwaysHiddenRevealed)
        XCTAssertEqual(secondaryVisibilityChanges.last, true)
        XCTAssertEqual(alwaysHiddenApplyCalls.last, true)
    }

    func testAutoCollapseSchedulesConfiguredIntervalOnExpand() {
        let scheduler = MockAutoCollapseScheduler()
        let controller = AutoCollapseTimerController(scheduler: scheduler)
        var collapseCallCount = 0

        controller.expand(interval: .s15) {
            collapseCallCount += 1
        }

        XCTAssertTrue(scheduler.isScheduled)
        XCTAssertEqual(scheduler.lastInterval, 15)

        scheduler.fire()

        XCTAssertEqual(collapseCallCount, 1)
    }

    func testAutoCollapseOffDoesNotScheduleOnExpand() {
        let scheduler = MockAutoCollapseScheduler()
        let controller = AutoCollapseTimerController(scheduler: scheduler)

        controller.expand(interval: .off) {
            XCTFail("Off should not schedule auto-collapse")
        }

        XCTAssertFalse(scheduler.isScheduled)
        XCTAssertEqual(scheduler.scheduleCallCount, 0)
    }

    func testManualCollapseCancelsPendingAutoCollapse() {
        let scheduler = MockAutoCollapseScheduler()
        let controller = AutoCollapseTimerController(scheduler: scheduler)
        var collapseCallCount = 0

        controller.expand(interval: .s30) {
            collapseCallCount += 1
        }
        controller.collapse()
        scheduler.fire()

        XCTAssertFalse(scheduler.isScheduled)
        XCTAssertEqual(scheduler.cancelCallCount, 2)
        XCTAssertEqual(collapseCallCount, 0)
    }

    func testIntervalChangeWhileCollapsedAppliesOnNextExpand() {
        let scheduler = MockAutoCollapseScheduler()
        let controller = AutoCollapseTimerController(scheduler: scheduler)

        controller.intervalDidChange(to: .s60, isExpanded: false) {}

        XCTAssertFalse(scheduler.isScheduled)
        XCTAssertEqual(scheduler.scheduleCallCount, 0)

        controller.expand(interval: .s60) {}

        XCTAssertTrue(scheduler.isScheduled)
        XCTAssertEqual(scheduler.lastInterval, 60)
        XCTAssertEqual(scheduler.scheduleCallCount, 1)
    }

    func testIntervalChangeWhileExpandedSchedulesNewCountdown() {
        let scheduler = MockAutoCollapseScheduler()
        let controller = AutoCollapseTimerController(scheduler: scheduler)
        var collapseCallCount = 0

        controller.intervalDidChange(to: .s10, isExpanded: true) {
            collapseCallCount += 1
        }

        XCTAssertTrue(scheduler.isScheduled)
        XCTAssertEqual(scheduler.lastInterval, 10)
        scheduler.fire()
        XCTAssertEqual(collapseCallCount, 1)
    }

    func testIntervalChangeWhileExpandedRestartsCountdown() {
        let scheduler = MockAutoCollapseScheduler()
        let controller = AutoCollapseTimerController(scheduler: scheduler)
        var firstCollapseCallCount = 0
        var secondCollapseCallCount = 0

        controller.expand(interval: .s10) {
            firstCollapseCallCount += 1
        }
        controller.intervalDidChange(to: .s60, isExpanded: true) {
            secondCollapseCallCount += 1
        }

        XCTAssertTrue(scheduler.isScheduled)
        XCTAssertEqual(scheduler.lastInterval, 60)
        XCTAssertEqual(scheduler.scheduleCallCount, 2)

        scheduler.fire()

        XCTAssertEqual(firstCollapseCallCount, 0)
        XCTAssertEqual(secondCollapseCallCount, 1)
    }

    func testSelectingOffCancelsPendingAutoCollapse() {
        let scheduler = MockAutoCollapseScheduler()
        let controller = AutoCollapseTimerController(scheduler: scheduler)
        var collapseCallCount = 0

        controller.expand(interval: .s10) {
            collapseCallCount += 1
        }
        controller.intervalDidChange(to: .off, isExpanded: true) {
            collapseCallCount += 1
        }
        scheduler.fire()

        XCTAssertFalse(scheduler.isScheduled)
        XCTAssertEqual(collapseCallCount, 0)
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

@MainActor
private final class MockAutoCollapseScheduler: AutoCollapseTimerScheduling {
    private var handler: (@MainActor () -> Void)?

    private(set) var isScheduled = false
    private(set) var lastInterval: TimeInterval?
    private(set) var scheduleCallCount = 0
    private(set) var cancelCallCount = 0

    func schedule(interval: TimeInterval, handler: @escaping @MainActor () -> Void) {
        isScheduled = true
        lastInterval = interval
        scheduleCallCount += 1
        self.handler = handler
    }

    func cancel() {
        isScheduled = false
        handler = nil
        cancelCallCount += 1
    }

    func fire() {
        guard let handler else { return }
        isScheduled = false
        self.handler = nil
        handler()
    }
}
