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
            Section {
                LabeledContent("Version", value: versionString)
            } header: {
                Text("PeekBar")
            }

            Section("General") {}

            Section("Menu Bar") {}

            Section("Updates") {}
        }
        .formStyle(.grouped)
        .frame(minWidth: 480, minHeight: 340)
    }
}
