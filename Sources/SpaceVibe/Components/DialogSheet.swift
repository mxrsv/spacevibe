import SwiftUI

/// The rows a dialog lists (RD-R16 "Dialogs"): at most 5, then "and N more <noun>s", so the buttons always stay in reach.
/// Pure.
struct CappedList<Item> {
    let shown: [Item]
    let hiddenCount: Int

    init(_ items: [Item], limit: Int = DialogCap.rows) {
        let cap = max(0, limit)
        shown = Array(items.prefix(cap))
        hiddenCount = max(0, items.count - cap)
    }

    /// "and 3 more items", "and 1 more session"; nil when nothing is hidden.
    func moreLine(one: String, many: String? = nil) -> String? {
        hiddenCount > 0 ? "and \(NumberWording.count(hiddenCount)) more \(hiddenCount == 1 ? one : many ?? one + "s")" : nil
    }
}

enum DialogCap {
    /// The most rows a dialog lists (RD-R16).
    static let rows = 5
}

/// The shell of the per-CLI sheet and the remove confirmation (DS-R10 "sheet"; the mock's `.scrim` and `.alert.sheet`): the
/// scrim over the window, a 392 wide card with its title centred, the content, a note, and the buttons stacked full width
/// with Cancel first. Cancel is the default (Return) and Esc or a click on the scrim cancels; the focus moves into the
/// sheet when it opens and the caller gives it back to the control that opened it (RD-R16). While `isWorking`, nothing
/// closes it and the buttons are disabled.
struct DialogSheet<Content: View, Confirm: View>: View {
    let title: String
    var note: String?
    var isWorking = false
    let cancel: () -> Void
    @ViewBuilder var content: Content
    /// The confirming button(s), below Cancel.
    @ViewBuilder var confirm: Confirm

    @AccessibilityFocusState private var titleFocused: Bool

    init(title: String, note: String? = nil, isWorking: Bool = false, cancel: @escaping () -> Void,
         @ViewBuilder content: () -> Content, @ViewBuilder confirm: () -> Confirm) {
        self.title = title
        self.note = note
        self.isWorking = isWorking
        self.cancel = cancel
        self.content = content()
        self.confirm = confirm()
    }

    var body: some View {
        ZStack {
            ColorRole.scrimFill
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { if !isWorking { cancel() } }
                .pointerStyle(.default)
                .accessibilityHidden(true)
            card
        }
        .onExitCommand { if !isWorking { cancel() } }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: SpaceRole.step6) {
            Text(title)
                .typeRole(.bodyMedium)
                .foregroundStyle(ColorRole.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.top, SpaceRole.step8)
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($titleFocused)
            content
            if let note {
                Text(note)
                    .typeRole(.quiet)
                    .foregroundStyle(ColorRole.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(spacing: SpaceRole.step8) {
                Button(action: cancel) { Text("Cancel").frame(maxWidth: .infinity) }
                    .buttonStyle(PushButtonStyle(.control))
                    .keyboardShortcut(.defaultAction)
                    .focusEffectDisabled()
                confirm
            }
            .disabled(isWorking)
            .padding(.top, SpaceRole.step12)
        }
        .padding(.horizontal, SpaceRole.step20)
        .padding(.top, SpaceRole.step20)
        .padding(.bottom, SpaceRole.step16)
        .frame(width: BlockRole.sheetWidth)
        .overlayPanelSurface()
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityLabel(title)
        .onAppear { titleFocused = true }
    }
}

/// One line of a dialog's list (the mock's `.pk`): an optional lead (a checkbox, a logo, a kind icon), a name in
/// `bodyMedium` cut in the middle, and a quiet line under it (a folder in mono, or who reads it).
struct DialogListLine<Lead: View>: View {
    let name: String
    var detail: String?
    var detailIsPath = false
    var isEnabled = true
    @ViewBuilder var lead: Lead

    var body: some View {
        HStack(alignment: .top, spacing: SpaceRole.step10) {
            lead
            VStack(alignment: .leading, spacing: SpaceRole.step2) {
                MiddleTruncatedText(name)
                    .typeRole(.bodyMedium)
                    .foregroundStyle(ColorRole.ink)
                if let detail {
                    Text(detail)
                        .typeRole(detailIsPath ? .mono : .quiet)
                        .foregroundStyle(ColorRole.ink3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .opacity(isEnabled ? 1 : OpacityRole.disabled)
        .accessibilityElement(children: .combine)
    }
}

/// The quiet "and N more" line under a capped list.
struct DialogMoreLine: View {
    let text: String

    var body: some View {
        Text(text).typeRole(.quiet).foregroundStyle(ColorRole.ink3)
    }
}
