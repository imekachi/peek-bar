import Foundation

/// Typed facade over `UserDefaults` for app state PeekBar persists itself.
struct SettingsStore {
    enum StatusItemAutosaveName {
        static let toggleItem = "PeekBarToggleItem"
        static let separatorItem = "PeekBarSeparatorItem"
    }

    private enum Key {
        static let hasLaunchedBefore = "peekbar.hasLaunchedBefore"
        static let isCollapsed = "peekbar.isCollapsed"
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    /// Whether the app has completed a prior launch; used to auto-open Preferences once.
    var hasLaunchedBefore: Bool {
        get { userDefaults.bool(forKey: Key.hasLaunchedBefore) }
        nonmutating set { userDefaults.set(newValue, forKey: Key.hasLaunchedBefore) }
    }

    /// Current collapse state (`false` = expanded / `›`, the default).
    var isCollapsed: Bool {
        get { userDefaults.bool(forKey: Key.isCollapsed) }
        nonmutating set { userDefaults.set(newValue, forKey: Key.isCollapsed) }
    }
}
