import AppKit
import SwiftUI

/// The window of a glance surface, the strip or its hover list (spec `docs/specs/2026-11-19-session-glance-widget.md`,
/// GW15, GW-R7, GW-R8). Borderless and non-activating: it never becomes key or main, so the front app keeps its focus and
/// typing is never interrupted. It is exactly the size of its SwiftUI content; its transparent corners let clicks through,
/// and the system draws its shadow, which takes no clicks.
///
/// Level `.floating`: above every normal window, and below the menu bar's level, as the plan's Approach asks (`.statusBar`
/// sits above the main menu). With `fullScreenAuxiliary` a floating panel also shows beside a full-screen app on that app's
/// Space; `canJoinAllSpaces` puts it on every Space, `stationary` keeps it in place in Mission Control, and `ignoresCycle`
/// keeps it out of Cmd-` window cycling.
final class GlancePanel: NSPanel {
    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        becomesKeyOnlyIfNeeded = true
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovable = false
        isReleasedWhenClosed = false
        animationBehavior = .none
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// The SwiftUI content of a `GlancePanel`. It takes the first click (the panel is never key, so without it a click would
/// only be swallowed), and it reports the pointer entering and leaving through a tracking area that works while SpaceVibe
/// is not the active app, which is the normal case for the widget.
final class GlanceHostingView<Content: View>: NSHostingView<Content> {
    /// The pointer entered (true) or left (false) the surface.
    var onPointer: ((Bool) -> Void)?
    private var tracking: NSTrackingArea?

    required init(rootView: Content) {
        super.init(rootView: rootView)
        // The controller sizes the window from `fittingSize`, which needs the intrinsic size; no min or max size is pushed
        // onto the window.
        sizingOptions = [.intrinsicContentSize]
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
        tracking = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        if event.trackingArea === tracking { onPointer?(true) }
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        if event.trackingArea === tracking { onPointer?(false) }
    }
}

extension GlanceScreen {
    /// The connected screens in `NSScreen.screens` order (the first has the menu bar), as the placement logic reads them.
    @MainActor
    static func connected() -> [GlanceScreen] {
        NSScreen.screens.map { screen in
            let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
            return GlanceScreen(id: GlanceScreenID(displayID: number?.uint32Value ?? 0, name: screen.localizedName),
                                visibleFrame: screen.visibleFrame)
        }
    }
}
