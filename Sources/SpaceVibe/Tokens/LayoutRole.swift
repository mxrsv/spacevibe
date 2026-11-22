import SwiftUI

// The design-system spec's space, radius, size, opacity, depth and motion tokens (DS-R3 to DS-R9), read from the reference
// mock's `src/style.css` and its Tokens page. New-frame views take every number from here (AR6; v5 numbers stay in
// `Metrics`, `Space` and `Rhythm`).

/// The window's look (DS-R8): Glass is the system material on macOS 26; Solid on macOS 15 and with Reduce Transparency.
/// Decided once at the frame root and passed down (AR8); a token that differs by look takes it as an argument.
enum MaterialLook: Hashable, Sendable {
    case glass, solid
}

/// Spacing steps and the named layout metrics (DS-R3). Nothing else in a screen is a number.
enum SpaceRole {
    static let step2: CGFloat = 2
    static let step4: CGFloat = 4
    static let step6: CGFloat = 6
    static let step8: CGFloat = 8
    static let step10: CGFloat = 10
    static let step12: CGFloat = 12
    static let step16: CGFloat = 16
    static let step20: CGFloat = 20
    static let step24: CGFloat = 24

    static let steps: [CGFloat] = [step2, step4, step6, step8, step10, step12, step16, step20, step24]

    /// How far content starts below the top: the toolbar is the system's, 68 in Glass and 64 in Solid.
    static func toolbarClearance(_ look: MaterialLook) -> CGFloat { look == .glass ? 68 : 64 }
    /// How far content starts below a window's title bar (the Settings window, a sheet).
    static let titleBarClearance: CGFloat = 36
    /// Where an empty state starts.
    static let emptyStateTop: CGFloat = 72
    /// Below this window width the inspector is an overlay that covers the list (RD-R13).
    static let inspectorOverlayBelowWindowWidth: CGFloat = 1100
    /// The Glass sidebar's inset from the window edge; 26 = 18 + 8, so its corners are concentric with the window's.
    static func sidebarInset(_ look: MaterialLook) -> CGFloat { look == .glass ? step8 : 0 }
}

/// The trailing inspector's width at any window width from `SpaceRole.inspectorOverlayBelowWindowWidth` up: `wide` on the
/// pages whose inspector holds the CLI tile grid (Skills, Subagents, Inbox; `FramePage.inspectorWidth`), `standard` on every
/// other page (the mock's `iw`, owner 2026-11-21: no 1600 rule).
enum InspectorWidth: Hashable, Sendable {
    case standard, wide

    var points: CGFloat { self == .wide ? 336 : 308 }
}

/// A corner: a fixed radius, or a capsule (half the shorter side).
enum CornerRole: Hashable, Sendable {
    case radius(CGFloat)
    case capsule
}

/// Radius steps and the radii by look (DS-R4). Meters, ticks and dots are capsules. The by-look radii end in `Corner`
/// because `window` and `control` are v5 `Metrics.Radius` names with other values (AR6).
enum RadiusRole {
    static let step4: CGFloat = 4
    static let step6: CGFloat = 6
    static let step8: CGFloat = 8
    static let step10: CGFloat = 10
    static let step14: CGFloat = 14
    static let step18: CGFloat = 18

    static let steps: [CornerRole] = [.radius(step4), .radius(step6), .radius(step8), .radius(step10), .radius(step14),
                                      .radius(step18), .capsule]

    /// The sidebar: a floating 18 in Glass, square and flush in Solid. (The window's own corner, 26 / 12, is the system's.)
    static func sidebarCorner(_ look: MaterialLook) -> CornerRole { .radius(look == .glass ? step18 : 0) }
    static func groupCorner(_ look: MaterialLook) -> CornerRole { .radius(look == .glass ? step14 : step10) }
    /// Buttons, toolbar controls, segmented controls and fields.
    static func controlCorner(_ look: MaterialLook) -> CornerRole { look == .glass ? .capsule : .radius(step6) }
    static func popoverCorner(_ look: MaterialLook) -> CornerRole { .radius(look == .glass ? step14 : step10) }
    static let meterCorner = CornerRole.capsule
}

/// Control, row, meter and icon sizes (DS-R5, DS-R6), and the keyboard focus bar (RD29).
enum SizeRole {
    static let controlRegular: CGFloat = 32
    static let controlSmall: CGFloat = 26
    static let controlMini: CGFloat = 20
    /// A checkbox, toggle or logo toggle sits in this cell, and the whole cell takes the click.
    static let hitCell: CGFloat = 28
    /// No hit target is smaller (RD-R16).
    static let minimumHitTarget: CGFloat = 24

    static let tableRow: CGFloat = 48
    /// A table row whose logo toggles wrap to a second line (from 7 CLIs).
    static let tableRowWrapped: CGFloat = 60
    static let listRow: CGFloat = 44

    /// Segmented controls (DS-R5) are a regular or small control: the track is `controlRegular` or `controlSmall`, and its
    /// segments sit `segmentedInset` inside the edge, so 28 and 22 high.
    static let segmentedInset = SpaceRole.step2
    static let segmentRegular = controlRegular - 2 * segmentedInset
    static let segmentSmall = controlSmall - 2 * segmentedInset

