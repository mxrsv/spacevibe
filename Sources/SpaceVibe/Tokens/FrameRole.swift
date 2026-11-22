import SwiftUI

// The window frame's own metrics (RB-S3): the sidebar, the toolbar and the help popover, read from the reference mock's
// `src/style.css` (`~/scratch/spacevibe-reins/2026-11-20-redesign-v2`). The design-system spec's DS-R3 names the clearances
// and the inspector widths (`SpaceRole`, `InspectorWidth`); these are the frame metrics it did not name yet. A metric that
// differs by look takes the look as an argument, like `RadiusRole`.

enum FrameRole {
    /// The sidebar column, inset included: `.desk{--sw:240px}` and `.desk[data-look=solid]{--sw:224px}` (style.css:56-57).
    static func sidebarWidth(_ look: MaterialLook) -> CGFloat { look == .glass ? 240 : 224 }

    /// The toolbar strip over the content: `.tb{height:60px}` and `.desk[data-look=solid] .tb{height:52px}` (style.css:89, 94).
    /// The overlay inspector starts below it (`.in.ov{top:60px}`, style.css:482).
    static func toolbarHeight(_ look: MaterialLook) -> CGFloat { look == .glass ? 60 : 52 }

    /// The toolbar's primary or destructive button keeps this one width, so its label never moves the controls beside it
    /// (RD-R17 Layout): `.dst.slot,.pri.slot,span.slot{min-width:196px;max-width:196px}` (style.css:523).
    static let toolbarSlotWidth: CGFloat = 196

    /// One sidebar page item: `.nv{height:32px}` and `.desk[data-look=solid] .nv{height:30px}` (style.css:72-73).
    static func sidebarItemHeight(_ look: MaterialLook) -> CGFloat { look == .glass ? 32 : 30 }

    /// A sidebar page item's corner: `.nv{border-radius:calc(var(--r-sb) - 8px)}` (18 − 8 = 10 in Glass) and
    /// `.desk[data-look=solid] .nv{border-radius:var(--r6)}` (style.css:72-73).
    static func sidebarItemCorner(_ look: MaterialLook) -> CornerRole {
        .radius(look == .glass ? RadiusRole.step10 : RadiusRole.step6)
    }

    /// The Settings item at the sidebar's foot: `.sbf button{border-radius:var(--r8)}` (style.css:82).
    static let sidebarFootCorner = CornerRole.radius(RadiusRole.step8)

    /// The page help popover beside the title (RD32): `.hpop{width:300px;padding:var(--sp12)}` (style.css:567).
    static let helpPopoverWidth: CGFloat = 300

    /// The Settings window's width (`style.css` `.sw{width:660px}`, style.css:290).
    static let settingsWindowWidth: CGFloat = 660

    /// The Settings window's pane body is at least this tall, so switching panes never resizes the window much
    /// (`.sbody{min-height:380px}`, style.css:302).
    static let settingsBodyMinHeight: CGFloat = 380

    /// One Settings pane tab is at least this wide (`.panes b{min-width:74px}`, style.css:298).
    static let paneTabMinWidth: CGFloat = 74

    /// The sidebar's top, where the window's traffic lights sit: `.lights{height:52px}` (style.css:67).
    static let trafficLightClearance: CGFloat = 52

    /// With the sidebar hidden (RD47) the toolbar starts after the window's traffic lights, as a macOS toolbar does when its
    /// sidebar collapses: the three 12 pt buttons, their 8 pt gaps and the 20 pt the system keeps on each side of them.
    static let trafficLightsWidth: CGFloat = 92
}
