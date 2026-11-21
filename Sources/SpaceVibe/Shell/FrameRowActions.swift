import AppKit
import SwiftUI

/// A menu shortcut: a key and its modifiers (Command by default).
struct FrameShortcut: Hashable, Sendable, CustomStringConvertible {
    let key: Character
    let modifiers: EventModifiers

    init(_ key: Character, modifiers: EventModifiers = .command) {
        self.key = key
        self.modifiers = modifiers
    }

    var keyboardShortcut: KeyboardShortcut { KeyboardShortcut(KeyEquivalent(key), modifiers: modifiers) }

    static func == (a: FrameShortcut, b: FrameShortcut) -> Bool {
        a.key.lowercased() == b.key.lowercased() && a.modifiers.rawValue == b.modifiers.rawValue
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(key.lowercased())
        hasher.combine(modifiers.rawValue)
    }

    var description: String {
        let marks: [(EventModifiers, String)] = [(.control, "⌃"), (.option, "⌥"), (.shift, "⇧"), (.command, "⌘")]
        let glyph = key == KeyEquivalent.delete.character ? "⌫" : key.uppercased()
        return marks.filter { modifiers.contains($0.0) }.map(\.1).joined() + glyph
    }

    /// The row actions' menu shortcuts (RD-R16 Keyboard: every row action is a menu command with a shortcut), one per verb
    /// wherever it appears. Command with Shift or Option, never a plain letter, and none a text field uses for editing
    /// (⌘⌫ deletes to the line start, so Remove is ⇧⌘⌫, as Finder's Empty Trash).
    static let remove = FrameShortcut(KeyEquivalent.delete.character, modifiers: [.command, .shift])
    static let addTo = FrameShortcut("a", modifiers: [.command, .shift])
    static let changeToAsk = FrameShortcut("a", modifiers: [.command, .option])

    /// What the frame's own commands hold (`FrameCommands`): ⌘1 to ⌘8, ⌘I, ⌘R, ⌘,, ⌘F and the two Undo keys, and the plain
    /// letters the frame reads itself (RD39): j and k move the selection, Z undoes, A toggles the focused logo. A row action
    /// may not take one of these.
    static let reserved: [FrameShortcut] =
        FrameCommandMap.pageShortcuts.map(\.shortcut)
        + [FrameCommandMap.inspector, FrameCommandMap.refresh, FrameCommandMap.settings, FrameCommandMap.find,
           FrameCommandMap.undo, FrameCommandMap.redo]
        + (["j", "k", "z", "a"] as [Character]).map { FrameShortcut($0, modifiers: []) }

    /// A letter with no Command, Control or Option: it would fire inside a text field if it were a menu key equivalent.
    var isPlainKey: Bool { modifiers.isDisjoint(with: [.command, .control, .option]) }
}

/// One action on a row (RD-R16 Keyboard, R3): Keep, Remove from…, Add to…, Stop…, Copy Command. The same value becomes a
/// menu-bar command with its shortcut (while its row is selected), a context-menu item and an accessibility action on the
/// row, so a row's buttons, which Tab never reaches inside a table (RB-T0 (c)), are all reachable without a pointer.
struct FrameRowAction: Identifiable {
    /// Stable within a row: `keep`, `remove`, `addTo`, `stop`, `copyCommand`.
    let id: String
    /// The full-verb label (RD32), also the accessibility action's name.
    let title: String
    var shortcut: FrameShortcut?
    /// Drawn with the destructive role (Remove, Stop…).
    var isDestructive = false
    var isEnabled = true
    let perform: @MainActor () -> Void

    /// Shortcuts in `actions` that the frame already holds or that two actions share. Empty for a valid list.
    static func conflicts(in actions: [FrameRowAction]) -> [FrameShortcut] {
        var seen: Set<FrameShortcut> = []
        var clashes: [FrameShortcut] = []
        for shortcut in actions.compactMap(\.shortcut) {
            if FrameShortcut.reserved.contains(shortcut) || !seen.insert(shortcut).inserted { clashes.append(shortcut) }
        }
        return clashes
    }

    /// The menu-bar key equivalent: the shortcut unless it is a plain letter. A menu key equivalent fires even while a text
    /// field has the focus, so a plain letter (S for Stop) is read by the list instead (`plainKey`), never by the menu.
    var menuShortcut: FrameShortcut? {
        guard let shortcut, !shortcut.isPlainKey else { return nil }
        return shortcut
    }

    /// The enabled action whose plain-letter shortcut is `characters` (Shift alone allowed), among `actions`; nil for any
    /// other key. The frame calls it from the list's key handler only, so a text field's typing never reaches it.
    static func plainKey(_ characters: String, modifiers: EventModifiers, in actions: [FrameRowAction]) -> FrameRowAction? {
        guard modifiers.isDisjoint(with: [.command, .control, .option]), let key = characters.lowercased().first,
              characters.count == 1 else { return nil }
        return actions.first { action in
            guard let shortcut = action.shortcut, shortcut.isPlainKey, action.isEnabled else { return false }
            return shortcut.key.lowercased().first == key
        }
    }
}

