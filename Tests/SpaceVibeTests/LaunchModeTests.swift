import Foundation
import Testing
@testable import SpaceVibe

/// Gallery and shot entry points remain development-only after the UI cut-over.
@Suite("Development launch modes")
struct LaunchModeTests {
    @Test("the gallery and shot modes need a development build")
    func modesNeedDevelopmentBuild() {
        let gallery = ["SPACEVIBE_GALLERY": "1"]
        let shots = ["SPACEVIBE_SHOT_DIR": "/tmp/shots"]
        for environment in [gallery, shots, gallery.merging(shots) { $1 }] {
            guard case .normal = LaunchMode.current(environment: environment, isDevelopmentBuild: false) else {
                Issue.record("a distribution build must start normal: \(environment)")
                return
            }
        }
        guard case .gallery = LaunchMode.current(environment: gallery, isDevelopmentBuild: true) else {
            Issue.record("the gallery variable must open the gallery in a development build")
            return
        }
        guard case .shots(let directory) = LaunchMode.current(environment: shots, isDevelopmentBuild: true) else {
            Issue.record("the shot variable must pick the shots mode in a development build")
            return
        }
        #expect(directory.path == "/tmp/shots")
    }

    private static let redesign = ["SPACEVIBE_REDESIGN": "1"]

    @Test("SPACEVIBE_REDESIGN=1 in a development build picks the redesign, beside every launch mode")
    func redesignSwitchOn() {
        let modes: [[String: String]] = [[:], ["SPACEVIBE_GALLERY": "1"], ["SPACEVIBE_SHOT_DIR": "/tmp/shots"]]
        for base in modes {
            let environment = base.merging(Self.redesign) { $1 }
            #expect(LaunchMode.surface(environment: environment, isDevelopmentBuild: true) == .redesign, "\(environment)")
            // The switch is orthogonal: it never changes which mode starts.
            let withSwitch = LaunchMode.current(environment: environment, isDevelopmentBuild: true)
            let without = LaunchMode.current(environment: base, isDevelopmentBuild: true)
            #expect(withSwitch == without, "\(environment)")
        }
    }

    @Test("an unset, empty or other SPACEVIBE_REDESIGN value keeps the v5 window", arguments: [nil, "", "0", "true", "yes", " 1", "2"])
    func redesignSwitchOff(value: String?) {
        let environment = value.map { ["SPACEVIBE_REDESIGN": $0] } ?? [:]
        #expect(LaunchMode.surface(environment: environment, isDevelopmentBuild: true) == .v5)
    }

    @Test("a distribution build ignores SPACEVIBE_REDESIGN")
    func distributionIgnoresRedesign() {
        #expect(LaunchMode.surface(environment: Self.redesign, isDevelopmentBuild: false) == .v5)
        let everything = Self.redesign.merging(["SPACEVIBE_GALLERY": "1", "SPACEVIBE_SHOT_DIR": "/tmp/shots"]) { $1 }
        #expect(LaunchMode.surface(environment: everything, isDevelopmentBuild: false) == .v5)
        guard case .normal = LaunchMode.current(environment: everything, isDevelopmentBuild: false) else {
            Issue.record("a distribution build must start normal")
            return
        }
    }

    @Test("the frame's pages follow the sidebar order, which is the ⌘1 to ⌘8 order of RD39")
    func framePageOrder() {
        #expect(FramePage.allCases.map(\.title) == ["Inbox", "Clean", "Skills", "Subagents", "Hooks", "Rules", "Limits", "Activity"])
    }

    @Test("with the switch on, the window's shot keys draw the frame in both looks; glance keeps its run; settings draws the Settings window")
    @MainActor
    func frameShotKeys() {
        #expect(ShotRenderer.framePages(forScreen: "shell") == FramePage.allCases)
        for page in FramePage.allCases {
            #expect(ShotRenderer.framePages(forScreen: page.rawValue) == [page])
        }
        #expect(ShotRenderer.framePages(forScreen: "glance") == nil)
        #expect(ShotRenderer.framePages(forScreen: "unknown") == nil)
        #expect(ShotRenderer.framePages(forScreen: "settings") == nil)
        #expect(ShotRenderer.frameSettingsScreen == "settings")
        #expect(ShotRenderer.frameLooks == [.glass, .solid])
        // `gallery` draws the redesign's specimens (RB-V2 shoots them), never a page.
        #expect(ShotRenderer.framePages(forScreen: ShotRenderer.frameGalleryScreen) == nil)
        #expect(ShotRenderer.frameGalleryParts.map(\.name) == ["design-system", "frame-blocks", "frame-overlays"])
    }

    @Test("a debug build counts as a development build")
    func debugBuildIsDevelopment() {
        #if DEBUG
        #expect(LaunchMode.isDevelopmentBuild)
        #endif
    }

    private static let checkout = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func script(_ name: String) throws -> String {
        try String(contentsOf: Self.checkout.appendingPathComponent("scripts/\(name)"), encoding: .utf8)
    }

    /// H9: the compile flag may sit on the development branch of `build-app.sh` only, and the release script must keep
    /// building with `--distribution`.
    @Test("build-app.sh adds the dev flag only outside --distribution; release.sh builds with --distribution")
    func buildFlagStaysOutOfDistribution() throws {
        let flag = "-DSPACEVIBE_DEVELOPMENT_TOOLS"
        let flagLines = try script("build-app.sh").split(separator: "\n").filter { $0.contains(flag) }
        #expect(flagLines.count == 1, "the flag must be set in one place")
        #expect(flagLines.first.map { $0.trimmingCharacters(in: .whitespaces).hasPrefix("\"\")") } == true,
                "the flag must be set on the no-argument (development) branch only")
        #expect(try script("release.sh").contains("scripts/build-app.sh\" --distribution"))
        #expect(!(try script("release.sh").contains(flag)))
    }
}
