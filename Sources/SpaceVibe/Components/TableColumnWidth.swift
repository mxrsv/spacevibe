import CoreGraphics

/// The fixed column widths of the frame's tables (the mock's `--cols` grids, `src/d-hooks-rules.js`), so a long name or a
/// state in one cell never moves the columns of the rows below (FE-L1). The name column takes what is left.
enum TableColumnWidth {
    /// A CLI logo column: the 28 pt cell of a 20 pt logo.
    static let logo: CGFloat = SizeRole.hitCell
    /// Runs: a thin bar and its count.
    static let runs: CGFloat = 148
    /// The count after a Runs bar.
    static let runsFigure: CGFloat = 44
    /// Status: a state glyph and a short sentence.
    static let status: CGFloat = 168
    /// The selected row's action buttons; every row keeps the room, so selecting a row moves nothing.
    static let action: CGFloat = 172
    /// Sessions on Skills and Subagents: a thin bar and its count (the mock's `pageEquip` grid, `96px`).
    static let sessions: CGFloat = 96
    /// The bar inside the Sessions cell (`.rch.tt`, `48px`); the count takes the rest.
    static let sessionsBar: CGFloat = 48
    /// Last ran on Skills and Subagents: a day (`today`, `12 days ago`; `76px`).
    static let lastRan: CGFloat = 76
    /// A table's header line (the mock's `.th`, 30 px).
    static let headerHeight: CGFloat = 30
    /// Below this list width the Status column folds into the row's sub-line (the mock's `ctx.wide`, `mw >= 940`).
    static let statusColumnMinListWidth: CGFloat = 940
    /// Rules: a rule's permission, glyph and word (`104px`).
    static let permission: CGFloat = 104
    /// Rules: a capability's name (`120px`).
    static let capabilityName: CGFloat = 120
    /// Rules: a capability's Allow / Ask / Deny dial (`190px`).
    static let capabilityDial: CGFloat = 190
}
