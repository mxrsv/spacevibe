import AppKit
import SwiftUI

/// Headless screenshots (`SPACEVIBE_SHOT_DIR=<dir>`). Renders views with `ImageRenderer`: no window is created, no
/// focus is taken and no Screen Recording permission is needed. Then the process exits.
///
/// `SPACEVIBE_SHOT_SCREEN` selects shell, skills, subagents, hooks, rules, activity, limits, settings or glance.
/// With `SPACEVIBE_REDESIGN=1` the keys that draw the window draw the redesign's frame instead (`framePages`), `shell` adds
/// the redesign's specimens, and `gallery` draws only those (`frameGalleryParts`). `activity` with `SPACEVIBE_SHOT_STATE`
/// draws that page's states from synthetic data (`ActivityShotState`).
/// Real-screen runs require SPACEVIBE_TEST=1 and a synthetic home. Settings uses demo data. Glance draws in-memory reports
/// only, and still runs under the test guard: in the app the widget is fed by the core.
@MainActor
enum ShotRenderer {
    static let size = CGSize(width: 1440, height: 900)
    static let scale: CGFloat = 2

    static func run(into directory: URL) {
        NSApplication.shared.setActivationPolicy(.prohibited)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let environment = ProcessInfo.processInfo.environment
            let screen = environment[CoreEnvironment.variable("SHOT_SCREEN")] ?? "shell"
            if LaunchMode.surface(environment: environment) == .redesign {
                if screen == frameSettingsScreen {
                    try writeSettingsWindow(into: directory)
                    exit(0)
                }
                if screen == frameGalleryScreen {
                    try writeFrameGalleries(into: directory)
                    exit(0)
                }
                // Hooks draws each of its page states from in-memory data (RB-R3, `HooksFrameShots`).
                if screen == FramePage.hooks.rawValue {
                    try requireSyntheticHome(environment)
                    try HooksFrameShots.run(into: directory)
                    exit(0)
                }
                if let state = environment[CoreEnvironment.variable("SHOT_STATE")], screen == FramePage.activity.rawValue {
                    try requireSyntheticHome(environment)
                    try writeActivityStates(state, into: directory)
                    exit(0)
                }
                if let pages = framePages(forScreen: screen) {
                    try requireSyntheticHome(environment)
                    try writeFrame(on: pages, into: directory)
                    // Limits adds its page in every state from synthetic readings (RB-R6).
                    if screen == FramePage.limits.rawValue { try LimitsFrameShots.run(into: directory) }
                    // As the v5 `shell` run adds its gallery, the frame's adds the design system and the blocks.
                    if screen == "shell" { try writeFrameGalleries(into: directory) }
                    exit(0)
                }
            }
            switch screen {
            case "shell":
                try requireSyntheticHome(environment)
                try ShellShots.run(into: directory, tab: nil)
                try writeGalleries(into: directory)
            case "skills": try requireSyntheticHome(environment); try SkillsShots.run(into: directory)
            case "subagents": try requireSyntheticHome(environment); try SubagentsShots.run(into: directory)
            case "hooks": try requireSyntheticHome(environment); try HooksShots.run(into: directory)
            case "rules": try requireSyntheticHome(environment); try RulesTabShots.run(into: directory)
            case "activity": try requireSyntheticHome(environment); try ActivityTabShots.run(into: directory)
            case "limits": try requireSyntheticHome(environment); try LimitsShots.run(into: directory)
            case "settings": try SettingsShots.run(into: directory)
            case "glance":
                try requireSyntheticHome(environment)
                // With the switch on the widget draws the redesign's surface and text tokens (RD34).
                try GlanceShots.run(into: directory, tokens: .forSurface(LaunchMode.surface(environment: environment)))
            default: throw ShotHarness.Failure("unknown SPACEVIBE_SHOT_SCREEN \(screen) (shell, skills, subagents, hooks, rules, activity, limits, settings or glance)")
            }

        } catch {
            FileHandle.standardError.write(Data("shot mode failed: \(error.localizedDescription)\n".utf8))
            exit(1)
        }
        exit(0)
    }

    /// With the switch on, `settings` draws the redesign's Settings window (AR8), not the v5 overlay.
    nonisolated static let frameSettingsScreen = "settings"

    /// The pages a shot key draws in the redesign's frame: `shell` every page, a page's own key (`FramePage.rawValue`, so
    /// `inbox` and `clean` too) that page. Nil for `settings` (its own window, `frameSettingsScreen`), a key that does not
    /// draw the window (`glance`: the widget keeps its run) or an unknown key, which the v5 run then answers.
    nonisolated static func framePages(forScreen screen: String) -> [FramePage]? {
        if screen == "shell" { return FramePage.allCases }
        return FramePage(rawValue: screen).map { [$0] }
    }

    /// Both looks are drawn (DS-R8): Glass is the system material, which this renderer may not draw.
    nonisolated static let frameLooks: [MaterialLook] = [.glass, .solid]

    /// `frame-<page>-<look>-<appearance>.png` for each page, in both looks and appearances.
    private static func writeFrame(on pages: [FramePage], into directory: URL) throws {
        for choice in [AppearanceChoice.dark, .light] {
            for look in frameLooks {
                for page in pages {
                    let view = ShotHarness.frame(on: page, look: look, choice: choice, env: AppEnvironment.shared)
                    try write(view, name: "frame-\(page.rawValue)-\(look)", choice: choice, to: directory)
                }
            }
        }
    }

    /// Activity's states (RD-R13) from synthetic data (`ActivityShotState`): `SPACEVIBE_SHOT_STATE=<state>` or `all`, drawn as
    /// `frame-activity-<state>-<look>-<appearance>.png`.
    private static func writeActivityStates(_ key: String, into directory: URL) throws {
        guard key == "all" || ActivityShotState(rawValue: key) != nil else {
            throw ShotHarness.Failure("unknown SPACEVIBE_SHOT_STATE \(key) (all, \(ActivityShotState.allCases.map(\.rawValue).joined(separator: ", ")))")
        }
        let states = ActivityShotState(rawValue: key).map { [$0] } ?? ActivityShotState.allCases
        for choice in [AppearanceChoice.dark, .light] {
            for look in frameLooks {
                for state in states {
                    let toasts = ToastCenter(announce: false)
                    if let toast = state.toast { toasts.show(toast.message, tone: toast.tone) }
                    let preview = state.preview()
                    let view = ShotHarness.frame(
                        on: .activity, look: look, choice: choice, env: AppEnvironment.shared,
                        content: { page, model in page == .activity ? ActivityPage.content(model, preview: preview) : .region(page, model: model) },
                        sidebarValues: state.sidebarValues(), toasts: toasts)
                    try write(view, name: "frame-activity-\(state.rawValue)-\(look)", choice: choice, to: directory)
                }
            }
        }
    }

    /// `settings-window-<look>-<appearance>.png`. It reads no config, so it needs no synthetic home.
    private static func writeSettingsWindow(into directory: URL) throws {
        for choice in [AppearanceChoice.dark, .light] {
            for look in frameLooks {
                let view = ShotHarness.settingsWindow(look: look, choice: choice, env: AppEnvironment.shared)
                try write(view, name: "settings-window-\(look)", choice: choice, to: directory, fullHeight: true)
            }
        }
    }

    /// With the switch on, `gallery` draws only the redesign's specimens (`frameGalleryParts`); `shell` draws them after the
    /// pages.
    nonisolated static let frameGalleryScreen = "gallery"

    /// The redesign's gallery parts and their shot names: the Tokens + base specimen (RB-S1, beside `mock.html?page=tokens`)
    /// and the blocks in every state (RB-S4), split to stay under the image height limit.
    nonisolated static let frameGalleryParts: [(part: ComponentGalleryContent.Part, name: String)] = [
        (.designSystem, "design-system"), (.frameBlocks, "frame-blocks"), (.frameOverlays, "frame-overlays"),
    ]

    /// `<part>-<look>-<appearance>.png` for each redesign part, in both looks (DS-R8) and appearances. Specimens hold
    /// synthetic data only, so no synthetic home is needed.
    private static func writeFrameGalleries(into directory: URL) throws {
        for choice in [AppearanceChoice.dark, .light] {
            for look in frameLooks {
                for item in frameGalleryParts {
                    try write(gallery(choice, part: item.part).frameLookRoot(forced: look), name: "\(item.name)-\(look)", choice: choice,
                              to: directory, fullHeight: true)
                }
            }
        }
    }

    /// The real screens read config folders, so they run only where the core refuses a root under the real home.
    private static func requireSyntheticHome(_ environment: [String: String]) throws {
        guard environment[CoreEnvironment.variable("TEST")] == "1" else {
            throw ShotHarness.Failure("real-screen shots need SPACEVIBE_TEST=1 and a synthetic home")
        }
    }

    /// The gallery without the demo shell states: what the v5 `shell` run adds to the v5 window's own shots.
    private static func writeGalleries(into directory: URL) throws {
        for choice in [AppearanceChoice.dark, .light] {
            try write(gallery(choice, part: .first), name: "gallery", choice: choice, to: directory, fullHeight: true)
            try write(gallery(choice, part: .second), name: "gallery-more", choice: choice, to: directory, fullHeight: true)
            try writeV5Galleries(choice, into: directory)
        }
    }

    private static func writeV5Galleries(_ choice: AppearanceChoice, into directory: URL) throws {
        try write(gallery(choice, part: .third), name: "gallery-v5", choice: choice, to: directory, fullHeight: true)
        try write(gallery(choice, part: .fourth), name: "gallery-controls", choice: choice, to: directory, fullHeight: true)
        try write(gallery(choice, part: .fifth), name: "gallery-pane", choice: choice, to: directory, fullHeight: true)
    }

    private static func gallery(_ choice: AppearanceChoice, part: ComponentGalleryContent.Part) -> some View {
        let shell = ShellModel(tabs: DemoTabs.make(), appearance: AppearanceStore(forced: choice))
        return VStack(alignment: .leading, spacing: 0) {
            Text("Component gallery")
                .spaceVibeText(.cardTitle)
                .padding(.horizontal, Space.s24)
                .padding(.top, 20)
                .padding(.bottom, 4)
            ComponentGalleryContent(part: part)
        }
        .frame(width: size.width, alignment: .topLeading)
        .overlayHost()
        .background(Palette.bgApp)
        .spaceVibeRoot(shell: shell, toasts: ToastCenter(announce: false))
    }

    static func write<V: View>(_ view: V, name: String, choice: AppearanceChoice, to directory: URL, fullHeight: Bool = false) throws {
        let renderer = ImageRenderer(content: view
            .environment(\.colorScheme, choice.colorScheme)
            .environment(\.isShotRendering, true))
        renderer.scale = scale
        if fullHeight { renderer.proposedSize = ProposedViewSize(width: size.width, height: nil) }
        // A taller image renders blank without an error (the 16384 px texture limit), so it is refused here: split the content.
        guard let image = renderer.cgImage, image.height <= maxImageHeight,
              let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            throw ShotError.renderFailed(name)
        }
        let url = directory.appendingPathComponent("\(name)-\(choice.rawValue).png")
        try png.write(to: url)
        print(url.path)
    }

    /// A view that floats over other apps (the glance widget) at its own size, on the app's ground with room around it, so its
    /// edge reads in both appearances.
    static func writeFloating<V: View>(_ view: V, name: String, choice: AppearanceChoice, to directory: URL) throws {
        try write(view.padding(Space.s24).background(Palette.bgApp), name: name, choice: choice, to: directory)
    }

    private static let maxImageHeight = 16384

    private enum ShotError: LocalizedError {
        case renderFailed(String)
        var errorDescription: String? {
            if case .renderFailed(let name) = self { return "could not render \(name) (a shot taller than 16384 px renders blank: split it)" }
            return nil
        }
    }
}
