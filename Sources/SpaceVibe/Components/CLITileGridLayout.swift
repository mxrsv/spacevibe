import CoreGraphics

/// The shape of the inspector's CLI tile grid and the heat of each tile (RD15, RD-R12; the mock's `tileInspector`). Pure.
enum CLITileGridLayout {
    /// The most rows the grid ever has (RD15: "chỉ cho max là 3 hàng").
    static let maxRows = 3

    /// `max(3, ceil(N / 3))`: 3 columns up to 9 CLIs, then as many as keep the grid at 3 rows.
    static func columns(_ count: Int) -> Int {
        max(3, (max(0, count) + maxRows - 1) / maxRows)
    }

    static func rows(_ count: Int) -> Int {
        guard count > 0 else { return 0 }
        let columns = columns(count)
        return (count + columns - 1) / columns
    }

    /// The indexes on each row, in the fixed CLI order.
    static func lines(_ count: Int) -> [[Int]] {
        let columns = columns(count)
        return stride(from: 0, to: max(0, count), by: columns).map { Array($0 ..< min($0 + columns, count)) }
    }

    /// The grid's width: whole tiles and the gaps between them, each tile at most 72 and narrower when `available` is less
    /// than four of them need (the mock's `.tiles`: `width: min(100%, cols × 72 + (cols − 1) × 6)`, columns `minmax(0, 1fr)`).
    static func width(_ count: Int, available: CGFloat = .infinity) -> CGFloat {
        let columns = CGFloat(columns(count))
        return columns * tileWidth(count, available: available) + (columns - 1) * BlockRole.tileGap
    }

    /// One tile's width: 72 (RD-R12) while the columns fit in `available`, otherwise the share of it each column gets after
    /// the 6 pt gaps. Never below 0; an unknown width (0 or less, before the first layout) keeps 72.
    static func tileWidth(_ count: Int, available: CGFloat) -> CGFloat {
        guard available > 0 else { return BlockRole.tileWidth }
        let columns = CGFloat(columns(count))
        let share = (available - (columns - 1) * BlockRole.tileGap) / columns
        return max(0, min(BlockRole.tileWidth, share.rounded(.down)))
    }
}

/// One of the four neutral heat steps of a tile (RD-R8, RD-R12): how many sessions a CLI used the item for, relative to the
/// item's top CLI. 0 is no measured use (`data1`), then up to a quarter of the top (`data2`), up to 60% (`data3`), above
/// (`data4`). Never a state colour.
enum HeatStep: Int, CaseIterable, Comparable, Sendable {
    case none = 0, low, middle, high

    static func < (lhs: HeatStep, rhs: HeatStep) -> Bool { lhs.rawValue < rhs.rawValue }

    /// The step for `sessions` when the item's top CLI has `top` (the largest of its CLIs' counts).
    static func step(sessions: Int, top: Int) -> HeatStep {
        guard sessions > 0 else { return .none }
        let ratio = Double(sessions) / Double(max(1, top))
        if ratio <= 0.25 { return .low }
        if ratio <= 0.6 { return .middle }
        return .high
    }

    /// Each tile's step, against the top of the same list (unmeasured and off tiles count 0).
    static func steps(_ states: [CLIToggleState]) -> [HeatStep] {
        let top = states.map(\.measuredSessions).max() ?? 0
        return states.map { step(sessions: $0.measuredSessions, top: top) }
    }
}
