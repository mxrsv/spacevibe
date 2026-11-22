import Foundation
import SwiftUI
import Testing
@testable import SpaceVibe

/// The redesign's frame (RB-S3): the menu-bar shortcuts, the 1100 pt inspector rule, the Glass/Solid decision, the scenes
/// each app declares, the sidebar's values and the row-action registration.
@Suite("Redesign frame")
@MainActor
struct AppFrameTests {
    // MARK: Commands (RD39)

    @Test("⌘1 to ⌘8 follow the sidebar order, which is FramePage's order and its groups' order")
    func pageShortcuts() {
        #expect(FrameCommandMap.pageShortcuts.map(\.page) == FramePage.allCases)
        #expect(FrameCommandMap.pageShortcuts.map(\.shortcut) == (1...8).map { FrameShortcut(Character(String($0))) })
        #expect(FramePage.SidebarGroup.allCases.flatMap(\.pages) == FramePage.allCases)
        #expect(FramePage.SidebarGroup.allCases.map(\.title) == ["Triage", "Agents", "Watch"])
        #expect(FramePage.SidebarGroup.agents.pages == [.skills, .subagents, .hooks, .rules])
    }

    @Test("the frame's own shortcuts are distinct and reserved: ⌘1–⌘8, ⌘I, ⌘R, ⌘, and the Undo keys")
    func reservedShortcuts() {
        let reserved = FrameShortcut.reserved
        #expect(Set(reserved).count == reserved.count)
        #expect(reserved.contains(FrameShortcut("i")) && reserved.contains(FrameShortcut("r")) && reserved.contains(FrameShortcut(",")))
        #expect(reserved.contains(FrameShortcut("z")) && reserved.contains(FrameShortcut("Z", modifiers: [.command, .shift])))
        #expect(FrameShortcut("k", modifiers: [.command, .shift]).description == "⇧⌘K")
    }

    @Test("a row action may not take a frame shortcut or another action's shortcut")
    func rowActionConflicts() {
        func action(_ id: String, _ shortcut: FrameShortcut?) -> FrameRowAction {
            FrameRowAction(id: id, title: id, shortcut: shortcut) {}
        }
        let fine = [action("keep", FrameShortcut("k")), action("remove", FrameShortcut("\u{8}")), action("copy", nil)]
        #expect(FrameRowAction.conflicts(in: fine).isEmpty)
        #expect(FrameRowAction.conflicts(in: [action("keep", FrameShortcut("3"))]) == [FrameShortcut("3")])
        #expect(FrameRowAction.conflicts(in: [action("a", FrameShortcut("e")), action("b", FrameShortcut("E"))]) == [FrameShortcut("e")])
        #expect(FrameRowAction.conflicts(in: [action("a", FrameShortcut("e", modifiers: []))]).isEmpty)
    }

    // MARK: Inspector (RD-R13)

    @Test("below 1100 pt the inspector is an overlay that starts closed; from 1100 pt it is docked and shown")
    func overlayThreshold() {
        let state = FrameInspectorState()
        #expect(FrameInspectorState.isOverlayWidth(1099.5))
        #expect(!FrameInspectorState.isOverlayWidth(1100))
        #expect(state.presentation(windowWidth: 1280, pageHasInspector: true) == .docked)
        #expect(state.presentation(windowWidth: 1000, pageHasInspector: true) == .hidden)
        #expect(state.presentation(windowWidth: 1280, pageHasInspector: false) == .hidden)
        #expect(state.opened(windowWidth: 1000).presentation(windowWidth: 1000, pageHasInspector: true) == .overlay)
        #expect(state.opened(windowWidth: 1000).presentation(windowWidth: 1000, pageHasInspector: false) == .hidden)
    }

