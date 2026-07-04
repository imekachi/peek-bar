import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    private static let contentSize = NSSize(width: 480, height: 340)

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
            let window = NSWindow(
                contentRect: NSRect(origin: .zero, size: Self.contentSize),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "Settings"
            window.contentViewController = hostingController
            window.center()
            window.setFrameAutosaveName("PeekBarSettingsWindow")
            self.window = window
        }

        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        StartupLog.emit("PeekBar: settings opened")
    }
}
