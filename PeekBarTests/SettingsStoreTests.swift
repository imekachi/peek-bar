import XCTest
@testable import PeekBar

final class SettingsStoreTests: XCTestCase {
    private var suiteName: String!
    private var suite: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "SettingsStoreTests.\(UUID().uuidString)"
        suite = UserDefaults(suiteName: suiteName)!
        suite.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        suite.removePersistentDomain(forName: suiteName)
        suite = nil
        suiteName = nil
        super.tearDown()
    }

    @MainActor
    func testDefaultsWhenKeysAreAbsent() {
        let store = SettingsStore(userDefaults: suite)

        XCTAssertTrue(store.launchAtLogin)
        XCTAssertEqual(store.autoCollapseInterval, .off)
        XCTAssertFalse(store.alwaysHiddenEnabled)
        XCTAssertTrue(store.automaticallyCheckForUpdates)
        XCTAssertFalse(store.isCollapsed)
        XCTAssertFalse(store.hasLaunchedBefore)
    }

    @MainActor
    func testRoundTripPersistence() {
        let store = SettingsStore(userDefaults: suite)
        store.launchAtLogin = false
        store.autoCollapseInterval = .s30
        store.alwaysHiddenEnabled = true
        store.automaticallyCheckForUpdates = false
        store.isCollapsed = true
        store.hasLaunchedBefore = true

        let reloaded = SettingsStore(userDefaults: suite)

        XCTAssertFalse(reloaded.launchAtLogin)
        XCTAssertEqual(reloaded.autoCollapseInterval, .s30)
        XCTAssertTrue(reloaded.alwaysHiddenEnabled)
        XCTAssertFalse(reloaded.automaticallyCheckForUpdates)
        XCTAssertTrue(reloaded.isCollapsed)
        XCTAssertTrue(reloaded.hasLaunchedBefore)
    }
}
