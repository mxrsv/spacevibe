import SwiftUI

// The surfaces of the redesign's window frame (RB-S3): the material every block reads (AR8), the window's one solid surface
// with the floating sidebar's shape cut out, the sidebar, the toolbar strip and the trailing inspector. Frame-only drawing
// lives here because a screen folder may not paint (`StyleBoundaryTests`); `Shell/AppFrame.swift` composes it.

// MARK: - Material (AR8)

/// Draws the system's Liquid Glass on a view. Only the frame root makes one, inside its single `if #available(macOS 26, *)`
/// (`Shell/FrameLook.swift`), so no other view calls `#available` for the look.
protocol FrameGlassPainter: Sendable {
    @MainActor func paint(_ content: AnyView, in corner: CornerRole, interactive: Bool) -> AnyView
}

/// The macOS 26 material: `glassEffect` in the corner's shape (DS-R8).
@available(macOS 26, *)
struct SystemGlassPainter: FrameGlassPainter {
    @MainActor func paint(_ content: AnyView, in corner: CornerRole, interactive: Bool) -> AnyView {
        AnyView(content.glassEffect(interactive ? .regular.interactive() : .regular, in: CornerRoleShape(corner)))
    }
}

/// The window's material, decided once at the frame root (macOS 26 and Reduce Transparency off → Glass) and read by every
/// block through `\.frameMaterial` or `\.materialLook`. Glass carries the painter that draws it, so a Glass look without the
/// system material cannot be expressed.
enum FrameMaterial {
    case solid
    case glass(any FrameGlassPainter)

    var look: MaterialLook {
        switch self {
        case .solid: .solid
        case .glass: .glass
        }
    }
}

private struct FrameMaterialKey: EnvironmentKey {
    static let defaultValue = FrameMaterial.solid
}

extension EnvironmentValues {
    /// The frame's material (AR8). Default Solid: a view drawn outside the frame (a specimen, a shot) is Solid.
    var frameMaterial: FrameMaterial {
        get { self[FrameMaterialKey.self] }
        set { self[FrameMaterialKey.self] = newValue }
    }

    /// The frame's look, for a token that differs by look (`RadiusRole.controlCorner(look)` and the like).
    var materialLook: MaterialLook { frameMaterial.look }
}

/// A `CornerRole` as a shape: a continuous rounded rectangle, or a capsule.
struct CornerRoleShape: InsettableShape {
    let corner: CornerRole
    var inset: CGFloat = 0

    init(_ corner: CornerRole) { self.corner = corner }

    func path(in rect: CGRect) -> Path {
        let box = rect.insetBy(dx: inset, dy: inset)
        let radius: CGFloat
        switch corner {
        case .radius(let value): radius = max(0, value - inset)
        case .capsule: radius = min(box.width, box.height) / 2
        }
        return RoundedRectangle(cornerRadius: radius, style: .continuous).path(in: box)
    }

    func inset(by amount: CGFloat) -> CornerRoleShape {
        var copy = self
        copy.inset += amount
        return copy
    }
}

extension View {
    /// The look's surface in `corner`: the system glass in Glass (interactive for a control), `solid` filled in Solid.
    func frameGlass(in corner: CornerRole, interactive: Bool = false, solid: Color) -> some View {
        modifier(FrameGlassSurface(corner: corner, interactive: interactive, solid: solid))
    }
}

private struct FrameGlassSurface: ViewModifier {
    let corner: CornerRole
    let interactive: Bool
    let solid: Color
    @Environment(\.frameMaterial) private var material

    func body(content: Content) -> some View {
        switch material {
        case .glass(let painter): painter.paint(AnyView(content), in: corner, interactive: interactive)
        case .solid: content.background(solid, in: CornerRoleShape(corner))
        }
    }
}

// MARK: - Window, sidebar, toolbar, inspector

/// The window's one solid surface (design notes, 2026-11-21 fix): the canvas everywhere, and in Glass only the floating
/// sidebar's own rounded shape cut out, so the sidebar is the one place the desktop shows through. No band, no stepped corner.
/// A window without a sidebar (Settings) passes `hasSidebar: false` and is the canvas throughout.
struct FrameWindowSurface: View {
    var hasSidebar = true
    @Environment(\.materialLook) private var look

