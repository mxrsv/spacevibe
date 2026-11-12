import Foundation

/// How this process was started, decided once from the environment.
///
/// - `SPACEVIBE_GALLERY=1`: opens the component gallery instead of the shell.
/// - `SPACEVIBE_SHOT_DIR=<dir>`: writes PNGs of the shell and the gallery into `<dir>` without opening a window, then exits.
///
/// Both modes are honoured only in a development build: a distribution build always starts `.normal`.
enum LaunchMode {
    case normal
    case gallery
    case shots(directory: URL)

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

    /// Gallery and screenshot entry points are available only in development builds.
    static var isDevelopmentBuild: Bool {
        #if DEBUG || SPACEVIBE_DEVELOPMENT_TOOLS
        true
        #else
        false
        #endif
    }
}
