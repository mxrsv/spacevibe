import AppKit
import SwiftUI

/// Where the window's traffic lights go in the redesign's main window (RB-F4; the mock's `.lights` at the floating sidebar's
/// top): the close button's centre at `FrameRole.trafficLightCenter` from the window's left and top edges, the other two after
/// it at the system's own spacing. Pure, so the geometry is tested without a window.
struct FrameWindowButtonsPlacement: Equatable, Sendable {
    /// The title bar container's height: twice the centre, so a button centred in it sits at the centre line.
    let titlebarHeight: CGFloat
    /// Each button's origin inside the title bar container (close, minimize, zoom). The container is not flipped, and the
    /// buttons are centred in it, so the same origin holds counted from its top or its bottom.
    let origins: [CGPoint]

    /// - `buttonSize`: the system button's size (14 pt on macOS 26 and 27).
    /// - `pitch`: the distance from one button's left edge to the next, as the system lays them out (23 pt there).
    static func make(look: MaterialLook, buttonSize: CGSize, pitch: CGFloat, count: Int = 3) -> FrameWindowButtonsPlacement {
        let center = FrameRole.trafficLightCenter(look)
        let first = CGPoint(x: center - buttonSize.width / 2, y: center - buttonSize.height / 2)
        let origins = (0..<count).map { CGPoint(x: first.x + CGFloat($0) * pitch, y: first.y) }
        return FrameWindowButtonsPlacement(titlebarHeight: center * 2, origins: origins)
    }

    /// The right edge of the last button, from the window's left edge: the toolbar with the sidebar hidden starts after it.
    func trailingEdge(buttonWidth: CGFloat) -> CGFloat { (origins.last?.x ?? 0) + buttonWidth }
}

extension View {
    /// Moves the hosting window's traffic lights to the frame's place for `look` and keeps them there through resizes,
    /// full-screen and every relayout the system makes. A headless shot draws no window, so this draws and does nothing there.
    func frameWindowButtons(look: MaterialLook) -> some View {
        background(FrameWindowButtonsAnchor(look: look).frame(width: .zero, height: .zero).accessibilityHidden(true))
    }
}

private struct FrameWindowButtonsAnchor: NSViewRepresentable {
    let look: MaterialLook

    func makeNSView(context: Context) -> FrameWindowButtonsView { FrameWindowButtonsView() }

    func updateNSView(_ view: FrameWindowButtonsView, context: Context) { view.look = look }
}

/// Puts the window's three standard buttons where `FrameWindowButtonsPlacement` says. AppKit lays the title bar out again on a
/// resize, a style change and full-screen exit and puts the buttons back at its own place, so the view watches the buttons'
/// and the title bar container's frames and places them again, once at once and once after that layout pass ends.
final class FrameWindowButtonsView: NSView {
    var look: MaterialLook = .solid {
        didSet { if look != oldValue { place() } }
    }

    private var observers: [NSObjectProtocol] = []
    private var isPlacing = false
    /// The distance between two buttons as AppKit lays them out, and where this view last put the close button.
    private var systemPitch: CGFloat?
    private var placed: CGPoint?
    private static let buttonTypes: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton]

    /// It draws nothing and takes no click: the window's background drag and the content keep every event.
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    /// Leaving the window (SwiftUI removing the view) ends the observing; a new window starts it again.
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        stopObserving()
        guard let window else { return }
        let buttons = Self.buttonTypes.compactMap { window.standardWindowButton($0) }
        let watched = buttons + [buttons.first?.superview?.superview].compactMap { $0 }
        for view in watched {
            view.postsFrameChangedNotifications = true
            observers.append(NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification, object: view,
                                                                    queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.placeNowAndAfterLayout() }
            })
        }
        for name in [NSWindow.didResizeNotification, NSWindow.didExitFullScreenNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: window, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.placeNowAndAfterLayout() }
            })
        }
        placeNowAndAfterLayout()
    }

    private func stopObserving() {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers = []
    }

    private func placeNowAndAfterLayout() {
        place()
        DispatchQueue.main.async { [weak self] in self?.place() }
    }

    /// Sets only what differs, so the frame notifications it causes end at the second pass. The frame changes it makes post
    /// notifications at once, so a pass started inside one returns at the guard: a button read half-moved would give a wrong
    /// spacing.
    private func place() {
        guard !isPlacing, let window, !window.styleMask.contains(.fullScreen) else { return }
        let buttons = Self.buttonTypes.compactMap { window.standardWindowButton($0) }
        guard buttons.count == Self.buttonTypes.count, let container = buttons[0].superview?.superview,
              let frameView = container.superview else { return }
        isPlacing = true
        defer { isPlacing = false }
        // The system's spacing, read while the buttons stand where AppKit put them (not at this view's last placement).
        if buttons[0].frame.origin != placed {
            let pitch = buttons[1].frame.minX - buttons[0].frame.minX
            if pitch > 0 { systemPitch = pitch }
        }
        guard let systemPitch else { return }
        let placement = FrameWindowButtonsPlacement.make(look: look, buttonSize: buttons[0].frame.size, pitch: systemPitch,
                                                         count: buttons.count)
        var frame = container.frame
        frame.size.height = placement.titlebarHeight
        frame.origin.y = frameView.isFlipped ? 0 : frameView.bounds.height - placement.titlebarHeight
        if container.frame != frame { container.frame = frame }
        for (button, origin) in zip(buttons, placement.origins) where button.frame.origin != origin {
            button.setFrameOrigin(origin)
        }
        placed = placement.origins.first
    }
}
