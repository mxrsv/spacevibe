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
    /// The amber Never ran dot (`.nvd`) on a logo toggle and on a tile.
    static let neverRanDot: CGFloat = 5
    /// The bar under a last-copy logo or tile (`.tgl.last::after`): 2 high, inset 8 from the cell's sides.
    static let lastCopyBar: CGFloat = 2
    /// The `?` disc of an unreadable CLI's logo (`.tgl .qm`).
    static let unknownDisc: CGFloat = 12
    /// The lock or link glyph at a logo toggle's corner (`.tgl .lk .ic`, 9 × 9).
    static let toggleBadgeGlyph: CGFloat = 9
    /// Logo toggles per line in a row before they wrap (RD-R11).
    static let togglesPerLine = 5

    /// A toast's height when it holds one line (`.toast` min-height 44) and its widest (`max-width: 620px`).
    static let toastMinHeight: CGFloat = 44
    static let toastMaxWidth: CGFloat = 620
    /// What a toast keeps clear of each side of the window (`max-width: min(620px, calc(100% - 320px))`).
    static let toastWindowMargin: CGFloat = 160
    /// The per-CLI sheet and the remove confirmation (`.alert.sheet`, width 392).
    static let sheetWidth: CGFloat = 392
    /// A menu (`.cpop`, 252 wide) and an anchored popover (`.tpop`, 300 wide).
    static let menuWidth: CGFloat = 252
    static let popoverWidth: CGFloat = 300
    /// The project picker's path column (`.ppop .cpi`, at most 190 wide).
    static let menuDetailMaxWidth: CGFloat = 190
    /// The tallest the dialog list grows before it scrolls (`.pkl.scroll`, max-height 252): five rows.
    static let dialogListMaxHeight: CGFloat = 252
    /// A legend swatch (`.tleg i`, 12 × 12, radius 4).
    static let legendSwatch: CGFloat = 12
    /// The toolbar's search field (`.srch`, 176 wide), and the main column width under which it folds to its icon button
    /// (the mock's `srch`: `mw < 860`).
    static let searchFieldWidth: CGFloat = 176
    static let searchFoldsBelowListWidth: CGFloat = 860
}