    @Test("the toolbar button and ⌘I toggle at any width; a row click or Return opens; Esc closes only the overlay")
    func inspectorTransitions() {
        let narrow: CGFloat = 1000, wide: CGFloat = 1280
        let open = FrameInspectorState().toggled(windowWidth: narrow)
        #expect(open.presentation(windowWidth: narrow, pageHasInspector: true) == .overlay)
        #expect(open.toggled(windowWidth: narrow).presentation(windowWidth: narrow, pageHasInspector: true) == .hidden)
        #expect(open.closingOverlay().presentation(windowWidth: narrow, pageHasInspector: true) == .hidden)
        let hidden = FrameInspectorState().toggled(windowWidth: wide)
        #expect(hidden.presentation(windowWidth: wide, pageHasInspector: true) == .hidden)
        #expect(hidden.opened(windowWidth: wide).presentation(windowWidth: wide, pageHasInspector: true) == .docked)
        #expect(FrameInspectorState().closingOverlay().presentation(windowWidth: wide, pageHasInspector: true) == .docked,
                "Esc never hides a docked inspector")
    }

    @Test("the chrome closes the overlay when the window crosses 1100 pt and when the page changes; Esc reports what it closed")
    func chrome() {
        let chrome = FrameChrome()
        chrome.pageHasInspector = true
        chrome.setWindowWidth(1000)
        #expect(!chrome.closeOverlays(), "nothing open: the key goes on")
        chrome.openInspector()
        #expect(chrome.presentation == .overlay)
        chrome.setWindowWidth(1300)
        #expect(chrome.presentation == .docked)
        chrome.setWindowWidth(1000)
        #expect(chrome.presentation == .hidden, "crossing the line closed the overlay")
        chrome.openInspector()
        chrome.isHelpOpen = true
        chrome.keyboardRow = "a"
        chrome.pageChanged()
        #expect(chrome.presentation == .hidden && !chrome.isHelpOpen && chrome.keyboardRow == nil)
        chrome.isHelpOpen = true
        #expect(chrome.closeOverlays() && !chrome.isHelpOpen)
    }

    @Test("the frame's arrow keys move the route's selection by ListSelection; a click clears the focus bar")
    func keyboardSelection() {
        let router = FrameRouter(FrameRoute(page: .skills))
        let chrome = FrameChrome()
        let rows = ["a", "b", "c"]
        // What `frameListKeys` does on ↓ twice and ↑ once: the one rule, written into the route and the keyboard row.
        for move in [ListSelection.Move.next, .next, .previous] {
            let next = ListSelection.moved(move, from: router.route.selection, in: rows)
            router.select(next)
            chrome.keyboardRow = next
        }
        #expect(router.route.selection == "a" && chrome.keyboardRow == "a")
        #expect(router.route.page == .skills, "selecting never changes the page (AR5)")
        chrome.pointerSelected()
        #expect(chrome.keyboardRow == nil && router.route.selection == "a")
    }

    // MARK: Toasts (AR4, RD-R16, RD-R17)

    @Test("the frame draws a write's toast with its action, a refusal as the refused toast that stays until dismissed")
    func toastKinds() {
        let undo = Toast(message: "Removed ponytail", tone: .info, action: .undo {})
        let plain = Toast(message: "Stopped", tone: .info, action: nil)
        let view = Toast(message: "SpaceVibe 0.2.0 is available", tone: .info, action: ToastAction(title: "View") {})
        let refused = Toast(message: "Couldn't remove x. Nothing changed.", tone: .danger, action: nil)
        #expect(FrameToastKind(undo) == .write(action: "Undo"))
        #expect(FrameToastKind(plain) == .write(action: nil))
        #expect(FrameToastKind(view) == .write(action: "View"))
        #expect(FrameToastKind(refused) == .refused(action: nil))
        #expect(FrameToastKind(refused).staysUntilDismissed && !FrameToastKind(undo).staysUntilDismissed)
        #expect(FrameToastKind.icon(for: "Undo") == .arrowCounterClockwise)
        #expect(FrameToastKind.icon(for: "View") == nil && FrameToastKind.icon(for: nil) == nil)
        #expect(ToastText.spoken("Removed ponytail", action: "Undo") == "Removed ponytail. Undo available.")
        #expect(ToastText.spoken("Stopped", action: nil) == "Stopped")
    }

    @Test("while the frame's host announces, the center stays quiet; the v5 host leaves it to the center")
    func toastAnnouncer() {
        let toasts = ToastCenter(announce: false)
        #expect(!toasts.hostAnnounces, "v5 default: the center announces")
        toasts.hostAnnounces = true
        toasts.show("Removed ponytail") {}
        #expect(toasts.current?.message == "Removed ponytail" && toasts.canUndoByKey, "the toast and its Undo are unchanged")
    }

    // MARK: Row actions (RD-R16, R3)

    @Test("a row action is a red-tint button when destructive, a control otherwise, with its shortcut in the tooltip")
    func rowActionButtons() {
        let keep = FrameRowAction(id: "keep", title: "Keep", shortcut: FrameShortcut("k")) {}
        let remove = FrameRowAction(id: "remove", title: "Remove from…", isDestructive: true) {}
        #expect(keep.buttonKind == .control && remove.buttonKind == .destructive)
        #expect(keep.tooltip == "Keep (⌘K)" && remove.tooltip == "Remove from…")
    }

    // MARK: Material (AR8, DS-R8)

    @Test("Glass only with the system material and Reduce Transparency off", arguments: [
        (true, false, MaterialLook.glass), (true, true, .solid), (false, false, .solid), (false, true, .solid),
    ])
    func materialDecision(glassAvailable: Bool, reduceTransparency: Bool, look: MaterialLook) {
        #expect(MaterialLook.decide(glassAvailable: glassAvailable, reduceTransparency: reduceTransparency) == look)
    }

    @Test("a view outside the frame root is Solid, and the frame's look metrics follow the look")
    func materialDefaults() {
        #expect(EnvironmentValues().materialLook == .solid)
        #expect(FrameRole.sidebarWidth(.glass) == 240 && FrameRole.sidebarWidth(.solid) == 224)
        #expect(FrameRole.toolbarHeight(.glass) == 60 && FrameRole.toolbarHeight(.solid) == 52)
        #expect(FrameRole.toolbarHeight(.glass) < SpaceRole.toolbarClearance(.glass))
        #expect(FrameRole.toolbarHeight(.solid) < SpaceRole.toolbarClearance(.solid))
    }

    // MARK: Scenes (AR8)

    @Test("the Settings window and the frame's commands exist only in the app the switch starts")
    func sceneGating() {
        #expect(ObjectIdentifier(SpaceVibeApp.app(for: .v5)) == ObjectIdentifier(SpaceVibeApp.self))
        #expect(ObjectIdentifier(SpaceVibeApp.app(for: .redesign)) == ObjectIdentifier(SpaceVibeFrameApp.self))
        #expect(SpaceVibeApp.sceneIDs == [SpaceVibeApp.mainWindowID])
        #expect(SpaceVibeFrameApp.sceneIDs == [SpaceVibeApp.mainWindowID, SettingsWindowFrame.windowID, JournalWindow.windowID])
        // A distribution build never reaches the frame app.
        #expect(LaunchMode.surface(environment: ["SPACEVIBE_REDESIGN": "1"], isDevelopmentBuild: false) == .v5)
        #expect(SettingsPane.allCases.map(\.title) == ["General", "CLIs", "Limits", "Data", "Updates"])
    }

    // MARK: Sidebar values (AR3, RD10, RD-R16)

    @Test("the sidebar shows the page's figure as neutral text; only Inbox carries a severity glyph")
    func sidebarValues() {
        #expect(FrameSidebarValue(figure: .count(11, tone: .critical), page: .inbox, criticalCount: 2)
            == FrameSidebarValue(text: "11", mark: .critical, criticalCount: 2))
        #expect(FrameSidebarValue(figure: .count(3, tone: .attention), page: .skills) == FrameSidebarValue(text: "3"))
        #expect(FrameSidebarValue(figure: .count(0, tone: nil), page: .inbox).mark == nil)
        #expect(FrameSidebarValue(figure: .pending, page: .skills).text == "\u{2026}")
        #expect(FrameSidebarValue(figure: .pending, page: .clean).text == "Measuring")
        #expect(FrameSidebarValue(figure: .failed, page: .rules).text == "Unmeasurable")
        #expect(FrameSidebarValue(figure: .unmeasurable, page: .limits).text == "Unmeasurable")
        #expect(FrameSidebarValue(figure: .percentLeft(37.6, tone: .attention), page: .limits) == FrameSidebarValue(text: "37.6% left"))
        #expect(FrameSidebarValue(figure: .percentLeft(38, tone: nil), page: .limits) == FrameSidebarValue(text: "38% left"))
        #expect(FrameSidebarValue(figure: .notMeasured, page: .clean) == .none)
        #expect(FrameSidebarValue(figure: .count(1_204, tone: nil), page: .activity).text == NumberWording.count(1_204))
    }

    @Test("VoiceOver reads the Inbox item as \"N need you, M critical\" and other items as their title and value")
    func spokenLabels() {
        #expect(FrameSidebarValue(text: "11", mark: .critical, criticalCount: 2).spokenLabel(for: .inbox) == "Inbox, 11 need you, 2 critical")
        #expect(FrameSidebarValue(text: "4", mark: .attention).spokenLabel(for: .inbox) == "Inbox, 4 need you")
        #expect(FrameSidebarValue(text: "\u{2026}").spokenLabel(for: .inbox) == "Inbox, \u{2026}")
        #expect(FrameSidebarValue(text: "3").spokenLabel(for: .hooks) == "Hooks, 3")
        #expect(FrameSidebarValue.none.spokenLabel(for: .clean) == "Clean")
        #expect(FrameSidebarValues.none[.inbox] == .none)
    }

    @Test("a region not built yet says so, with the inspector only on pages that have one")
    func notBuiltContent() {
        for page in FramePage.allCases {
            let content = FramePageContent.notBuilt(page)
            #expect((content.inspector != nil) == page.hasInspector)
            #expect(content.help == page.help && !content.help.isEmpty)
            #expect(content.primary == nil)
        }
        #expect(FramePage.allCases.filter { !$0.hasInspector } == [.clean, .limits])
    }

    // MARK: RB-V1 build-review findings

    @Test("plain-letter keys never act while text is edited: Z typed in the search field is the field's, not Undo")
    func plainKeysWaitForTextFields() {
        // The search field's field editor is an NSTextView, the window's first responder while it is edited.
        let editor = NSTextView()
        #expect(!FramePlainKeys.undoMayAct(modifiers: [], isModal: false, firstResponder: editor))
        #expect(!FramePlainKeys.rowLetterMayAct(isModal: false, firstResponder: editor))
        #expect(FramePlainKeys.undoMayAct(modifiers: [], isModal: false, firstResponder: NSView()))
        #expect(FramePlainKeys.undoMayAct(modifiers: [], isModal: false, firstResponder: nil))
        #expect(!FramePlainKeys.undoMayAct(modifiers: [.shift], isModal: false, firstResponder: nil))
        #expect(!FramePlainKeys.undoMayAct(modifiers: [], isModal: true, firstResponder: nil))
        #expect(FramePlainKeys.rowLetterMayAct(isModal: false, firstResponder: NSView()))
    }

    @Test("RD-R16: Remove, Add to… and Change to Ask have menu shortcuts: distinct, not reserved, not plain letters, no text-editing key")
    func rowActionShortcuts() {
        let shortcuts = [FrameShortcut.remove, FrameShortcut.addTo, FrameShortcut.changeToAsk]
        #expect(Set(shortcuts).count == 3 && shortcuts.allSatisfy { !$0.isPlainKey && !FrameShortcut.reserved.contains($0) })
        #expect(!shortcuts.contains(FrameShortcut(KeyEquivalent.delete.character)), "⌘⌫ deletes to the line start in a text field")
        #expect(shortcuts.allSatisfy { $0 != FrameShortcut("k") && $0 != FrameShortcut("c", modifiers: [.command, .shift]) })
        #expect(FrameShortcut.remove.description == "⇧⌘⌫" && FrameShortcut.addTo.description == "⇧⌘A" && FrameShortcut.changeToAsk.description == "⌥⌘A")
    }

    @Test("RD-R16: Copy Command and Show Terminal have menu shortcuts that clash with no frame key and no other row action")
    func copyAndTerminalShortcuts() {
        let others = [FrameShortcut.remove, FrameShortcut.addTo, FrameShortcut.changeToAsk, FrameShortcut("k")]
        for shortcut in [FrameShortcut.copyCommand, FrameShortcut.showTerminal] {
            #expect(!shortcut.isPlainKey && !FrameShortcut.reserved.contains(shortcut) && !others.contains(shortcut))
        }
        #expect(FrameShortcut.copyCommand != FrameShortcut.showTerminal)
        #expect(FrameShortcut.showTerminal != FrameShortcut("t", modifiers: [.command, .option]), "⌥⌘T is the toolbar's Hide Toolbar")
        #expect(FrameShortcut.copyCommand.description == "⇧⌘C" && FrameShortcut.showTerminal.description == "⇧⌘T")
    }

    private static func key(_ characters: String, _ flags: NSEvent.ModifierFlags, type: NSEvent.EventType = .keyDown) -> NSEvent? {
        NSEvent.keyEvent(with: type, location: .zero, modifierFlags: flags, timestamp: 0, windowNumber: 0, context: nil,
                         characters: characters, charactersIgnoringModifiers: characters, isARepeat: false, keyCode: 0)
    }

    @Test("Item menu keys that write never act while the search field is edited; a pointer choice and other focus still act")
    func menuKeysWaitForTextFields() {
        // The search field's field editor is an NSTextView, the window's first responder while it is edited.
        let editor = NSTextView()
        var ran: [String] = []
        let actions = [
            FrameRowAction(id: "remove", title: "Remove", shortcut: .remove, isDestructive: true) { ran.append("remove") },
            FrameRowAction(id: "keep", title: "Keep", shortcut: FrameShortcut("k")) { ran.append("keep") },
            FrameRowAction(id: "addTo", title: "Add to…", shortcut: .addTo) { ran.append("addTo") },
            FrameRowAction(id: "changeToAsk", title: "Change to Ask", shortcut: .changeToAsk) { ran.append("changeToAsk") },
        ]
        let keys: [NSEvent?] = [Self.key("\u{7F}", [.command, .shift]), Self.key("k", .command), Self.key("A", [.command, .shift]),
                                Self.key("a", [.command, .option])]
        for (action, key) in zip(actions, keys) {
            #expect(FramePlainKeys.isKeyEquivalent(action.menuShortcut, of: key), "\(action.id): the key-down is its shortcut")
            FramePlainKeys.performFromMenu(action, event: key, firstResponder: editor)
        }
        #expect(ran.isEmpty, "⇧⌘⌫, ⌘K, ⇧⌘A and ⌥⌘A typed in the search field write nothing")
        for (action, key) in zip(actions, keys) { FramePlainKeys.performFromMenu(action, event: key, firstResponder: NSView()) }
        #expect(ran == ["remove", "keep", "addTo", "changeToAsk"], "with the list focused the keys act")
        ran = []
        let click = NSEvent.mouseEvent(with: .leftMouseUp, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil,
                                       eventNumber: 0, clickCount: 1, pressure: 0)
        FramePlainKeys.performFromMenu(actions[0], event: click, firstResponder: editor)
        FramePlainKeys.performFromMenu(actions[1], event: Self.key("\r", []), firstResponder: editor)
        #expect(ran == ["remove", "keep"], "chosen in the menu (pointer, or Return in a menu opened from the keyboard), it acts")
        #expect(!FramePlainKeys.isKeyEquivalent(.remove, of: Self.key("\u{7F}", .command)), "⌘⌫ is not ⇧⌘⌫")
    }

    // MARK: RB-F1 shared fixes

    @Test("RD47: Hide Sidebar toggles the sidebar, names its next state, is ⌃⌘S and frees the sidebar's width for the list")
    func hideSidebar() {
        let chrome = FrameChrome()
        chrome.setWindowWidth(1280)
        let sidebar = FrameRole.sidebarWidth(.solid), inspector = InspectorWidth.wide.points
        let shown = chrome.listWidth(sidebar: sidebar, inspector: inspector)
        #expect(chrome.sidebarCommandTitle == "Hide Sidebar")
        chrome.toggleSidebar()
        #expect(chrome.isSidebarHidden && chrome.sidebarCommandTitle == "Show Sidebar")
        #expect(chrome.listWidth(sidebar: sidebar, inspector: inspector) == shown + sidebar)
        chrome.toggleSidebar()
        #expect(!chrome.isSidebarHidden)
        #expect(FrameCommandMap.sidebar == FrameShortcut("s", modifiers: [.command, .control]))
        #expect(FrameCommandMap.sidebar.description == "⌃⌘S")
        #expect(FrameShortcut.reserved.contains(FrameCommandMap.sidebar), "no row action may take ⌃⌘S")
    }

    @Test("the toolbar keeps its 196 pt slot on every page that has a primary, empty or not; Limits has none")
    func toolbarSlot() {
        #expect(FramePage.allCases.filter { !$0.hasToolbarSlot } == [.limits])
        #expect(FrameRole.toolbarSlotWidth == 196)
    }

    @Test("a refused write's toast offers Reload with its arrow, as the mock's writefail; the Settings toast keeps 90 % of 660")
    func refusedToastReload() {
        let refused = Toast(message: "Nothing changed. x", tone: .danger, action: ToastAction(title: FrameWrites.reloadTitle) {})
        #expect(FrameToastKind(refused) == .refused(action: "Reload"))
        #expect(FrameToastKind.icon(for: FrameWrites.reloadTitle) == .arrowClockwise)
        #expect(abs(FrameRole.settingsWindowWidth - 2 * BlockRole.settingsToastWindowMargin - FrameRole.settingsWindowWidth * 0.9) < 0.001)
        #expect(BlockRole.settingsToastWindowMargin < BlockRole.toastWindowMargin, "the main window's 160 would leave 340 of 660")
    }
}

