import AppKit
import SwiftUI

@MainActor
final class PreferencesWindowController: NSWindowController {
    private static let contentSize = NSSize(width: 480, height: 340)

    init() {
        super.init(window: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        if window == nil {
            let hostingController = NSHostingController(rootView: PreferencesView())
            let window = NSWindow(
                contentRect: NSRect(origin: .zero, size: Self.contentSize),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "PeekBar Settings"
            window.contentViewController = hostingController
            window.center()
            window.setFrameAutosaveName("PeekBarPreferencesWindow")
            self.window = window
        }

        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        StartupLog.emit("PeekBar: preferences opened")
    }
}
