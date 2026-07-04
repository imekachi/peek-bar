import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    private let settings: SettingsStore

    init(settings: SettingsStore) {
        self.settings = settings
        super.init(window: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        if window == nil {
            let hostingController = NSHostingController(rootView: SettingsView(settings: settings))
            // Drive the window size from the SwiftUI content's fitting size so every section is
            // visible without scrolling, the way System Settings panes fit their content. A frame
            // autosave name is intentionally omitted: a stale saved height would re-clip content.
            hostingController.sizingOptions = [.preferredContentSize]

            let window = NSWindow(contentViewController: hostingController)
            window.styleMask = [.titled, .closable]
            window.title = "Settings"
            window.center()
            self.window = window
        }

        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        StartupLog.emit("PeekBar: settings opened")
    }
}
