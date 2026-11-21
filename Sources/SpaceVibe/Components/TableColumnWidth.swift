import CoreGraphics

/// The fixed column widths of the frame's tables (the mock's `--cols` on `.th` and `.tr`), the one list of them: a table names
/// its columns here, so a screen holds no number (DS-R3) and a long name or a state in one cell never moves the columns of
/// the rows below (FE-L1). The name column takes what is left.
enum TableColumnWidth {
    /// A state glyph or a kind icon before the name.
    static let glyph: CGFloat = 20
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
    /// Activity › Sessions: the selected row's Stop (`112px`).
    static let sessionAction: CGFloat = 112
    /// Activity: the open tool call (`220px`).
    static let currentTool: CGFloat = 220
    /// Activity: the session's age (`96px`).
    static let age: CGFloat = 96
    /// Activity › Failures: the failure count (`64px`).
    static let failureCount: CGFloat = 64
    /// Activity › Failures: the selected row's Copy Command (`148px`).
    static let failureAction: CGFloat = 148
    /// Sessions on Skills and Subagents: a thin bar and its count (the mock's `pageEquip` grid, `96px`).
    static let sessions: CGFloat = 96
    /// The bar inside the Sessions cell (`.rch.tt`, `48px`); the count takes the rest.
    static let sessionsBar: CGFloat = 48
    /// Last ran on Skills and Subagents: a day (`today`, `12 days ago`; `76px`).
    static let lastRan: CGFloat = 76
    /// A table's header line (the mock's `.th`, 30 px).
    static let headerHeight: CGFloat = 30
    /// The list width from which a table shows its wide columns (the mock's `ctx.wide`, `mw >= 940`): below it Hooks folds
    /// its Status column into the row's sub-line and Activity drops its Current tool and Age columns.
    static let wideListWidth: CGFloat = 940
    /// Rules: a rule's permission, glyph and word (`104px`).
    static let permission: CGFloat = 104
    /// Rules: a capability's name (`120px`).
    static let capabilityName: CGFloat = 120
    /// Rules: a capability's Allow / Ask / Deny dial (`190px`).
    static let capabilityDial: CGFloat = 190
}
