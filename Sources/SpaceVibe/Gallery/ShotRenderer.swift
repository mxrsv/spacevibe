import AppKit
import SwiftUI

/// Headless screenshots (`SPACEVIBE_SHOT_DIR=<dir>`). Renders views with `ImageRenderer`: no window is created, no
/// focus is taken and no Screen Recording permission is needed. Then the process exits.
///
/// `SPACEVIBE_SHOT_SCREEN` selects shell, skills, subagents, hooks, rules, activity, limits, settings or glance.
/// With `SPACEVIBE_REDESIGN=1` the keys that draw the window draw the redesign's frame instead (`framePages`).
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
            if LaunchMode.surface(environment: environment) == .redesign, let pages = try framePages(forScreen: screen) {
                try requireSyntheticHome(environment)
                try writeFrame(on: pages, into: directory)
                exit(0)
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
            case "glance": try requireSyntheticHome(environment); try GlanceShots.run(into: directory)
            default: throw ShotHarness.Failure("unknown SPACEVIBE_SHOT_SCREEN \(screen) (shell, skills, subagents, hooks, rules, activity, limits, settings or glance)")
            }

        } catch {
            FileHandle.standardError.write(Data("shot mode failed: \(error.localizedDescription)\n".utf8))
            exit(1)
        }
        exit(0)
    }

    /// The pages a shot key draws in the redesign's frame: `shell` every page, a page's own key (`FramePage.rawValue`, so
    /// `inbox` and `clean` too) that page. Nil for a key that does not draw the window (`glance`: the widget keeps its run)
    /// or is unknown, which the v5 run then answers. `settings` fails: the redesign's Settings is its own window (AR8) and is
    /// not built yet, and the v5 Settings overlay is not a redesign surface.
    nonisolated static func framePages(forScreen screen: String) throws -> [FramePage]? {
        if screen == "shell" { return FramePage.allCases }
        if screen == "settings" {
            throw ShotHarness.Failure("the redesign has no Settings window yet: unset SPACEVIBE_REDESIGN for the v5 Settings shots")
        }
        return FramePage(rawValue: screen).map { [$0] }
    }

    /// `frame-<page>-<appearance>.png` for each page, in both appearances.
    private static func writeFrame(on pages: [FramePage], into directory: URL) throws {
        for choice in [AppearanceChoice.dark, .light] {
            for page in pages {
                let view = ShotHarness.frame(on: page, choice: choice, env: AppEnvironment.shared)
                try write(view, name: "frame-\(page.rawValue)", choice: choice, to: directory)
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
