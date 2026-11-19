import Foundation

/// What the collapsed widget draws (spec `docs/specs/2026-11-19-session-glance-widget.md`, GW-R3, GW-R4, GW14): the shown
/// entries in display order, then `+N` when more are live, laid out along the slot's axis. No item is the empty state, which
/// draws the faint mark (GW11). Pure, so a test reads it without a window.
struct GlanceStrip: Equatable {
    enum Item: Identifiable, Equatable {
        case entry(GlanceEntry)
        /// The `N` of `+N`.
        case overflow(Int)

        var id: String {
            switch self {
            case .entry(let entry): entry.id
            case .overflow: "overflow"
            }
        }
    }

    let axis: GlanceAxis
    let items: [Item]

    init(entries: GlanceEntries, slot: GlanceSlot) {
        axis = slot.axis
        let shown = entries.shown.map(Item.entry)
        items = entries.overflow > 0 ? shown + [.overflow(entries.overflow)] : shown
    }

    var isEmpty: Bool { items.isEmpty }
}
