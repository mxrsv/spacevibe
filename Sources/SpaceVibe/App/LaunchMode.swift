import Foundation

/// How this process was started, decided once from the environment.
///
/// - `SPACEVIBE_GALLERY=1`: opens the component gallery instead of the shell.
/// - `SPACEVIBE_SHOT_DIR=<dir>`: writes PNGs of the shell and the gallery into `<dir>` without opening a window, then exits.
/// - `SPACEVIBE_REDESIGN=1`: the window draws the redesign's frame (`AppFrame`) instead of the v5 `AppShell`. This is not a
///   mode of its own but a `Surface` beside the mode: the gallery and the shot run still start, and read `surface` to know
///   which window they show.
///
/// All three are honoured only in a development build: a distribution build always starts `.normal` on `.v5`.
enum LaunchMode: Equatable {
    case normal
    case gallery
    case shots(directory: URL)

    /// Which window root the shell draws: the shipped v5 window, or the redesign being built behind the dev switch
    /// (plan `docs/plans/2026-11-21-spacevibe-redesign-build.md`, "FE-P9 shape").
    enum Surface: Equatable {
        case v5
        case redesign
    }

    static func current(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        isDevelopmentBuild: Bool = LaunchMode.isDevelopmentBuild
    ) -> LaunchMode {
        guard isDevelopmentBuild else { return .normal }
        if let path = environment[CoreEnvironment.variable("SHOT_DIR")], !path.isEmpty {
            return .shots(directory: URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true))
        }
        if environment[CoreEnvironment.variable("GALLERY")] == "1" { return .gallery }
        return .normal
    }

    /// `.redesign` only for `SPACEVIBE_REDESIGN=1` in a development build; any other value, or none, is `.v5`.
    static func surface(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        isDevelopmentBuild: Bool = LaunchMode.isDevelopmentBuild
    ) -> Surface {
        guard isDevelopmentBuild, environment[CoreEnvironment.variable("REDESIGN")] == "1" else { return .v5 }
        return .redesign
    }

    /// Gallery, screenshot and redesign entry points are available only in development builds.
    static var isDevelopmentBuild: Bool {
        #if DEBUG || SPACEVIBE_DEVELOPMENT_TOOLS
        true
        #else
        false
        #endif
    }
}
