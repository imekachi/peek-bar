import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore

    init(settings: SettingsStore) {
        _settings = ObservedObject(wrappedValue: settings)
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

                Text(
                    "Adds a second separator so you can ⌘-drag icons past it to keep them permanently hidden."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            } header: {
                Text("Menu Bar")
            }

            Section("Updates") {
                Toggle("Automatically check for updates", isOn: $settings.automaticallyCheckForUpdates)

                LabeledContent("Version", value: versionString)

                // Disabled until spec 0007 implements update checking.
                Button("Check for Updates…") { }
                    .buttonStyle(.bordered)
                    .disabled(true)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 480, minHeight: 340)
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
