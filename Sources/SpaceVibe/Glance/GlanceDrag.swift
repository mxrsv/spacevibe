import CoreGraphics
import Foundation

/// The left button on the strip, told apart as a click or a drag (spec `docs/specs/2026-11-19-session-glance-widget.md`,
/// GW13, GW-R6, GW-R7). Pure: the panel feeds it the pointer in global screen coordinates and acts on the step it returns.
///
/// The press is held back from the strip's content until it is decided. A release before the pointer has moved
/// `Metrics.Glance.dragThreshold` is a click: the panel hands the held press and the release to the content, which then
/// sees exactly the click it always saw (GW-R6). Past the threshold it is a drag, and the content never sees that press at
/// all, so no entry is pressed and no release can open one.
struct GlancePointerTracker: Equatable {
    enum Step: Equatable {
        /// Keep the event from the content; nothing else happens yet.
        case hold
        /// The pointer passed the threshold: the drag starts where the button went down and moves to `to`.
        case beginDrag(from: CGPoint, to: CGPoint)
        /// The drag goes on.
        case drag(to: CGPoint)
        /// The button came up after a drag.
        case drop(at: CGPoint)
        /// The button came up before the threshold: give the held press, then this release, to the content.
        case click
        /// Not part of a press on the strip: the content gets the event as usual.
        case pass
    }

    private enum Phase: Equatable {
        case idle
        case pressed(at: CGPoint)
        case dragging
    }

    private var phase = Phase.idle

    var isDragging: Bool { phase == .dragging }

    /// True once `point` is `Metrics.Glance.dragThreshold` or more from `start`.
    static func passesThreshold(from start: CGPoint, to point: CGPoint) -> Bool {
        hypot(point.x - start.x, point.y - start.y) >= Metrics.Glance.dragThreshold
    }

    /// A new press always starts over, whatever came before (a release lost to another app ends nothing twice).
    mutating func down(at point: CGPoint) -> Step {
        phase = .pressed(at: point)
        return .hold
    }

    mutating func dragged(to point: CGPoint) -> Step {
        switch phase {
        case .idle:
            return .pass
        case .pressed(let start):
            guard Self.passesThreshold(from: start, to: point) else { return .hold }
            phase = .dragging
            return .beginDrag(from: start, to: point)
        case .dragging:
            return .drag(to: point)
        }
    }

    mutating func up(at point: CGPoint) -> Step {
        defer { phase = .idle }
        switch phase {
        case .idle: return .pass
        case .pressed: return .click
        case .dragging: return .drop(at: point)
        }
    }
}

/// The widget's size in each axis (GW14), measured with its current entries when a drag starts: each slot's outline is the
/// widget as it would sit in that slot.
struct GlanceStripSizes: Equatable {
    var horizontal: CGSize
    var vertical: CGSize

    func size(for axis: GlanceAxis) -> CGSize {
        switch axis {
        case .horizontal: horizontal
        case .vertical: vertical
        }
    }
}

/// One drop slot drawn on its screen's overlay. `frame` is in the overlay's own coordinates: origin at the top left of the
/// screen's visible frame, y running down, as SwiftUI lays it out.
struct GlanceDropOutline: Equatable, Identifiable {
    let slot: GlanceSlot
    let frame: CGRect
    /// The slot a release here would pick.
    let isTarget: Bool

    var id: GlanceSlot { slot }
}

/// One drag of the widget, from the press past the threshold to the release (GW13, GW-R7). Pure geometry over the screens
/// connected when the drag started: the strip keeps the point it was grabbed at under the pointer, and the target is always
/// `GlanceSlot.nearest` to the pointer, the same rule the release uses.
struct GlanceDragSession: Equatable {
    let screens: [GlanceScreen]
    let sizes: GlanceStripSizes
    /// The pointer's distance from the strip's origin when the button went down.
    let grab: CGSize

    /// `pointer` is where the button went down, `stripFrame` the strip's frame then; both global, origin bottom left.
    init(screens: [GlanceScreen], sizes: GlanceStripSizes, pointer: CGPoint, stripFrame: CGRect) {
        self.screens = screens
        self.sizes = sizes
        grab = CGSize(width: pointer.x - stripFrame.minX, height: pointer.y - stripFrame.minY)
    }

    /// Where the strip's origin goes while the pointer is at `pointer`.
    func stripOrigin(at pointer: CGPoint) -> CGPoint {
        CGPoint(x: pointer.x - grab.width, y: pointer.y - grab.height)
    }

    /// The slot a release at `pointer` picks, highlighted while the pointer is there. Nil only with no screen.
    func target(at pointer: CGPoint) -> GlancePlacement.Resolved? {
        GlanceSlot.nearest(to: pointer, on: screens)
    }

    /// The 8 outlines of `screen`'s overlay, each sized like the widget in that slot's axis.
    func outlines(on screen: GlanceScreen, target: GlancePlacement.Resolved?) -> [GlanceDropOutline] {
        let visible = screen.visibleFrame
        return GlanceSlot.allCases.map { slot in
            let global = slot.frame(for: sizes.size(for: slot.axis), in: visible)
            let local = CGRect(x: global.minX - visible.minX, y: visible.maxY - global.maxY, width: global.width, height: global.height)
            return GlanceDropOutline(slot: slot, frame: local, isTarget: target?.screen.id == screen.id && target?.slot == slot)
        }
    }

    /// The release: the nearest slot to `pointer` becomes the saved placement (GW-R7), and is returned. With no screen nothing
    /// is saved and the widget stays where it was.
    @MainActor
    @discardableResult
    func drop(at pointer: CGPoint, into preferences: GlancePreferences) -> GlancePlacement.Resolved? {
        guard let placed = target(at: pointer) else { return nil }
        preferences.placement = placed.saved
        return placed
    }
}

/// The strip's path into its slot after a release (FE-M1): eased out, cubic, so it starts quick and settles without
/// overshoot or bounce.
enum GlanceSnap {
    /// The origin at `progress` (0 at the release, 1 in the slot; clamped to that range).
    static func origin(from start: CGPoint, to end: CGPoint, progress: Double) -> CGPoint {
        let t = min(1, max(0, progress))
        let eased = CGFloat(1 - pow(1 - t, 3))
        return CGPoint(x: start.x + (end.x - start.x) * eased, y: start.y + (end.y - start.y) * eased)
    }
}
