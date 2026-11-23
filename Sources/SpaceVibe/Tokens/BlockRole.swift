import SwiftUI

/// Sizes of single blocks (RB-S4) that the design-system spec states in its block text and the reference mock draws, but that
/// `SizeRole` does not hold: the CLI tile (RD-R12 "about 72×60 pt"), its marks, and the widths of the overlay surfaces. Read from
/// the mock's `src/style.css` (`.tile`, `.tgl`, `.toast`, `.alert.sheet`, `.cpop`, `.tpop`). New-frame blocks only (AR6).
enum BlockRole {
    /// A CLI tile in the inspector grid (`.tile`: 72 × 60, radius 10, 6 apart).
    static let tileWidth: CGFloat = 72
    static let tileHeight: CGFloat = 60
    static let tileGap: CGFloat = 6
    /// The disc behind a tile's success check (`.tile .tok`): the check at 12 with 2 around it, in the group surface's colour.
    static let tileCheckDisc: CGFloat = 16
    /// The disc behind a tile's logo on a heat step it would not read on (RD48): the 20 pt logo with 2 around it, in the group
    /// surface's colour, like the check's (`ColorRole.tileLogoDisc`).
    static let tileLogoDisc: CGFloat = 24
    /// The amber Never ran dot (`.nvd`) on a logo toggle and on a tile.
    static let neverRanDot: CGFloat = 5
    /// The height of the Not supported dash in a logo toggle's cell (`.tgl .dash`).
    static let notSupportedDash: CGFloat = 2
    /// The `?` disc of an unreadable CLI's logo (`.tgl .qm`).
    static let unknownDisc: CGFloat = 12
    /// The lock, link or `?` glyph at a logo toggle's corner. The mock draws it 9 × 9 (`.tgl .lk .ic`); 12 is DS-R6's smallest
    /// icon size.
    static let toggleBadgeGlyph = SizeRole.icon12
    /// Logo toggles per line in a row before they wrap (RD-R11).
    static let togglesPerLine = 5

    /// A toast's height when it holds one line (`.toast` min-height 44) and its widest (`max-width: 620px`).
    static let toastMinHeight: CGFloat = 44
    static let toastMaxWidth: CGFloat = 620
    /// What a toast keeps clear of each side of the window (`max-width: min(620px, calc(100% - 320px))`).
    static let toastWindowMargin: CGFloat = 160
    /// The Settings window's toast keeps 5 % of the 660 window clear on each side (the mock's `.toast` `max-width: 90%`).
    static let settingsToastWindowMargin: CGFloat = FrameRole.settingsWindowWidth * 0.05
    /// The per-CLI sheet and the remove confirmation (`.alert.sheet`, width 392).
    static let sheetWidth: CGFloat = 392
    /// A menu (`.cpop`, 252 wide) and an anchored popover (`.tpop`, and the page help popover `.hpop`, both 300 wide).
    static let menuWidth: CGFloat = 252
    static let popoverWidth: CGFloat = 300
    /// The project picker's path column (`.ppop .cpi`, at most 190 wide).
    static let menuDetailMaxWidth: CGFloat = 190
    /// The tallest the dialog list grows before it scrolls (`.pkl.scroll`, max-height 252): five rows.
    static let dialogListMaxHeight: CGFloat = 252
    /// A legend swatch (`.tleg i`, 12 × 12, radius 4).
    static let legendSwatch: CGFloat = 12
    /// The toolbar's search field (`.srch`, 176 wide), and the toolbar width under which it folds to its icon button. The
    /// mock's `srch` folds below an 860 main column (`mw < 860`), the column its toolbar sat over; with the toolbar across the
    /// window (RD57) the same 860 applies to the toolbar, so the fold never depends on the page's inspector.
    static let searchFieldWidth: CGFloat = 176
    static let searchFoldsBelowToolbarWidth: CGFloat = 860

    /// The switch (`.swt`): a 34 × 20 track and a 16 pt knob.
    static let switchTrackWidth: CGFloat = 34
    static let switchTrackHeight = SizeRole.controlMini
    static let switchKnob = SizeRole.icon16
    /// An inspector's key column (`grid-template-columns: 84px …`), and a page's settings list with longer keys ("Approval
    /// policy"; the mock's Rules `160px`).
    static let keyColumn: CGFloat = 84
    static let wideKeyColumn: CGFloat = 160
    /// A lifecycle node's disc and its ring (`.nd .pt`: 22, a 2 ring), and how far its badge disc sits past the disc's corner
    /// (`.ndb`, 7).
    static let lifecycleDisc: CGFloat = 22
    static let lifecycleRing = SpaceRole.step2
    static let lifecycleBadgeOffset: CGFloat = 7
    /// Below this list width a finding row leaves out its evidence column (the mock's `mw >= 700`), so the name keeps room.
    static let findingEvidenceFromListWidth: CGFloat = 700
    /// Where the pending ring's quarter arc starts (the mock's `.spin` `border-top`): the top, a quarter turn before 12 o'clock
    /// less half the arc.
    static let pendingArcRotation = Angle.degrees(-135)
}
