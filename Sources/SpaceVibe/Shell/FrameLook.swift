import SwiftUI

extension MaterialLook {
    /// Glass only where the system material exists (macOS 26) and Reduce Transparency is off; Solid otherwise (DS-R8,
    /// RB-T0 (d)). Pure, so the rule is tested without either OS.
    static func decide(glassAvailable: Bool, reduceTransparency: Bool) -> MaterialLook {
        glassAvailable && !reduceTransparency ? .glass : .solid
    }
}

extension View {
    /// The frame's one platform decision (plan AR8): which material the window uses, put into `\.frameMaterial` for every
    /// view below. Applied once at each window root of the redesign (the main window, the Settings window). `forced` pins a
    /// look for a screenshot; Glass can only be forced where the system draws it.
    func frameLookRoot(forced: MaterialLook? = nil) -> some View {
        modifier(FrameLookRoot(forced: forced))
    }
}

private struct FrameLookRoot: ViewModifier {
    let forced: MaterialLook?
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        content.environment(\.frameMaterial, material)
    }

    /// The only `#available` the frame has for its look.
    private var material: FrameMaterial {
        if #available(macOS 26, *) {
            let look = forced ?? MaterialLook.decide(glassAvailable: true, reduceTransparency: reduceTransparency)
            return look == .glass ? .glass(SystemGlassPainter()) : .solid
        }
        return .solid
    }
}
