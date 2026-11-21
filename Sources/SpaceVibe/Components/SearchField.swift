import SwiftUI

/// The toolbar's search field (DS-R10 "Search field", regular 32, normal and focused; the mock's `srch`): the magnifying
/// glass, the text in `bodyText`, the `⌘F` hint while it is empty, on the control fill in the look's control corner. Focus is
/// the RD29 bar, never a ring (D57). Esc clears the text, and on an empty field gives the focus back. `folded` draws only
/// the icon button (the mock below an 860 pt main column) until it is pressed or ⌘F asks for it; a field with text never
/// folds. `focusRequest` changing moves the focus into it (⌘F).
struct SearchField: View {
    @Binding var text: String
    /// What VoiceOver calls it ("Search skills").
    let label: String
    var folded = false
    var focusRequest = 0

    @FocusState private var focused: Bool
    @State private var unfolded = false
    @Environment(\.materialLook) private var look
    @Environment(\.specimenInteraction) private var specimen

    var body: some View {
        if folded && text.isEmpty && !focused && !unfolded {
            Button {
                unfolded = true
                focused = true
            } label: { SpaceVibeIcon(frame: .magnifyingGlass, size: .control) }
                .buttonStyle(PushButtonStyle(.icon))
                .focusEffectDisabled()
                .help("\(label) (\u{2318}F)")
                .accessibilityLabel(label)
                .onChange(of: focusRequest) {
                    unfolded = true
                    focused = true
                }
        } else {
            field
        }
    }

    private var field: some View {
        let shape = CornerRoleShape(RadiusRole.controlCorner(look))
        let isFocused = focused || specimen.contains(.focus)
        return HStack(spacing: SpaceRole.step6) {
            FrameGlyph(.magnifyingGlass, side: SizeRole.icon16, ink: ColorRole.ink3)
            TextField(Self.placeholder, text: $text)
                .textFieldStyle(.plain)
                .typeRole(.bodyText)
                .foregroundStyle(ColorRole.ink)
                .focused($focused)
                .focusEffectDisabled()
                .accessibilityLabel(label)
            if text.isEmpty && !isFocused {
                Text(verbatim: "\u{2318}F")
                    .typeRole(.quietMedium)
                    .foregroundStyle(ColorRole.ink3)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, SpaceRole.step10)
        .frame(width: BlockRole.searchFieldWidth, height: SizeRole.controlRegular)
        .background(shape.fill(isFocused ? ColorRole.controlHoverFill : ColorRole.controlFill))
        .contentShape(shape)
        // The whole field takes the click and shows the text cursor, not only the text.
        .pointerStyle(.horizontalText)
        .focusBar(isFocused, inset: RadiusRole.controlCorner(look) == .capsule ? SizeRole.controlRegular / 2 : SpaceRole.step2)
        .onTapGesture { focused = true }
        .onExitCommand { escape() }
        .onChange(of: focusRequest) { focused = true }
        .onChange(of: focused) { _, now in if !now && text.isEmpty { unfolded = false } }
        .onAppear { if unfolded { focused = true } }
    }

    private func escape() {
        if text.isEmpty { focused = false } else { text = "" }
    }

    static let placeholder = "Search"
}

/// The list's state when the search hides every row (the mock's "not shown": "No <items> match" with Clear Search): the
/// empty state with the magnifying glass and the button that clears the field.
struct SearchNoMatchState: View {
    /// "No skills match".
    let title: String
    let text: String
    let clear: () -> Void

    var body: some View {
        PageEmptyState(icon: .magnifyingGlass, title: title, text: text) {
            Button(action: clear) { PushButtonLabel(Self.clearTitle, icon: .x, size: .small) }
                .buttonStyle(PushButtonStyle(.control, size: .small))
                .focusEffectDisabled()
        }
    }

    static let clearTitle = "Clear Search"
}
