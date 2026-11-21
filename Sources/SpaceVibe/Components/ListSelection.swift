import SwiftUI

/// Arrow-key selection inside a list block (RD39, D11; RD-R16): ↑ and k move to the previous row, ↓ and j to the next,
/// clamped at the ends (no wrap, as the mock's `onKey`). Moving the selection never opens the overlay inspector and never
/// starts work (FE-I2); Return or ⌘I opens the inspector, and that stays with the frame. Pure, so `FrameBlocksTests` drives it.
enum ListSelection {
    enum Move: Hashable, Sendable {
        case previous, next

        /// The move a key stands for: the arrows and the vi letters j and k, nothing else.
        init?(key: KeyEquivalent) {
            switch key {
            case .upArrow, KeyEquivalent("k"): self = .previous
            case .downArrow, KeyEquivalent("j"): self = .next
            default: return nil
            }
        }
    }

    /// The row selected after `move` from `current` among `ids` (the rows shown, in order). Nothing selected, or a selection
    /// no longer shown, starts at the first row; an empty list selects nothing.
    static func moved(_ move: Move, from current: String?, in ids: [String]) -> String? {
        guard !ids.isEmpty else { return nil }
        guard let current, let index = ids.firstIndex(of: current) else { return ids[0] }
        let next = move == .next ? min(ids.count - 1, index + 1) : max(0, index - 1)
        return ids[next]
    }
}

extension View {
    /// Makes a list block take ↑↓ and j/k while it has the keyboard focus. `selection` is the page's selected row id;
    /// `keyboardRow` is the row that shows the focus bar, set when a key moved the selection and cleared by the pointer (the
    /// mock's `kbdId`), so a click never leaves a stray bar.
    func listKeyboardSelection(ids: [String], selection: Binding<String?>, keyboardRow: Binding<String?>) -> some View {
        modifier(ListKeyboardSelection(ids: ids, selection: selection, keyboardRow: keyboardRow))
    }
}

private struct ListKeyboardSelection: ViewModifier {
    let ids: [String]
    @Binding var selection: String?
    @Binding var keyboardRow: String?
    @FocusState private var focused: Bool

    func body(content: Content) -> some View {
        content
            .focusable()
            .focused($focused)
            .focusEffectDisabled()
            .onKeyPress(keys: [.upArrow, .downArrow, KeyEquivalent("j"), KeyEquivalent("k")]) { press in
                guard press.modifiers.isDisjoint(with: [.command, .control, .option]), let move = ListSelection.Move(key: press.key),
                      let next = ListSelection.moved(move, from: selection, in: ids) else { return .ignored }
                selection = next
                keyboardRow = next
                return .handled
            }
            .onChange(of: focused) { _, now in if !now { keyboardRow = nil } }
    }
}
