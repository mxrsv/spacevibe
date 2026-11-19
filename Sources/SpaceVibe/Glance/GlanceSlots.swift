import CoreGraphics
import Foundation

/// Where the glance widget may sit (spec `docs/specs/2026-11-19-session-glance-widget.md`, GW13, GW14, GW16, GW-R7).
///
/// Pure geometry in AppKit's global screen coordinates: the origin is at the bottom left, so "top" is `maxY`. Every frame
/// comes from a screen's `visibleFrame`, which already leaves out the menu bar and the Dock, so the widget and its list
/// never cover them (GW-R8). No window code lives here; the panel asks these types and only draws.
enum GlanceLayout {
    /// The widget's distance from the edges of the visible frame, and what the hover list keeps from them too.
    static let margin: CGFloat = Space.s12
    /// Between the widget and the hover list that opens from it.
    static let listGap: CGFloat = Space.s6
}

/// How the widget's entries run (GW14): stacked on the left and right edge middles, in a row everywhere else.
enum GlanceAxis: Equatable {
    case horizontal
    case vertical
}

/// Where the hover list opens from the widget: always toward the screen centre (GW14).
enum GlanceListDirection: Equatable {
    case down
    case up
    case right
    case left
}

/// One of the 8 drop slots of a screen (GW13): four corners and the middle of each edge. The raw values are what is
/// saved, so they never change.
enum GlanceSlot: String, Codable, CaseIterable {
    case topLeft
    case topCenter
    case topRight
    case leftMiddle
    case rightMiddle
    case bottomLeft
    case bottomCenter
    case bottomRight

    /// The slot of a first launch (GW16).
    static let defaultSlot: GlanceSlot = .bottomRight

    private enum Column { case left, center, right }
    private enum Row { case top, middle, bottom }

    private var column: Column {
        switch self {
        case .topLeft, .leftMiddle, .bottomLeft: .left
        case .topCenter, .bottomCenter: .center
        case .topRight, .rightMiddle, .bottomRight: .right
        }
    }

    private var row: Row {
        switch self {
        case .topLeft, .topCenter, .topRight: .top
        case .leftMiddle, .rightMiddle: .middle
        case .bottomLeft, .bottomCenter, .bottomRight: .bottom
        }
    }

    var axis: GlanceAxis { row == .middle ? .vertical : .horizontal }

    var listDirection: GlanceListDirection {
        switch row {
        case .top: .down
        case .bottom: .up
        case .middle: column == .left ? .right : .left
        }
    }

    /// The point the widget is pinned to: the slot's corner or edge middle, `GlanceLayout.margin` inside the visible frame.
    func anchor(in visibleFrame: CGRect) -> CGPoint {
        let inner = visibleFrame.insetBy(dx: GlanceLayout.margin, dy: GlanceLayout.margin)
        let x: CGFloat = switch column {
        case .left: inner.minX
        case .center: inner.midX
        case .right: inner.maxX
        }
        let y: CGFloat = switch row {
        case .top: inner.maxY
        case .middle: inner.midY
        case .bottom: inner.minY
        }
        return CGPoint(x: x, y: y)
    }

    /// The widget's frame in this slot: its matching corner or edge middle sits on `anchor(in:)`.
    func frame(for size: CGSize, in visibleFrame: CGRect) -> CGRect {
        let anchor = anchor(in: visibleFrame)
        let x: CGFloat = switch column {
        case .left: anchor.x
        case .center: anchor.x - size.width / 2
        case .right: anchor.x - size.width
        }
        let y: CGFloat = switch row {
        case .top: anchor.y - size.height
        case .middle: anchor.y - size.height / 2
        case .bottom: anchor.y
        }
        return CGRect(origin: CGPoint(x: x, y: y), size: size)
    }