@Suite("Frame round 2: sidebar, scope menus, Undo")
@MainActor
struct FrameRoundTwoTests {
    @Test("RD54: the sidebar's Limits value reads Over limit when the Window that needs you is over, never 0% left")
    func overLimit() {
        #expect(FrameSidebarValue(figure: .percentLeft(0, tone: .critical, isOver: true), page: .limits) == FrameSidebarValue(text: "Over limit"))
        #expect(FrameSidebarValue(figure: .percentLeft(0, tone: .critical), page: .limits) == FrameSidebarValue(text: "0% left"))
        let limits = CoreLimitsResult(limits: [FrameTestData.limits(used: 112)])
        let world = FrameWorld(snapshot: FrameSnapshot(registry: FrameTestData.registry, limits: limits), now: FrameTestData.now)
        let figure = world.figure(for: .limits, loading: [], failed: [])
        #expect(FrameSidebarValue(figure: figure, page: .limits).text == "Over limit")
    }

    @Test("a CLI hidden in Settings after it was picked reads as All CLIs in the menu and in the lists")
    func hiddenScope() {
        let options = FrameTestData.registry.prefix(1).map { CLIMenuEntries.Option(cli: CLIIdentity(id: $0.id, name: $0.name), isSupported: true) }
        let entries = CLIMenuEntries.scope(Array(options), scope: "codex")
        #expect(entries.first?.isChosen == true && entries.filter(\.isChosen).count == 1)
        let world = FrameWorld(snapshot: FrameSnapshot(registry: FrameTestData.registry), facts: FrameFacts(hidden: ["codex"]), now: FrameTestData.now)
        #expect(world.shownScope("codex") == nil && world.shownScope("claude") == "claude" && world.shownScope(nil) == nil)
        let hook = FrameTestData.hook("h", cells: ["claude": FrameTestData.runs(1), "codex": .missing])
        var snapshot = FrameSnapshot(registry: FrameTestData.registry)
        snapshot.loadout = FrameTestData.loadout(hooks: [hook])
        let hooks = HooksListModel(world: FrameWorld(snapshot: snapshot, facts: FrameFacts(hidden: ["codex"]), now: FrameTestData.now),
                                   loading: [], failed: [], failure: nil, view: HooksViewState(cli: "codex"), now: FrameTestData.now)
        #expect(hooks.stages.flatMap(\.rows).map(\.id) == ["hook::h@claude"], "Hooks is not left filtered to the hidden CLI")
        let equip = EquipListModel.make(kind: .skills, world: FrameWorld(snapshot: FrameSnapshot(registry: FrameTestData.registry,
            loadout: FrameTestData.loadout([FrameTestData.item("s", cells: ["claude": FrameTestData.sessions(1), "codex": FrameTestData.sessions(1)])])),
            facts: FrameFacts(hidden: ["codex"]), now: FrameTestData.now), loading: [], failed: [], failure: nil,
            view: EquipViewState(cli: "codex"), now: FrameTestData.now)
        #expect(equip.visible.map(\.id) == ["skill::s"])
    }

    @Test("Undo acts on the main window's stack only while a frame window is key and no dialog covers it")
    func undoCommand() {
        #expect(FrameUndoCommand.target(editorCanUndo: false, isFrameKey: true, isModal: false, sessionCanUndo: true) == .session)
        #expect(FrameUndoCommand.target(editorCanUndo: false, isFrameKey: false, isModal: false, sessionCanUndo: true) == .nothing,
                "from the Settings or Journal window")
        #expect(FrameUndoCommand.target(editorCanUndo: false, isFrameKey: true, isModal: true, sessionCanUndo: true) == .nothing)
        #expect(FrameUndoCommand.target(editorCanUndo: true, isFrameKey: false, isModal: true, sessionCanUndo: true) == .editor,
                "a field being edited keeps its own Undo")
    }
}
