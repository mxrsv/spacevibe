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
    /// True from the press until its release (or `cancel()`): a held press or a drag.
    var isActive: Bool { phase != .idle }

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

    /// Forgets the press without a click or a drop: its release never came (`GlanceLostRelease`), or the widget left the
    /// screen. Returns true when a drag was in progress, so the caller can end it.
    @discardableResult
    mutating func cancel() -> Bool {
        defer { phase = .idle }
        return phase == .dragging
    }
}

/// Holds the strip's renders back while a press on it is undecided or dragging (GW-R6). The panel replays a held press and
/// its release to the content once they make a click, so the content must still be the one the press went down on: a
/// report that redrew the strip in between would hand the click to whatever entry sits there now. Pure; the controller asks
/// `admit` before each render and runs the one it returns from `release`.
struct GlanceRenderGate: Equatable {
    private(set) var isHeld = false
    /// The render asked for while held, with its snap flag (a release asks for the snap); nil when none was asked.
    private(set) var deferred: Bool?

    mutating func hold() {
        isHeld = true
    }

    /// True when the render may run now. While held it is noted instead, and a snap asked for once stays asked for.
    mutating func admit(snap: Bool) -> Bool {
        guard isHeld else { return true }
        deferred = (deferred ?? false) || snap
        return false
    }

    /// The press is over: returns the render to run now (its snap flag), nil when none was asked for while held. The render
    /// reads the state at that moment, so the latest report is the one drawn.
    mutating func release() -> Bool? {
        defer { self = GlanceRenderGate() }
        return deferred
    }
}

/// A press whose release the strip never received: the window server lost it, the screen locked, or another app took the
/// button. While a press is held the controller reads `NSEvent.pressedMouseButtons` every `checkInterval`; the press ends
/// after `upReadings` readings in a row with the left button up. One reading is not enough: the button can already be up
/// while its release still waits in the event queue, and ending the press then would turn that click into nothing.
struct GlanceLostRelease: Equatable {
    static let checkInterval: Duration = .milliseconds(250)
    static let upReadings = 2

    private var ups = 0

    /// One reading; true when the press should end now.
    mutating func observe(leftButtonDown: Bool) -> Bool {
        ups = leftButtonDown ? 0 : ups + 1
        return ups >= Self.upReadings
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