    var body: some View {
        FrameWindowShape(sidebarWidth: FrameRole.sidebarWidth(look), inset: hasSidebar ? RadiusRole.sidebarInset(look) : 0,
                         corner: RadiusRole.sidebarCorner(look))
            .fill(ColorRole.canvasSurface, style: FillStyle(eoFill: true))
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}

/// The window's rectangle minus the sidebar's rounded rectangle (even-odd). With no inset (Solid) nothing is cut out.
private struct FrameWindowShape: Shape {
    let sidebarWidth: CGFloat
    let inset: CGFloat
    let corner: CornerRole

    func path(in rect: CGRect) -> Path {
        var path = Path(rect)
        guard inset > 0 else { return path }
        let sidebar = CGRect(x: rect.minX + inset, y: rect.minY + inset,
                             width: sidebarWidth - inset * 2, height: rect.height - inset * 2)
        path.addPath(CornerRoleShape(corner).path(in: sidebar))
        return path
    }
}

extension View {
    /// The main window's own background: cleared in Glass, so the desktop shows through the one hole `FrameWindowSurface`
    /// leaves (the floating sidebar's shape); the system's in Solid, which `FrameWindowSurface` covers.
    func frameWindowBackground() -> some View {
        modifier(FrameWindowBackground())
    }

    /// The sidebar column (RD-R1): in Glass a floating glass shape inset from the window's edges; in Solid the sidebar
    /// ground flush with the edges and a hairline on its trailing side (`style.css` `.sb`).
    func frameSidebarSurface() -> some View {
        modifier(FrameSidebarSurface())
    }

    /// The toolbar strip (`style.css` `.tb`): nothing of its own in Glass, where each control is glass; the canvas with a
    /// hairline under it in Solid.
    func frameToolbarSurface() -> some View {
        modifier(FrameToolbarSurface())
    }

    /// The trailing inspector (`style.css` `.in`, `.in.ov`): docked, the group ground in the sidebar's corner (Glass) or the
    /// canvas with a leading hairline (Solid); as an overlay below 1100 pt, the same with a hairline ring and the float shadow.
    func frameInspectorSurface(overlay: Bool) -> some View {
        modifier(FrameInspectorSurface(overlay: overlay))
    }
}

private struct FrameWindowBackground: ViewModifier {
    @Environment(\.materialLook) private var look

    func body(content: Content) -> some View {
        if look == .glass {
            content.containerBackground(.clear, for: .window)
        } else {
            content
        }
    }
}

private struct FrameSidebarSurface: ViewModifier {
    @Environment(\.materialLook) private var look

    func body(content: Content) -> some View {
        switch look {
        case .glass:
            content
                .frameGlass(in: RadiusRole.sidebarCorner(look), solid: ColorRole.sidebarSurface)
                .padding(RadiusRole.sidebarInset(look))
        case .solid:
            content
                .background(ColorRole.sidebarSurface)
                .overlay(alignment: .trailing) { FrameHairline(axis: .vertical) }
        }
    }
}

private struct FrameToolbarSurface: ViewModifier {
    @Environment(\.materialLook) private var look

    func body(content: Content) -> some View {
        switch look {
        case .glass: content
        case .solid:
            content
                .background(ColorRole.canvasSurface)
                .overlay(alignment: .bottom) { FrameHairline(axis: .horizontal) }
        }
    }
}

private struct FrameInspectorSurface: ViewModifier {
    let overlay: Bool
    @Environment(\.materialLook) private var look

    func body(content: Content) -> some View {
        let corner = RadiusRole.sidebarCorner(look)
        let inset = RadiusRole.sidebarInset(look)
        let ground = look == .glass ? ColorRole.groupSurface : ColorRole.canvasSurface
        content
            .background(ground, in: CornerRoleShape(corner))
            .overlay {
                if overlay { CornerRoleShape(corner).strokeBorder(ColorRole.hairline) }
            }
            .overlay(alignment: .leading) {
                if look == .solid && !overlay { FrameHairline(axis: .vertical) }
            }
            .shadow(color: overlay ? ColorRole.floatShadow : .clear, radius: ShadowRole.floatRadius, y: ShadowRole.floatOffsetY)
            .padding([.top, .bottom, .trailing], inset)
    }
}

/// The one-point edge between frame regions in Solid.
private struct FrameHairline: View {
    let axis: Axis

    var body: some View {
        Rectangle()
            .fill(ColorRole.hairline)
            .frame(width: axis == .vertical ? 1 : nil, height: axis == .horizontal ? 1 : nil)
            .accessibilityHidden(true)
    }
}
