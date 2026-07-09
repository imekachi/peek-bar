import XCTest
@testable import PeekBar

@MainActor
final class LaunchAtLoginControllerTests: XCTestCase {
    private var suiteName: String!
    private var suite: UserDefaults!
    private var settings: SettingsStore!
    private var loginItem: MockLoginItem!
    private var controller: LaunchAtLoginController!

    override func setUp() async throws {
        try await super.setUp()
        suiteName = "LaunchAtLoginControllerTests.\(UUID().uuidString)"
        suite = UserDefaults(suiteName: suiteName)!
        suite.removePersistentDomain(forName: suiteName)
        settings = SettingsStore(userDefaults: suite)
        loginItem = MockLoginItem()
        controller = LaunchAtLoginController(settings: settings, loginItem: loginItem)
    }

    override func tearDown() async throws {
        controller = nil
        loginItem = nil
        settings = nil
        suite.removePersistentDomain(forName: suiteName)
        suite = nil
        suiteName = nil
        try await super.tearDown()
    }

    func testFirstLaunchRegistersLoginItem() {
        // Default settings value is `true` (default-on); first launch should honor it.
        controller.start(isFirstLaunch: true)

        XCTAssertEqual(loginItem.enableCallCount, 1)
        XCTAssertEqual(loginItem.disableCallCount, 0)
    }

    func testTogglingOnCallsEnable() {
        loginItem.isEnabled = false
        controller.start(isFirstLaunch: false)

        settings.launchAtLogin = true

        XCTAssertEqual(loginItem.enableCallCount, 1)
        XCTAssertEqual(loginItem.disableCallCount, 0)
    }

    func testTogglingOffCallsDisable() {
        loginItem.isEnabled = true
        controller.start(isFirstLaunch: false)

        settings.launchAtLogin = false

        XCTAssertEqual(loginItem.disableCallCount, 1)
        XCTAssertEqual(loginItem.enableCallCount, 0)
    }

    func testReconcilePullsOSStateIntoSettings() {
        settings.launchAtLogin = true
        loginItem.isEnabled = false // OS disagrees, e.g. removed via System Settings.

        controller.reconcile()

        XCTAssertFalse(settings.launchAtLogin)
    }

    func testEnableFailureResyncsToggleToActualState() {
        loginItem.isEnabled = false
        controller.start(isFirstLaunch: false)
        loginItem.shouldThrowOnEnable = true

        settings.launchAtLogin = true

        XCTAssertFalse(settings.launchAtLogin)
        XCTAssertEqual(settings.launchAtLogin, loginItem.isEnabled)
    }

    func testDisableFailureResyncsToggleToActualState() {
        loginItem.isEnabled = true
        controller.start(isFirstLaunch: false)
        loginItem.shouldThrowOnDisable = true

        settings.launchAtLogin = false

        XCTAssertTrue(settings.launchAtLogin)
        XCTAssertEqual(settings.launchAtLogin, loginItem.isEnabled)
    }

    func testSettingToggleToCurrentValueDoesNotReinvokeLoginItem() {
        loginItem.isEnabled = true
        settings.launchAtLogin = true
        controller.start(isFirstLaunch: false)

        settings.launchAtLogin = true // Unchanged value; removeDuplicates should suppress it.

        XCTAssertEqual(loginItem.enableCallCount, 0)
        XCTAssertEqual(loginItem.disableCallCount, 0)
    }
}

// MARK: - Test doubles

@MainActor
private final class MockLoginItem: LoginItemManaging {
    var isEnabled = false
    var shouldThrowOnEnable = false
    var shouldThrowOnDisable = false
    private(set) var enableCallCount = 0
    private(set) var disableCallCount = 0

    func enable() throws {
        enableCallCount += 1
        if shouldThrowOnEnable {
            throw MockLoginItemError.enableFailed
        }
        isEnabled = true
    }

    func disable() throws {
        disableCallCount += 1
        if shouldThrowOnDisable {
            throw MockLoginItemError.disableFailed
        }
        isEnabled = false
    }
}

private enum MockLoginItemError: LocalizedError {
    case enableFailed
    case disableFailed

    var errorDescription: String? {
        switch self {
        case .enableFailed: "enable failed"
        case .disableFailed: "disable failed"
        }
    }
}
