import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    private let manualUpdateChecker: ManualUpdateChecking

    init(settings: SettingsStore, manualUpdateChecker: ManualUpdateChecking) {
        _settings = ObservedObject(wrappedValue: settings)
        self.manualUpdateChecker = manualUpdateChecker
    }

    func performManualUpdateCheck() {
        manualUpdateChecker.checkManually()
    }

    private var versionString: String {
        let short =
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        guard
            let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
            !build.isEmpty
        else {
            return short
        }
        return "\(short) (\(build))"
    }

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
                    .help("Start PeekBar automatically when you log in.")
            }

            Section {
                Picker("Auto-collapse", selection: $settings.autoCollapseInterval) {
                    ForEach(SettingsStore.AutoCollapseInterval.allCases, id: \.self) { interval in
                        Text(interval.label).tag(interval)
                    }
                }
                .pickerStyle(.menu)

                Toggle("Enable always-hidden section", isOn: $settings.alwaysHiddenEnabled)
            } header: {
                Text("Menu Bar")
            } footer: {
                Text(
                    "Adds a second separator so you can ⌘-drag icons past it to keep them permanently hidden."
                )
            }

            Section("Updates") {
                Toggle("Automatically check for updates", isOn: $settings.automaticallyCheckForUpdates)

                LabeledContent("Version", value: versionString)

                Button("Check for Updates…", action: performManualUpdateCheck)
                    .buttonStyle(.bordered)
            }
        }
        .formStyle(.grouped)
        // Fix a native settings width and let height follow content, so the window can size to
        // fit every section (no scrolling, nothing clipped), as System Settings panes do.
        .frame(width: 500)
    }
}

private extension SettingsStore.AutoCollapseInterval {
    var label: String {
        switch self {
        case .off: "Off"
        case .s10: "10 seconds"
        case .s15: "15 seconds"
        case .s30: "30 seconds"
        case .s60: "1 minute"
        }
    }
}