    /// Meters (RD-R6): 4 in rows, 6 for the hero and Limits, 3 for progress. The pace tick is 2 wide and stands 2 past the
    /// meter above and below (the mock's `.mtr .tk`).
    static let meterRow: CGFloat = 4
    static let meterHero: CGFloat = 6
    static let meterProgress: CGFloat = 3
    static let paceTickWidth: CGFloat = 2
    static let paceTickOverhang: CGFloat = 2

    /// Keyboard focus: a 3 pt `ink` bar inside the focused row, field or control's leading edge, never a ring (RD29, D57).
    static let focusBar: CGFloat = 3

    static let icon12: CGFloat = 12
    static let icon14: CGFloat = 14
    static let icon16: CGFloat = 16
    static let icon20: CGFloat = 20
    static let icon40: CGFloat = 40
    static let icons: [CGFloat] = [icon12, icon14, icon16, icon20, icon40]
    /// A CLI logo is 16 or 20 (DS-R6): the same values as `icon16` and `icon20`, named so a logo can only take those two.
    static let logo16 = icon16
    static let logo20 = icon20

    /// The icon sizes `SpaceVibeIcon(frame:size:)` takes, so a new-frame icon never reaches a v5 size (`IconSize`, `Metrics`):
    /// each case is one of DS-R6's sizes. The case names match v5's so a call reads the same.
    enum Icon: CaseIterable, Sendable {
        /// A sidebar page icon, a pane tab: 20.
        case row
        /// Buttons, toolbar controls, fields: 16.
        case control
        /// Beside 12 pt text: 14.
        case inline
        /// A chevron, a check, a state glyph in a sidebar value: 12.
        case small
        /// An empty state's mark: 40.
        case hero

        var points: CGFloat {
            switch self {
            case .row: SizeRole.icon20
            case .control: SizeRole.icon16
            case .inline: SizeRole.icon14
            case .small: SizeRole.icon12
            case .hero: SizeRole.icon40
            }
        }
    }
}

/// Stroke widths: the 1 pt edge (a hairline, a control's edge, the dashed Off tile), the checkbox's 1.4 edge (the mock's
/// `inset 0 0 0 1.4px`) and the selected segment's 0.5 edge (`.seg b.on` `inset 0 0 0 .5px`).
enum StrokeRole {
    static let hairline: CGFloat = 1
    static let checkboxEdge: CGFloat = 1.4
    static let selectedSegmentEdge: CGFloat = 0.5
}

/// The only opacities a view uses (DS-R7).
enum OpacityRole {
    static let disabled = 0.42
    /// An off logo.
    static let dim = 0.55
    /// Not supported.
    static let ghost = 0.35
}

/// The one `float` shadow (DS-R8), with `ColorRole.floatShadow`: in-content popovers in Solid and the overlay inspector
/// (`View.floatShadow(when:)`). The mock's CSS is `0 16px 34px -10px`; SwiftUI's radius is half a CSS blur and it has no
/// spread, so the one offset is the CSS offset less the spread's 10, which keeps the shadow's visible lower edge where the
/// mock draws it.
enum ShadowRole {
    static let floatRadius: CGFloat = 17
    static let floatY: CGFloat = 6
    /// The light Off knob's shadow (`0 1px 2px`): blur 2, so radius 1, one point down.
    static let switchKnobRadius: CGFloat = 1
    static let switchKnobOffsetY: CGFloat = 1
}

extension View {
    /// The one float shadow, or none when `shows` is false.
    func floatShadow(when shows: Bool = true) -> some View {
        shadow(color: shows ? ColorRole.floatShadow : .clear, radius: ShadowRole.floatRadius, y: ShadowRole.floatY)
    }
}

/// The motion there is (DS-R9): the switch knob, a 1 pt tile lift on hover and a press scale. No loops, no shimmer, no
/// scroll-bound effects. Reduce Motion removes the lift and the scale.
enum MotionRole {
    static let switchKnobDuration: TimeInterval = 0.15
    /// Hover and press on a tile.
    static let tileDuration: TimeInterval = 0.12
    static let tileLift: CGFloat = 1
    /// A meter's fill growing to a new share (FE8 "filling bars"); at once with Reduce Motion.
    static let meterFillDuration: TimeInterval = 0.12
    static let pressScale: CGFloat = 0.98
    /// A toast sliding in from the bottom edge (opacity only with Reduce Motion).
    static let toastSlideDuration: TimeInterval = 0.2
    /// The sidebar folding away and back (Hide Sidebar, RD47); at once with Reduce Motion.
    static let sidebarDuration: TimeInterval = 0.2

    static func lift(reduceMotion: Bool) -> CGFloat { reduceMotion ? 0 : tileLift }
    static func scale(pressed: Bool, reduceMotion: Bool) -> CGFloat { pressed && !reduceMotion ? pressScale : 1 }
}
