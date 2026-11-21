import SwiftUI

/// The shipped app: the v5 window (`AppShell`), its commands (`ShellCommands`) and its Settings overlay. `main.swift` starts
/// it whenever the redesign switch is off (`LaunchMode.Surface.v5`), which a distribution build always is.
struct SpaceVibeApp: App {
    /// The id of the main `Window` scene, which the app delegate reopens from the Dock.
    static let mainWindowID = "main"
    /// The scenes this app declares.
    static let sceneIDs = [mainWindowID]

    /// Keeps the app running after the main window closes and reopens it from the Dock (GW17).
    @NSApplicationDelegateAdaptor(SpaceVibeAppDelegate.self) private var appDelegate
    @State private var shell: ShellModel
    @State private var env = AppEnvironment.shared
    private let mode = LaunchMode.current()

    init() {
        _shell = State(initialValue: Self.boot(mode: mode))
    }

    /// What every launch starts before its first scene: the shell model with the app's appearance store, the update
    /// checker, and the glance widget's way back into the window (GW6).
    @MainActor
    static func boot(mode: LaunchMode) -> ShellModel {
        // The app's own store applies the theme to `NSApp.appearance` and the font size to every text role.
        let shell = ShellModel(tabs: TabRegistry.makeTabs(), appearance: AppearanceStore(live: true))
        AppEnvironment.shared.updates.start(mode: mode)
        // A click on the glance widget with no host app opens Activity in this shell (GW6); the app delegate starts the widget.
        GlanceController.shared.shell = shell
        return shell
    }

    /// The app to run for `surface`: `main.swift` calls `main()` on it, so the redesign's scenes and commands exist only with
    /// the switch on (plan AR8).
    static func app(for surface: LaunchMode.Surface) -> any App.Type {
        switch surface {
        case .v5: SpaceVibeApp.self
        case .redesign: SpaceVibeFrameApp.self
        }
    }

    var body: some Scene {
        MainWindowScene(appDelegate: appDelegate) {
            Group {
                if case .gallery = mode { ComponentGalleryWindow() } else { AppShell() }
            }
            .spaceVibeRoot(shell: shell, toasts: env.toasts, env: env)
        }
        .commands {
            ShellCommands(shell: shell)
            AppInfoCommands(updates: env.updates)
        }
    }
}

/// The redesign behind `SPACEVIBE_REDESIGN=1` in a development build (FE-P9): the frame (`AppFrame`), its own commands
/// (`FrameCommands`, which replace the v5 `ShellCommands`: no v5 ⌘1–⌘9), the separate Settings window (RD4, AR8) and the
/// Journal window it opens (RB-R8).
struct SpaceVibeFrameApp: App {
    /// The scenes this app declares: the main window and the Settings window.
    static let sceneIDs = [SpaceVibeApp.mainWindowID, SettingsWindowFrame.windowID, JournalWindow.windowID]

    @NSApplicationDelegateAdaptor(SpaceVibeAppDelegate.self) private var appDelegate
    @State private var shell: ShellModel
    @State private var env = AppEnvironment.shared
    private let mode = LaunchMode.current()

    init() {
        _shell = State(initialValue: SpaceVibeApp.boot(mode: mode))
    }

    var body: some Scene {
        MainWindowScene(appDelegate: appDelegate) {
            Group {
                if case .gallery = mode { ComponentGalleryWindow() } else { AppFrame(env: env) }
            }
            .spaceVibeRoot(shell: shell, toasts: env.toasts, env: env)
        }
        .commands {
            FrameCommands(toasts: env.toasts)
            AppInfoCommands(updates: env.updates)
        }
        Window("Settings", id: SettingsWindowFrame.windowID) {
            SettingsWindowFrame()
                .frameLookRoot()
                .spaceVibeRoot(shell: shell, toasts: env.toasts, env: env)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)
        // Opened from Settings… (⌘,) and the sidebar's foot, not listed in the Window menu.
        .commandsRemoved()
        // Settings › Data › Show Journal (RB-R8).
        Window("Journal", id: JournalWindow.windowID) {
            JournalWindow()
                .frameLookRoot()
                .spaceVibeRoot(shell: shell, toasts: env.toasts, env: env)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)
        .commandsRemoved()
    }
}

/// The main `Window` scene both apps share: presented at every launch, hidden title bar, draggable background.
private struct MainWindowScene<Content: View>: Scene {
    let appDelegate: SpaceVibeAppDelegate
    @ViewBuilder let content: () -> Content

    var body: some Scene {
        Window(SpaceVibeMark.productName, id: SpaceVibeApp.mainWindowID) {
            content()
                .linksMainWindow(to: appDelegate)
                .frame(minWidth: 960, minHeight: 600)
        }
        // Present the main window at every launch, also when it was closed at the last quit and nothing is restored: its
        // content sets the app delegate's `openMainWindow`, which the Dock click and the widget's fallback use (GW17).
        .defaultLaunchBehavior(.presented)
        .windowStyle(.hiddenTitleBar)
        .windowBackgroundDragBehavior(.enabled)
        .defaultSize(width: 1180, height: 760)
    }
}

/// The standard About panel, with the licences the app must show (Credits), and the update check.
private struct AppInfoCommands: Commands {
    let updates: UpdateController

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About \(SpaceVibeMark.productName)") { Credits.showAboutPanel() }
            Button("Check for Updates\u{2026}") { updates.checkForUpdates() }
        }
    }
}
