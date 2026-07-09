import Combine
import Foundation

/// Typed facade over `UserDefaults` for app state PeekBar persists itself.
@MainActor
final class SettingsStore: ObservableObject {
    enum StatusItemAutosaveName {
        static let toggleItem = "PeekBarToggleItem"
        static let separatorItem = "PeekBarSeparatorItem"
        static let secondarySeparatorItem = "PeekBarSecondarySeparatorItem"
    }

    enum AutoCollapseInterval: Int, CaseIterable {
        case off = 0, s10 = 1, s15 = 2, s30 = 3, s60 = 4

        var duration: TimeInterval? {
            switch self {
            case .off: nil
            case .s10: 10
            case .s15: 15
            case .s30: 30
            case .s60: 60
            }
        }
    }

    private enum Key {
        static let hasLaunchedBefore = "peekbar.hasLaunchedBefore"
        static let isCollapsed = "peekbar.isCollapsed"
        static let launchAtLogin = "peekbar.launchAtLogin"
        static let autoCollapseInterval = "peekbar.autoCollapseInterval"
        static let alwaysHiddenEnabled = "peekbar.alwaysHiddenEnabled"
        static let isAlwaysHiddenRevealed = "peekbar.isAlwaysHiddenRevealed"
        static let automaticallyCheckForUpdates = "peekbar.automaticallyCheckForUpdates"
    }

    private let userDefaults: UserDefaults

    /// Whether the app has completed a prior launch; used to auto-open Settings once.
    @Published var hasLaunchedBefore: Bool {
        didSet { userDefaults.set(hasLaunchedBefore, forKey: Key.hasLaunchedBefore) }
    }

    /// Current collapse state (`false` = expanded / `›`, the default).
    @Published var isCollapsed: Bool {
        didSet { userDefaults.set(isCollapsed, forKey: Key.isCollapsed) }
    }

    @Published var launchAtLogin: Bool {
        didSet {
            userDefaults.set(launchAtLogin, forKey: Key.launchAtLogin)
            launchAtLoginChanges.send(launchAtLogin)
        }
    }

    /// Fires in `didSet` timing (after the backing store is updated), unlike `$launchAtLogin`
    /// which publishes in `willSet` timing. Used by `LaunchAtLoginController` so its
    /// error-path resync (a re-entrant write from within the observation) becomes the final
    /// stored value instead of being clobbered by the outer write completing afterwards.
    let launchAtLoginChanges = PassthroughSubject<Bool, Never>()

    @Published var autoCollapseInterval: AutoCollapseInterval {
        didSet { userDefaults.set(autoCollapseInterval.rawValue, forKey: Key.autoCollapseInterval) }
    }

    @Published var alwaysHiddenEnabled: Bool {
        didSet {
            userDefaults.set(alwaysHiddenEnabled, forKey: Key.alwaysHiddenEnabled)
            if alwaysHiddenEnabled && !oldValue {
                isAlwaysHiddenRevealed = true
            }
        }
    }

    @Published var isAlwaysHiddenRevealed: Bool {
        didSet { userDefaults.set(isAlwaysHiddenRevealed, forKey: Key.isAlwaysHiddenRevealed) }
    }

    @Published var automaticallyCheckForUpdates: Bool {
        didSet { userDefaults.set(automaticallyCheckForUpdates, forKey: Key.automaticallyCheckForUpdates) }
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        userDefaults.register(defaults: [
            Key.launchAtLogin: true,
            Key.automaticallyCheckForUpdates: true,
        ])
        hasLaunchedBefore = userDefaults.bool(forKey: Key.hasLaunchedBefore)
        isCollapsed = userDefaults.bool(forKey: Key.isCollapsed)
        launchAtLogin = userDefaults.bool(forKey: Key.launchAtLogin)
        autoCollapseInterval = AutoCollapseInterval(
            rawValue: userDefaults.integer(forKey: Key.autoCollapseInterval)
        ) ?? .off
        alwaysHiddenEnabled = userDefaults.bool(forKey: Key.alwaysHiddenEnabled)
        isAlwaysHiddenRevealed = userDefaults.bool(forKey: Key.isAlwaysHiddenRevealed)
        automaticallyCheckForUpdates = userDefaults.bool(forKey: Key.automaticallyCheckForUpdates)
    }
}
