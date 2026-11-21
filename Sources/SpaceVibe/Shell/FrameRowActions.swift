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
        return marks.filter { modifiers.contains($0.0) }.map(\.1).joined() + key.uppercased()
    }

    /// What the frame's own commands hold (`FrameCommands`): ⌘1 to ⌘8, ⌘I, ⌘R, ⌘, and the two Undo keys. A row action may
    /// not take one of these.
    static let reserved: [FrameShortcut] =
        FrameCommandMap.pageShortcuts.map(\.shortcut)
        + [FrameCommandMap.inspector, FrameCommandMap.refresh, FrameCommandMap.settings, FrameCommandMap.undo, FrameCommandMap.redo]
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

    /// On a page: the selected row's actions go to the menu bar's Item menu with their shortcuts (RD39: every command is
    /// also in the menu bar). A shortcut the frame holds is dropped there (`FrameRowAction.conflicts`).
    func frameSelectedRowActions(_ actions: [FrameRowAction]) -> some View {
        focusedSceneValue(\.frameRowActions, FrameRowActionList(actions: actions))
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
