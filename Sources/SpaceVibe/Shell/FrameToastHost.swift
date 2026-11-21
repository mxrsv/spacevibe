import SwiftUI

/// Which block draws a toast of the one `ToastCenter` in the frame (AR4): a write's `WriteToast`, or the core's refusal as a
/// `RefusedWriteToast`. Pure, so the mapping is tested without a window.
enum FrameToastKind: Equatable, Sendable {
    /// An accepted write (or a plain notice): the ok check and the toast's one action, Undo after a write.
    case write(action: String?)
    /// A refused write (`ToastTone.danger`): "Nothing changed." first, 3 lines with Details, and Dismiss.
    case refused(action: String?)
    /// A write that did part of what was asked (`ToastTone.partial`): the attention glyph, its sentence, Undo for what
    /// changed, and Dismiss (the mock's `failToast` with `partial`).
    case partial(action: String?)

    init(_ toast: Toast) {
        switch toast.tone {
        case .info: self = .write(action: toast.action?.title)
        case .danger: self = .refused(action: toast.action?.title)
        case .partial: self = .partial(action: toast.action?.title)
        }
    }

    /// A refusal or a partial write stays until it is dismissed (RD-R17); a write's toast times out, paused while the
    /// pointer is on it.
    var staysUntilDismissed: Bool {
        switch self {
        case .refused, .partial: true
        case .write: false
        }
    }

    /// Undo carries its arrow; any other action is its verb alone.
    static func icon(for action: String?) -> FrameIcon? {
        action == ToastText.undoTitle ? .arrowCounterClockwise : nil
    }
}

/// Draws the current toast at the bottom centre of the frame window (the mock's `.toast`: 20 above the bottom edge, at most
/// 620 wide and 160 clear of each window edge, so Undo is never pushed out of the window, RD-R17). Mounted once at the frame
/// root by `AppFrame`, beside the v5 `ToastHost`, which only `AppShell` mounts. Undo is in reach three ways: the toast's
/// button, Z (`AppFrame`) and ⌘Z (`FrameCommands`), all on the center's one stack (RD39).
///
/// While mounted it tells the center not to announce (`ToastCenter.hostAnnounces`): each block announces its own sentence
/// with the action it offers, a refusal at high priority (RD-R16), so VoiceOver hears it once.
struct FrameToastHost: View {
    @Environment(ToastCenter.self) private var toasts
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            if let toast = toasts.current {
                block(for: toast)
                    .padding(.horizontal, BlockRole.toastWindowMargin)
                    .padding(.bottom, SpaceRole.step20)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                    .id(toast.id)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(reduceMotion ? nil : .easeOut(duration: MotionRole.toastSlideDuration), value: toasts.current?.id)
        .allowsHitTesting(toasts.current != nil)
        .onAppear { toasts.hostAnnounces = true }
        .onDisappear { toasts.hostAnnounces = false }
    }

    @ViewBuilder
    private func block(for toast: Toast) -> some View {
        let kind = FrameToastKind(toast)
        switch kind {
        case .write(let action):
            WriteToast(message: toast.message, undo: action.map { _ in { toasts.runCurrentAction() } },
                       actionTitle: action ?? ToastText.undoTitle, actionIcon: FrameToastKind.icon(for: action))
                .onHover { $0 ? toasts.hold() : toasts.release() }
        case .refused(let action), .partial(let action):
            RefusedWriteToast(message: toast.message, isPartial: kind == .partial(action: action), actionTitle: action,
                              actionIcon: FrameToastKind.icon(for: action),
                              action: action.map { _ in { toasts.runCurrentAction() } },
                              dismiss: { toasts.dismiss(id: toast.id) })
                .onAppear { if kind.staysUntilDismissed { toasts.hold() } }
        }
    }
}
