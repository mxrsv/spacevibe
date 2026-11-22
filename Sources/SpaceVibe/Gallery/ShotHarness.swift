import Foundation
import SwiftUI

/// What the real-screen shot runs (`LoadoutShots`, `RulesShots`, `ActivityShots`) share: one failure type, one `check` that
/// prints `ok: ...`, one `wait` that spins the main run loop (`ImageRenderer` draws one frame and runs no `.task`, so the
/// reads and writes a shot needs only land while something spins it), and the shell that holds the screen under test.
@MainActor
enum ShotHarness {
    struct Failure: LocalizedError {
        let errorDescription: String?
        init(_ what: String) { errorDescription = what }
    }

    /// One deadline for every `wait`: CI runners are slow.
    nonisolated static let waitSeconds: TimeInterval = 60
    /// For the engine reads (the Loadout settle, the Activity read), which scan whole histories.
    nonisolated static let settleSeconds: TimeInterval = 120
    private static let spinSeconds: TimeInterval = 0.05

    static func check(_ condition: Bool, _ what: String) throws {
        guard condition else { throw Failure("check failed: \(what)") }
        print("ok: \(what)")
    }

    static func wait(_ what: String, seconds: TimeInterval = waitSeconds, until done: () -> Bool) throws {
        let deadline = Date().addingTimeInterval(seconds)
        while !done(), Date() < deadline {
            RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(spinSeconds))
        }
        guard done() else { throw Failure("\(what) did not finish in \(Int(seconds)) s") }
    }

    /// The registry's shell with `tab` standing in for the tab of the same id, and that tab active.
    static func shell(around tab: any SpaceVibeTab, choice: AppearanceChoice) -> ShellModel {
        let tabs: [any SpaceVibeTab] = TabRegistry.makeTabs().map { $0.id == tab.id ? tab : $0 }
        return ShellModel(tabs: tabs, appearance: AppearanceStore(forced: choice), activeID: tab.id)
    }

    /// The shell as one 1440x900 frame, with the services of `env` (and its toasts) in the environment.
    static func view(_ shell: ShellModel, env: AppEnvironment) -> some View {
        AppShell()
            .spaceVibeRoot(shell: shell, toasts: env.toasts, env: env)
            .frame(width: ShotRenderer.size.width, height: ShotRenderer.size.height)
    }

    /// The redesign's frame on `page` in `look` as one 1440x900 frame (`SPACEVIBE_REDESIGN=1`), with the services of `env`
    /// in the environment. The demo tabs only fill `spaceVibeRoot`'s shell slot: the frame does not read them.
    /// A page state shot passes its own `content`, the matching `sidebarValues` and the `toasts` it has shown.
    static func frame(on page: FramePage, look: MaterialLook, choice: AppearanceChoice, env: AppEnvironment,
                      content: AppFrame.PageContent? = nil, sidebarValues: FrameSidebarValues? = nil,
                      toasts: ToastCenter? = nil, width: CGFloat = ShotRenderer.size.width) -> some View {
        AppFrame(page: page, env: env, look: look, sidebarValues: sidebarValues,
                 content: content ?? { page, model in .region(page, model: model) })
            .spaceVibeRoot(shell: ShellModel(tabs: DemoTabs.make(), appearance: AppearanceStore(forced: choice)),
                           toasts: toasts ?? ToastCenter(announce: false), env: env)
            .frame(width: width, height: ShotRenderer.size.height)
    }
}
