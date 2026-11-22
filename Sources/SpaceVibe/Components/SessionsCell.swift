import SwiftUI

/// A Skill's or Subagent's Sessions cell (RD-R11, D23 replaced; the mock's `totCell`, `.rch.tt`), the sibling of `RunsCell`
/// (GLOSSARY: Runs are Hooks only, Sessions are Skills and Subagents): a thin 4 pt data bar scaled to the page's busiest item
/// and the count after it in `quietMedium` figures. Never ran reads `0` at 400 in `ink3` on an empty track; `+?` follows the
/// count when a CLI's folder could not be read, so the figure is a floor; a cell still being counted is a still
/// `SkeletonLine`. One width, so `4.8M` and `0` end on the same line.
struct SessionsCell: View {
    enum Value: Hashable, Sendable {
        /// `share` of the page's busiest item, 0 to 1; `floor` adds `+?`.
        case count(Int, share: Double, floor: Bool)
        /// Counted and zero; `floor` adds `+?`.
        case zero(floor: Bool)
        case pending
    }

    let value: Value

    init(_ value: Value) { self.value = value }

    var body: some View {
        HStack(spacing: SpaceRole.step6) {
            switch value {
            case .count(let sessions, let share, let floor):
                ShareMeter(share: share, tone: .data).frame(width: TableColumnWidth.sessionsBar)
                figure(NumberWording.compactCount(sessions) + (floor ? "+?" : ""), role: .quietMedium, ink: ColorRole.ink)
            case .zero(let floor):
                ShareMeter(share: 0).frame(width: TableColumnWidth.sessionsBar)
                figure(NumberWording.count(0) + (floor ? "+?" : ""), role: .quiet, ink: ColorRole.ink3)
            case .pending:
                // The mock's `.sk` over the whole cell: nothing is counted yet, so no bar and no figure.
                SkeletonLine(.long)
            }
        }
        .frame(width: TableColumnWidth.sessions, alignment: .leading)
        .help(Self.tooltip(value))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Sessions")
        .accessibilityValue(Self.spoken(value))
    }

    private func figure(_ text: String, role: TypeRole, ink: Color) -> some View {
        FigureText(text, role: role)
            .foregroundStyle(ink)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    /// The value for `total` sessions against the page's `top`: a sliver at least, so a small count still shows (the mock's 5%).
    static func value(total: Int, top: Int, floor: Bool, pending: Bool) -> Value {
        if pending { return .pending }
        guard total > 0 else { return .zero(floor: floor) }
        return .count(total, share: max(minimumShare, Double(total) / Double(max(1, top))), floor: floor)
    }

    static let minimumShare = 0.05

    /// "1,204 sessions", "0 sessions or more", "Counting".
    static func spoken(_ value: Value) -> String {
        switch value {
        case .count(let n, _, let floor): NumberWording.plural(n, "session") + (floor ? " or more" : "")
        case .zero(let floor): NumberWording.plural(0, "session") + (floor ? " or more" : "")
        case .pending: "Counting"
        }
    }

    static func tooltip(_ value: Value) -> String {
        switch value {
        case .count(_, _, true), .zero(true): "Plus Unmeasurable sessions in a CLI that could not be read"
        case .count(let n, _, false): NumberWording.plural(n, "session")
        case .zero(false): NumberWording.plural(0, "session")
        case .pending: "Counting sessions"
        }
    }
}
