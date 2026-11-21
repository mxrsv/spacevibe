import Foundation

// Entry point. The screenshot mode has to run before SwiftUI creates a window, so `SpaceVibeApp` is not `@main`. The
// redesign switch picks the app type, so its scenes and commands exist only with the switch on (plan AR8).
switch LaunchMode.current() {
case .shots(let directory):
    MainActor.assumeIsolated { ShotRenderer.run(into: directory) }
case .normal, .gallery:
    SpaceVibeApp.app(for: LaunchMode.surface()).main()
}
