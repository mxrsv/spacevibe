import AppKit
import SwiftUI

/// The frame's menu-bar shortcuts, in one place so the reserved list (`FrameShortcut.reserved`) and the menus cannot differ.
enum FrameCommandMap {
    /// ⌘1 to ⌘8 open the pages in sidebar order (RD39), through `FrameRoute.page(forShortcut:)`.
    static let pageShortcuts: [(page: FramePage, shortcut: FrameShortcut)] = (1...FramePage.allCases.count).compactMap { number in
        guard let page = FrameRoute.page(forShortcut: number), let key = String(number).first else { return nil }
        return (page, FrameShortcut(key))
    }

    static let inspector = FrameShortcut("i")
    /// Reads every source again (`FrameStore.refresh(force:)`).
    static let refresh = FrameShortcut("r")
    static let settings = FrameShortcut(",")
    /// Focuses the page's search field (`FrameSearch.requestFocus`).
    static let find = FrameShortcut("f")
    /// The session's Undo stack (`ToastCenter`, RD39); a text field keeps its own Undo.
    static let undo = FrameShortcut("z")
    static let redo = FrameShortcut("z", modifiers: [.command, .shift])
}

/// What the menu bar acts on in the key frame window: the route, the store and the frame's view state. Published by
/// `AppFrame` as a focused scene value, so the commands work from any focus and only while a frame window is key.
struct FrameCommandTarget {
    let model: FrameModel
    let chrome: FrameChrome

    /// A page's dialog covers the window: the page, inspector, refresh, search, Undo and Item commands wait until it closes,
    /// so nothing changes behind it (RD-R16).
    @MainActor
    var isModal: Bool { chrome.isDialogOpen }
}

private struct FrameCommandTargetKey: FocusedValueKey {
    typealias Value = FrameCommandTarget
}

extension FocusedValues {
    var frameCommandTarget: FrameCommandTarget? {
        get { self[FrameCommandTargetKey.self] }
        set { self[FrameCommandTargetKey.self] = newValue }
    }
}

/// The redesign's menu-bar commands, installed only by `SpaceVibeFrameApp` (the switch on), in place of the v5
/// `ShellCommands`: Settings (⌘,), Undo and Redo, Find (⌘F), the eight pages (⌘1 to ⌘8), the inspector (⌘I), Refresh (⌘R)
/// and the Item menu with the selected row's actions (`frameSelectedRowActions`). Every one is also reachable by VoiceOver
/// and Full Keyboard Access through the menu bar.
struct FrameCommands: Commands {
    let toasts: ToastCenter
    @FocusedValue(\.frameCommandTarget) private var target
    @FocusedValue(\.frameRowActions) private var rowActions
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        let modal = target?.isModal == true
        CommandGroup(replacing: .appSettings) {
            Button("Settings\u{2026}") { openWindow(id: SettingsWindowFrame.windowID) }
                .keyboardShortcut(FrameCommandMap.settings.keyboardShortcut)
        }
        CommandGroup(replacing: .undoRedo) {
            Button("Undo") { if !modal { Self.undo(toasts) } }
                .keyboardShortcut(FrameCommandMap.undo.keyboardShortcut)
            Button("Redo") { NSApp.sendAction(Selector(("redo:")), to: nil, from: nil) }
                .keyboardShortcut(FrameCommandMap.redo.keyboardShortcut)
        }
        CommandGroup(after: .textEditing) {
            Button("Find\u{2026}") { target?.model.search.requestFocus() }
                .keyboardShortcut(FrameCommandMap.find.keyboardShortcut)
                .disabled(target?.chrome.pageHasSearch != true || modal)
        }
        CommandGroup(before: .sidebar) {
            ForEach(FrameCommandMap.pageShortcuts, id: \.page) { item in
                Button(item.page.title) { target?.model.router.open(item.page) }
                    .keyboardShortcut(item.shortcut.keyboardShortcut)
                    .disabled(target == nil || modal)
            }
            Divider()
            Button(target?.chrome.isInspectorShown == true ? "Hide Inspector" : "Show Inspector") { target?.chrome.toggleInspector() }
                .keyboardShortcut(FrameCommandMap.inspector.keyboardShortcut)
                .disabled(target?.chrome.pageHasInspector != true || modal)
            Button("Refresh") {
                guard let store = target?.model.store else { return }
                Task { await store.refresh(force: true) }
            }
            .keyboardShortcut(FrameCommandMap.refresh.keyboardShortcut)
            .disabled(target == nil || modal)
            Divider()
        }
        CommandMenu("Item") {
            let actions = modal ? [] : rowActions?.actions ?? []
            if actions.isEmpty {
                Button("No Row Selected") {}.disabled(true)
            } else {
                let clashes = Set(FrameRowAction.conflicts(in: actions))
                ForEach(actions) { action in
                    // Its key equivalent does nothing while the search field is edited; a pointer choice always acts.
                    let button = Button(action.title, role: action.isDestructive ? .destructive : nil) {
                        FramePlainKeys.performFromMenu(action, event: NSApp.currentEvent, firstResponder: NSApp.keyWindow?.firstResponder)
                    }
                        .disabled(!action.isEnabled)
                    if let shortcut = action.menuShortcut, !clashes.contains(shortcut) {
                        button.keyboardShortcut(shortcut.keyboardShortcut)
                    } else {
                        button
                    }
                }
            }
        }
    }

    /// ⌘Z: a text field being edited keeps its own Undo; otherwise the session's newest Undo (the toast's, RD39).
    @MainActor
    static func undo(_ toasts: ToastCenter) {
        if let editor = NSApp.keyWindow?.firstResponder as? NSTextView, editor.undoManager?.canUndo == true {
            editor.undoManager?.undo()
        } else if toasts.canUndoByKey {
            toasts.undoKey()
        }
    }
}