    /// The hover list's frame for a widget at `widgetFrame` in this slot (GW14, GW-R5). It opens `GlanceLayout.listGap`
    /// away from the widget toward the centre. A corner's list lines up with the widget's outer side, an edge middle's
    /// list is centred on the widget. The result stays `GlanceLayout.margin` inside the visible frame and never overlaps
    /// the widget: the side it opens on is shortened to the room there, the other side is shortened to the screen and
    /// slid inside it. The caller reads the returned size as the room the list has.
    func listFrame(for size: CGSize, widgetFrame: CGRect, in visibleFrame: CGRect) -> CGRect {
        let inner = visibleFrame.insetBy(dx: GlanceLayout.margin, dy: GlanceLayout.margin)
        let gap = GlanceLayout.listGap
        switch listDirection {
        case .down, .up:
            let room = listDirection == .down ? widgetFrame.minY - gap - inner.minY : inner.maxY - widgetFrame.maxY - gap
            let height = max(0, min(size.height, room))
            let y = listDirection == .down ? widgetFrame.minY - gap - height : widgetFrame.maxY + gap
            let width = min(size.width, inner.width)
            let x: CGFloat = switch column {
            case .left: widgetFrame.minX
            case .center: widgetFrame.midX - width / 2
            case .right: widgetFrame.maxX - width
            }
            return CGRect(x: Self.clamp(x, length: width, within: inner.minX...inner.maxX), y: y,
                          width: width, height: height)
        case .right, .left:
            let room = listDirection == .right ? inner.maxX - widgetFrame.maxX - gap : widgetFrame.minX - gap - inner.minX
            let width = max(0, min(size.width, room))
            let x = listDirection == .right ? widgetFrame.maxX + gap : widgetFrame.minX - gap - width
            let height = min(size.height, inner.height)
            let y = widgetFrame.midY - height / 2
            return CGRect(x: x, y: Self.clamp(y, length: height, within: inner.minY...inner.maxY),
                          width: width, height: height)
        }
    }

    /// The nearest slot to `point` (the pointer where the drag ends) over every connected screen (GW13), by distance to
    /// each slot's anchor. Ties keep the earlier screen, then the earlier slot in `allCases`. Nil only with no screen.
    static func nearest(to point: CGPoint, on screens: [GlanceScreen]) -> GlancePlacement.Resolved? {
        let candidates = screens.flatMap { screen in allCases.map { GlancePlacement.Resolved(screen: screen, slot: $0) } }
        // `min(by:)` keeps the first of equal elements, which gives the tie order above.
        return candidates.min { distance(from: point, to: $0) < distance(from: point, to: $1) }
    }

    private static func distance(from point: CGPoint, to placement: GlancePlacement.Resolved) -> CGFloat {
        let anchor = placement.slot.anchor(in: placement.screen.visibleFrame)
        return hypot(anchor.x - point.x, anchor.y - point.y)
    }

    /// `origin` moved so `origin ... origin + length` sits inside `range`; a length larger than the range starts at its
    /// lower end.
    private static func clamp(_ origin: CGFloat, length: CGFloat, within range: ClosedRange<CGFloat>) -> CGFloat {
        max(range.lowerBound, min(origin, range.upperBound - length))
    }
}

/// A screen as it survives a relaunch: the caller fills it from `NSScreen` (`CGDirectDisplayID` from `deviceDescription`
/// and `localizedName`). Never an `NSScreen` reference.
struct GlanceScreenID: Codable, Hashable {
    var displayID: UInt32
    var name: String
}

/// A connected screen as the placement logic sees it.
struct GlanceScreen: Equatable {
    var id: GlanceScreenID
    /// `NSScreen.visibleFrame`, global coordinates, origin bottom left.
    var visibleFrame: CGRect
}

/// The saved slot (GW-R7): which screen and which of its 8 slots.
struct GlancePlacement: Codable, Equatable {
    var screen: GlanceScreenID
    var slot: GlanceSlot

    /// A placement on a screen that is connected now.
    struct Resolved: Equatable {
        var screen: GlanceScreen
        var slot: GlanceSlot

        var saved: GlancePlacement { GlancePlacement(screen: screen.id, slot: slot) }
    }

    /// Where the widget goes at launch. `screens` is `NSScreen.screens` in its order, so the first is the main screen (the
    /// one with the menu bar). A saved screen is found by display id, then by name (an external display can come back
    /// with a new id). A saved screen that is gone keeps its slot on the main screen ("Inferred, not decided" in the spec);
    /// nothing saved is bottom right on the main screen (GW16). Nil only with no screen.
    static func resolve(_ saved: GlancePlacement?, screens: [GlanceScreen]) -> Resolved? {
        guard let main = screens.first else { return nil }
        guard let saved else { return Resolved(screen: main, slot: GlanceSlot.defaultSlot) }
        let match = screens.first { $0.id.displayID == saved.screen.displayID }
            ?? screens.first { $0.id.name == saved.screen.name }
        return Resolved(screen: match ?? main, slot: saved.slot)
    }
}
