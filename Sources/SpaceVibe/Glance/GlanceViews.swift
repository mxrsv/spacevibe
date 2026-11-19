import SwiftUI

/// The collapsed widget (spec `docs/specs/2026-11-19-session-glance-widget.md`, GW-R2 to GW-R4, GW14): up to six entries and
/// `+N` along the slot's axis, or the faint mark with no live session. A click on an entry goes through `open` (GW-R6).
struct GlanceStripView: View {
    let strip: GlanceStrip
    /// False while the widget is not on screen: the working ring stops (GW-R11).
    let isOnScreen: Bool
    let open: (GlanceEntry) -> Void

    var body: some View {
        GlanceCapsule(axis: strip.axis) {
            if strip.isEmpty {
                GlanceEmptyMark(accessibilityName: GlanceWording.noSession)
            }
            ForEach(strip.items) { item in
                switch item {
                case .entry(let entry):
                    GlanceEntryButton(state: entry.state, cli: entry.cli, axis: strip.axis, isAnimating: isOnScreen,
                                      accessibilityName: GlanceWording.spoken(entry)) { open(entry) }
                case .overflow(let count):
                    GlanceOverflowCount(text: GlanceWording.overflow(count), axis: strip.axis,
                                        accessibilityName: GlanceWording.overflowSpoken(count))
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(GlanceWording.widgetName)
    }
}

/// The hover list (GW4, GW-R5): every live session in display order, or one sentence when there is none. `rowsHeight` is
/// the room the rows have once the list is shorter than its content (the screen, or `Metrics.Glance.listMaxHeight`); the rows
/// then scroll. `width` sizes the sentence's list; rows always take the list's full width.
struct GlanceListView: View {
    let entries: [GlanceEntry]
    /// Shown when `entries` is empty: "No session running", or why the sessions could not be read.
    let note: String
    var width: CGFloat?
    var rowsHeight: CGFloat?
    /// False while the widget is not on screen: the working ring stops (GW-R11).
    let isOnScreen: Bool
    /// Where a click on the entry goes: the host app's name, or "Activity".
    let hint: (GlanceEntry) -> String
    let open: (GlanceEntry) -> Void

    var body: some View {
        if entries.isEmpty {
            GlanceListSurface(width: width) { GlanceListNote(text: note) }
        } else {
            GlanceListSurface {
                if let rowsHeight {
                    SpaceVibeScrollView { rows }
                        .frame(height: rowsHeight, alignment: .top)
                        .clipped()
                } else {
                    rows
                }
            }
        }
    }

    private var rows: some View {
        VStack(spacing: 0) {
            ForEach(entries) { entry in
                GlanceSessionRow(cli: entry.cli, title: entry.title, detail: GlanceWording.detail(entry), state: entry.state,
                                 stateLabel: GlanceWording.label(entry.state), isAnimating: isOnScreen,
                                 hint: { hint(entry) }, action: { open(entry) })
            }
        }
    }
}
