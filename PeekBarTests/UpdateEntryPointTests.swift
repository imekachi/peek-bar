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
