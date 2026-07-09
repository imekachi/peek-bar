import Combine

/// Bridges the `launchAtLogin` toggle in `SettingsStore` to the OS login-item registration,
/// keeping both in sync and resyncing to the OS's actual state if registration fails.
@MainActor
final class LaunchAtLoginController {
    private let settings: SettingsStore
    private let loginItem: LoginItemManaging
    private var toggleObservation: AnyCancellable?
    private var isApplying = false

    init(settings: SettingsStore, loginItem: LoginItemManaging) {
        self.settings = settings
        self.loginItem = loginItem
    }

    /// Applies the initial login-item state, then begins observing further toggle changes.
    ///
    /// On first launch the settings default (on) is honored by registering the login item.
    /// On later launches the toggle is instead reconciled to whatever the OS reports, since
    /// the user may have removed the login item outside the app (e.g. System Settings).
    ///
    /// Subscribing only after this initial step — and dropping the subscription's current
    /// value with `.dropFirst()` — means this step's own write never retriggers a
    /// register/unregister call.
    func start(isFirstLaunch: Bool) {
        if isFirstLaunch {
            apply(settings.launchAtLogin)
        } else {
            reconcile()
        }

        toggleObservation = settings.launchAtLoginChanges
            .prepend(settings.launchAtLogin) // seed removeDuplicates with current value
            .removeDuplicates()
            .dropFirst()
            .sink { [weak self] enabled in
                self?.apply(enabled)
            }
    }

    /// Pulls the OS's actual login-item state into the toggle.
    func reconcile() {
        settings.launchAtLogin = loginItem.isEnabled
    }

    private func apply(_ enabled: Bool) {
        guard !isApplying else { return }
        isApplying = true
        defer { isApplying = false }

        do {
            if enabled {
                try loginItem.enable()
            } else {
                try loginItem.disable()
            }
        } catch {
            StartupLog.emit(
                "PeekBar: failed to \(enabled ? "enable" : "disable") launch at login — \(error.localizedDescription)"
            )
            reconcile()
        }
    }
}
