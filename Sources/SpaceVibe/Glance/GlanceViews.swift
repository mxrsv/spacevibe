import SwiftUI

/// The collapsed widget (spec `docs/specs/2026-11-19-session-glance-widget.md`, GW-R2 to GW-R4, GW14): up to six entries and
/// `+N` along the slot's axis, or the faint mark with no live session. A click on an entry goes through `open` (GW-R6).
struct GlanceStripView: View {
    let strip: GlanceStrip
    /// False while the widget is not on screen: the working ring stops (GW-R11).
    let isOnScreen: Bool
    /// Why the sessions could not be read (`GlanceFeed.failure`). The entries are then the last read: they fade, their rings
    /// stop, and VoiceOver reads the sentence.
    var failure: String?
    let open: (GlanceEntry) -> Void

    var body: some View {
        GlanceCapsule(axis: strip.axis, isStale: failure != nil && !strip.isEmpty) {
            if strip.isEmpty {
                GlanceEmptyMark(accessibilityName: GlanceWording.noSession)
            }
            ForEach(strip.items) { item in
                switch item {
                case .entry(let entry):
                    GlanceEntryButton(state: entry.state, cli: entry.cli, axis: strip.axis, isAnimating: isOnScreen && failure == nil,
                                      accessibilityName: GlanceWording.spoken(entry)) { open(entry) }
                case .overflow(let count):
                    GlanceOverflowCount(text: GlanceWording.overflow(count), axis: strip.axis,
                                        accessibilityName: GlanceWording.overflowSpoken(count))
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(GlanceWording.widgetName)
        .accessibilityValue(failure ?? "")
    }
}

/// The hover list (GW4, GW-R5): every live session in display order, or one sentence when there is none, then the pinned
/// Limits group when a window counts down (LC-R6). `rowsHeight` is the room the session rows have once the list is shorter
/// than its content (the screen, or `Metrics.Glance.listMaxHeight`); the rows then scroll and the Limits group stays in view
/// under them. `width` sizes the bare sentence's list; otherwise the list is `Metrics.Glance.listWidth` wide.
struct GlanceListView: View {
    let entries: [GlanceEntry]
    /// Shown when `entries` is empty: "No session running", or why the sessions could not be read.
    let note: String
    /// Why the sessions could not be read (`GlanceFeed.failure`, S-R3: the core's sentence or the fixed one). The rows are
    /// then the last read: the sentence sits above them, inside the scrolling part so the controller's sizing holds, and
    /// their rings stop.
    var failure: String?
    var width: CGFloat?
    var rowsHeight: CGFloat?
    /// False while the widget is not on screen: the working ring stops (GW-R11).
    let isOnScreen: Bool
    /// Where a click on the entry goes: the host app's name, or "Activity".
    let hint: (GlanceEntry) -> String
    let open: (GlanceEntry) -> Void
    /// The counting windows, the first to reset first (LC-R6); empty draws no group.
    var limits: [GlanceCountdownWindow] = []
    /// The clock the Limits group reads.
    var now = Date()
    var openLimit: (GlanceCountdownWindow) -> Void = { _ in }

    var body: some View {
        if entries.isEmpty, limits.isEmpty {
            GlanceListSurface(width: width) { GlanceListNote(text: failure ?? note) }
        } else {
            GlanceListSurface {
                if entries.isEmpty {
                    GlanceListNote(text: failure ?? note)
                } else if let rowsHeight {
                    SpaceVibeScrollView { rows }
                        .frame(height: rowsHeight, alignment: .top)
                        .clipped()
                } else {
                    rows
                }
                if !limits.isEmpty {
                    GlanceLimitsGroup {
                        ForEach(limits) { window in
                            GlanceLimitRow(cli: window.cli, share: window.share(at: now), ringTone: window.tone.barTone, name: window.name,
                                           clock: GlanceCountdownWording.clock(window, now: now), clockTone: window.tone.textTone,
                                           detail: GlanceCountdownWording.detail(window),
                                           accessibilityName: GlanceCountdownWording.spoken(window, now: now)) { openLimit(window) }
                        }
                    }
                    .accessibilityLabel(GlanceCountdownWording.groupName)
                }
            }
        }
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let failure { GlanceListNote(text: failure) }
            ForEach(entries) { entry in
                GlanceSessionRow(cli: entry.cli, title: entry.title, detail: GlanceWording.detail(entry), state: entry.state,
                                 stateLabel: GlanceWording.label(entry.state), isAnimating: isOnScreen && failure == nil,
                                 hint: { hint(entry) }, action: { open(entry) })
            }
        }
    }
}

/// The countdown pill (LC10, LC-R5): the window that resets first, at `now`, laid out along the strip's axis. A click goes
/// through `open` (LC-R7).
struct GlanceCountdownPillView: View {
    let window: GlanceCountdownWindow
    let now: Date
    let axis: GlanceAxis
    let open: (GlanceCountdownWindow) -> Void

    var body: some View {
        GlanceCountdownPill(cli: window.cli, share: window.share(at: now), ringTone: window.tone.barTone,
                            clock: GlanceCountdownWording.clock(window, now: now), clockTone: window.tone.textTone,
                            label: GlanceCountdownWording.label(window.kind), axis: axis,
                            accessibilityName: GlanceCountdownWording.spoken(window, now: now)) { open(window) }
    }
}
