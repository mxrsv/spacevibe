import AppKit
import SwiftUI

/// The AppKit side of the app's lifecycle (spec `docs/specs/2026-11-19-session-glance-widget.md`, GW17, GW-R9). A lone SwiftUI
/// `Window` scene quits the app when it closes; here the app keeps running with its Dock icon, so the glance widget stays.
/// A Dock click brings the main window back. Cmd-Q still quits, and quitting removes the widget with the process.
@MainActor
final class SpaceVibeAppDelegate: NSObject, NSApplicationDelegate {
    /// Opens the main `Window` scene, or brings it to the front when it is open. Set by the window's content from SwiftUI's
    /// `openWindow` (`linksMainWindow(to:)`); the action stays valid after that window closes.
    var openMainWindow: (() -> Void)?

    /// Starts the glance widget once, in a normal launch only (`GlanceController.runs`). It belongs to the process, not to the
    /// main window, so it stays after the window closes.
    func applicationDidFinishLaunching(_ notification: Notification) {
        GlanceController.shared.start(mode: LaunchMode.current()) { [weak self] in self?.openMainWindow?() }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    /// The `hasVisibleWindows` flag is not used: the widget's panel is a visible window too, so it would stay true with the
    /// main window closed. Opening a `Window` scene that is already open only brings it forward, so the call is always safe.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard let openMainWindow else { return true }
        openMainWindow()
        return false
    }
}

extension View {
    /// Hands this window's `openWindow` action to `delegate`, so a Dock click can reopen the main window after it closed.
    func linksMainWindow(to delegate: SpaceVibeAppDelegate) -> some View {
        modifier(MainWindowLink(delegate: delegate))
    }
}

private struct MainWindowLink: ViewModifier {
    let delegate: SpaceVibeAppDelegate
    @Environment(\.openWindow) private var openWindow

    func body(content: Content) -> some View {
        content.onAppear {
            let open = openWindow
            delegate.openMainWindow = { open(id: SpaceVibeApp.mainWindowID) }
        }
    }
}