/// The frame's plain-letter keys (Z for Undo, a row action's letter such as S for Stop, RD39): they act only when no text is
/// being edited. SwiftUI hands a key press to every `onKeyPress` from the focused view up to the window root before a text
/// field inserts the character, so a handler that is an ancestor of the toolbar's search field would see its typing; the
/// frame asks this first.
enum FramePlainKeys {
    /// A text field or text view has the keyboard: the window's first responder is AppKit's field editor (an `NSText`).
    static func isEditingText(_ firstResponder: NSResponder?) -> Bool { firstResponder is NSText }

    /// Whether Z may undo now: no modifier, no dialog over the window, no text being edited.
    static func undoMayAct(modifiers: EventModifiers, isModal: Bool, firstResponder: NSResponder?) -> Bool {
        modifiers.isEmpty && !isModal && !isEditingText(firstResponder)
    }

    /// Whether a row action's plain letter may act now: no dialog, no text being edited (the modifiers are
    /// `FrameRowAction.plainKey`'s to judge).
    static func rowLetterMayAct(isModal: Bool, firstResponder: NSResponder?) -> Bool {
        !isModal && !isEditingText(firstResponder)
    }
}

/// The selected row's actions as the menu bar reads them.
struct FrameRowActionList {
    let actions: [FrameRowAction]
}

private struct FrameRowActionsKey: FocusedValueKey {
    typealias Value = FrameRowActionList
}

extension FocusedValues {
    /// The actions of the row selected on the page showing, published by the page (`frameSelectedRowActions`).
    var frameRowActions: FrameRowActionList? {
        get { self[FrameRowActionsKey.self] }
        set { self[FrameRowActionsKey.self] = newValue }
    }
}

extension View {
    /// On a row: its actions as context-menu items and as accessibility actions (R3).
    func frameRowActions(_ actions: [FrameRowAction]) -> some View {
        modifier(FrameRowActionsModifier(actions: actions))
    }

    /// The selected row's actions go to the menu bar's Item menu with their shortcuts (RD39: every command is also in the
    /// menu bar). A shortcut the frame holds is dropped there (`FrameRowAction.conflicts`). Nil publishes nothing, so every
    /// row can carry it and only the selected one fills the menu (`FrameItemRow`).
    func frameSelectedRowActions(_ actions: [FrameRowAction]?) -> some View {
        focusedSceneValue(\.frameRowActions, actions.map(FrameRowActionList.init(actions:)))
    }
}

extension FrameRowAction {
    /// The button it is on the selected row: the red tint for Remove and Stop, a neutral control otherwise (FE-E2).
    var buttonKind: PushButtonStyle.Kind { isDestructive ? .destructive : .control }

    /// The button's tooltip: the title, with the menu shortcut when it has one ("Keep (⌘K)").
    var tooltip: String { shortcut.map { "\(title) (\($0))" } ?? title }
}

/// A row of a list or table with its actions given once (RD-R16 Keyboard, R3): `ItemRow` with `actions` as small buttons on
/// the selected row (RD41), the same list as the row's context-menu items and accessibility actions, and, while the row is
/// selected, as the menu bar's Item menu with their shortcuts. A page builds one `[FrameRowAction]` per row and hands it
/// here, so the four places cannot drift. Below 1100 pt the page repeats the selected row's list in the overlay inspector
/// with `FrameRowActionButtons` (`FramePageContent.overlayActions`).
struct FrameItemRow<Content: View>: View {
    typealias Check = ItemRow<Content, FrameRowActionButtons>.Check

    let label: String
    var height: ItemRowHeight = .table
    var isSelected = false
    var isKeyboardFocused = false
    var check: Check?
    let actions: [FrameRowAction]
    let select: () -> Void
    @ViewBuilder var content: Content

    init(label: String, height: ItemRowHeight = .table, isSelected: Bool = false, isKeyboardFocused: Bool = false,
         check: Check? = nil, actions: [FrameRowAction], select: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.label = label
        self.height = height
        self.isSelected = isSelected
        self.isKeyboardFocused = isKeyboardFocused
        self.check = check
        self.actions = actions
        self.select = select
        self.content = content()
    }

    var body: some View {
        ItemRow(label: label, height: height, isSelected: isSelected, isKeyboardFocused: isKeyboardFocused, check: check,
                select: select) { content } actions: { FrameRowActionButtons(actions: actions) }
            .frameRowActions(actions)
            .frameSelectedRowActions(isSelected ? actions : nil)
    }
}

/// A row's actions as buttons, in the list's order: on the selected row (`FrameItemRow`) and at the overlay inspector's top.
struct FrameRowActionButtons: View {
    let actions: [FrameRowAction]

    var body: some View {
        ForEach(actions) { action in
            Button(action.title) { action.perform() }
                .buttonStyle(PushButtonStyle(action.buttonKind, size: .small))
                .focusEffectDisabled()
                .disabled(!action.isEnabled)
                .help(action.tooltip)
        }
    }
}

private struct FrameRowActionsModifier: ViewModifier {
    let actions: [FrameRowAction]

    func body(content: Content) -> some View {
        content
            .contextMenu {
                ForEach(actions) { action in
                    Button(action.title, role: action.isDestructive ? .destructive : nil) { action.perform() }
                        .disabled(!action.isEnabled)
                }
            }
            .accessibilityActions {
                ForEach(actions.filter(\.isEnabled)) { action in
                    Button(action.title) { action.perform() }
                }
            }
    }
}
