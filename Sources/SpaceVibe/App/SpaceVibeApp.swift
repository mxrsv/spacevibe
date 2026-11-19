import SwiftUI

struct SpaceVibeApp: App {
    /// The id of the main `Window` scene, which the app delegate reopens from the Dock.
    static let mainWindowID = "main"

    /// Keeps the app running after the main window closes and reopens it from the Dock (GW17).
    @NSApplicationDelegateAdaptor(SpaceVibeAppDelegate.self) private var appDelegate
    @State private var shell: ShellModel
    @State private var env = AppEnvironment.shared
    private let mode = LaunchMode.current()

    init() {
        // The app's own store applies the theme to `NSApp.appearance` and the font size to every text role.
        _shell = State(initialValue: ShellModel(tabs: TabRegistry.makeTabs(), appearance: AppearanceStore(live: true)))
        AppEnvironment.shared.updates.start(mode: mode)
    }

    var body: some Scene {
        Window(SpaceVibeMark.productName, id: Self.mainWindowID) {
            Group {
                if case .gallery = mode {
                    ComponentGalleryWindow()
                } else {
                    AppShell()
                }
            }
            .spaceVibeRoot(shell: shell, toasts: env.toasts, env: env)
            .linksMainWindow(to: appDelegate)
            .frame(minWidth: 960, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .windowBackgroundDragBehavior(.enabled)
        .defaultSize(width: 1180, height: 760)
        .commands {
            ShellCommands(shell: shell)
            // The standard About panel, with the licences the app must show (Credits).
            CommandGroup(replacing: .appInfo) {
                Button("About \(SpaceVibeMark.productName)") { Credits.showAboutPanel() }
                Button("Check for Updates\u{2026}") { env.updates.checkForUpdates() }
            }
        }
    }
}
