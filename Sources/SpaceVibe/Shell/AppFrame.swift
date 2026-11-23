import AppKit
import SwiftUI

/// The redesign's window root, drawn instead of `AppShell` while `SPACEVIBE_REDESIGN=1` is on in a development build
/// (`LaunchMode.Surface`). The frame of RD-R1: the floating sidebar, the page's toolbar, the list on one solid window
/// surface and the trailing inspector, docked from 1100 pt and an overlay below (RD-R13), and above them all the page's
/// dialog (RD-R16).
///
/// The app owns the `FrameModel` (`SpaceVibeFrameApp`) and hands the same one to this window, Settings and the Journal; a
/// screenshot makes its own. The store reads at first appearance, on app activation and on ⌘R (`FrameCommands`). Each region
/// hands its page's parts through `content`; a region not built yet is `FramePageContent.notBuilt`. The look is decided once
/// here (`frameLookRoot`, AR8), the toasts of the write path show here (`FrameToastHost`), and so do every anchored popover
/// and menu of the pages (`overlayHost`).
struct AppFrame: View {
    typealias PageContent = @MainActor (FramePage, FrameModel) -> FramePageContent

    @State private var model: FrameModel
    @State private var chrome: FrameChrome
    private let forcedLook: MaterialLook?
    private let sidebarValues: FrameSidebarValues?
    private let content: PageContent

    /// - `model`: the app's (`SpaceVibeFrameApp`) or a screenshot's.
    /// - `look`: pins Glass or Solid (a screenshot); nil decides from the OS and Reduce Transparency.
    /// - `sidebarValues`: fixed values (a screenshot); nil reads them from the store.
    /// - `sidebarHidden`: a screenshot of Hide Sidebar (RD47); the app reads the window's stored state instead.
    /// - `inspectorOpen`: a screenshot below 1100 pt with the overlay inspector open (RD57); the app opens it by a row click,
    ///   Return, ⌘I or the toolbar button.
    @MainActor
    init(model: FrameModel, look: MaterialLook? = nil, sidebarValues: FrameSidebarValues? = nil, sidebarHidden: Bool = false,
         inspectorOpen: Bool = false,
         content: @escaping PageContent = { page, model in .region(page, model: model) }) {
        _model = State(initialValue: model)
        let chrome = FrameChrome(page: model.router.route.page)
        chrome.isSidebarHidden = sidebarHidden
        if inspectorOpen { chrome.openInspector() }
        _chrome = State(initialValue: chrome)
        forcedLook = look
        self.sidebarValues = sidebarValues
        self.content = content
    }

    /// A frame with a model of its own on `page`, over `env`'s core and toasts (a screenshot).
    @MainActor
    init(page: FramePage = .inbox, env: AppEnvironment? = nil, look: MaterialLook? = nil,
         sidebarValues: FrameSidebarValues? = nil, content: @escaping PageContent = { page, model in .region(page, model: model) }) {
        let env = env ?? .shared
        self.init(model: FrameModel(core: env.goCore, toasts: env.toasts, route: FrameRoute(page: page)), look: look,
                  sidebarValues: sidebarValues, content: content)
    }

    var body: some View {
        FrameWindow(model: model, chrome: chrome, sidebarValues: sidebarValues, content: content)
            .frameLookRoot(forced: forcedLook)
            .environment(chrome)
            .focusedSceneValue(\.frameCommandTarget, FrameCommandTarget(model: model, chrome: chrome))
            // The glance widget's click and its countdown pill route into this frame (GW6, LC-R7, AR5).
            .onAppear { GlanceController.shared.frame = model.router }
            .task { await model.store.start() }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                Task { await model.store.refresh() }
            }
    }
}

/// Where keyboard focus goes when the overlay inspector or a dialog opens and closes (RD-R16 Dialogs: focus moves in and
/// returns).
enum FrameFocusTarget: Hashable {
    case content, inspector, dialog

    /// Where the focus goes back to when the dialog closes: where it was before it opened, the list when that was nothing or
    /// the dialog itself.
    static func returning(to before: FrameFocusTarget?) -> FrameFocusTarget {
        guard let before, before != .dialog else { return .content }
        return before
    }
}

private struct FrameWindow: View {
    let model: FrameModel
    let chrome: FrameChrome
    let sidebarValues: FrameSidebarValues?
    let content: AppFrame.PageContent
    @Environment(\.materialLook) private var look
    @Environment(ToastCenter.self) private var toasts
    @Environment(\.openWindow) private var openWindow
    @FocusedValue(\.frameRowActions) private var rowActions
    @FocusState private var focus: FrameFocusTarget?
    @State private var focusBeforeDialog: FrameFocusTarget?
    /// Hide Sidebar (RD47), kept per window across launches, as macOS keeps a window's sidebar state.
    @SceneStorage("frame.sidebarHidden") private var storedSidebarHidden = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isShotRendering) private var isShotRendering

    var body: some View {
        let page = model.router.route.page
        let parts = content(page, model)
        // RB-F4: every region's place from this page's own parts, never from the page before (`FrameRegionLayout`).
        let layout = chrome.layout(on: page, hasInspector: parts.inspector != nil, look: look)
        let presentation = layout.presentation
        let modal = parts.dialog != nil
        ZStack(alignment: .topTrailing) {
            FrameWindowSurface(hasSidebar: !chrome.isSidebarHidden)
            HStack(spacing: 0) {
                if !chrome.isSidebarHidden {
                    FrameSidebar(current: page, values: sidebarValues ?? .from(model.store),
                                 open: { model.router.open($0) },
                                 openSettings: { openWindow(id: SettingsWindowFrame.windowID) })
                        .frame(width: FrameRole.sidebarWidth(look))
                        .transition(.move(edge: .leading))
                }
                // RD57: the toolbar spans the list and the inspector; the docked inspector starts under it. The toolbar comes
                // first for VoiceOver and the keyboard, and is drawn over the list, which scrolls under it.
                ZStack(alignment: .top) {
                    FrameToolbar(page: page, content: parts, chrome: chrome, leading: layout.toolbarLeading,
                                 isInspectorShown: presentation != .hidden, search: model.search, searchFolds: layout.searchFolds)
                        .zIndex(1)
                    HStack(spacing: 0) {
                        parts.body
                            .safeAreaPadding(layout.contentInsets)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            .focusable(!modal)
                            .focused($focus, equals: .content)
                            .focusEffectDisabled()
                            // Return opens the inspector on the selected row (RD-R16); a region's list keys do the same.
                            .onKeyPress(.return) {
                                guard model.router.route.selection != nil, parts.inspector != nil else { return .ignored }
                                chrome.openInspector()
                                return .handled
                            }
                            // A row action's plain letter (S for Stop, RD39) acts only while the list has the focus, so typing
                            // in the search field never fires it; the Item menu shows those actions without the key.
                            .onKeyPress(characters: .letters) { press in
                                guard FramePlainKeys.rowLetterMayAct(isModal: modal, firstResponder: NSApp.keyWindow?.firstResponder),
                                      let action = FrameRowAction.plainKey(press.characters, modifiers: press.modifiers,
                                                                                   in: rowActions?.actions ?? []) else { return .ignored }
                                action.perform()
                                return .handled
                            }
                        if presentation == .docked, let inspector = parts.inspector {
                            FrameInspector(content: inspector, overlayActions: nil, isOverlay: false) { chrome.closeOverlays() }
                                .frame(width: layout.inspectorWidth)
                                .padding(.top, layout.inspectorTop)
                        }
                    }
                }
            }
            .animation(reduceMotion ? nil : .easeOut(duration: MotionRole.sidebarDuration), value: chrome.isSidebarHidden)
            .accessibilityHidden(modal)
            if presentation == .overlay, let inspector = parts.inspector {
                FrameInspector(content: inspector, overlayActions: parts.overlayActions, isOverlay: true) { chrome.closeOverlays() }
                    .frame(width: layout.inspectorWidth)
                    .padding(.top, layout.inspectorTop)
                    .focusable(!modal)
                    .focused($focus, equals: .inspector)
                    .focusEffectDisabled()
                    .accessibilityHidden(modal)
            }
            // The write path's toasts (AR4): above the list and the overlay inspector, bottom centre of the window.
            FrameToastHost()
            // The page's dialog over everything, its scrim on the whole window (RD-R16, the mock's `.scrim`).
            if let dialog = parts.dialog {
                dialog.content
                    .focusable()
                    .focused($focus, equals: .dialog)
                    .focusEffectDisabled()
                    .id(dialog.id)
            }
        }
        .overlayHost()
        .ignoresSafeArea()
        .frameWindowBackground()
        // RB-F4: the traffic lights at the floating sidebar's top, as the mock draws them, not on its rounded corner.
        .frameWindowButtons(look: look)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { chrome.setWindowWidth($0) }
        .onAppear {
            // A shot draws the state it was given; the app takes the window's stored one.
            if !isShotRendering, chrome.isSidebarHidden != storedSidebarHidden { chrome.isSidebarHidden = storedSidebarHidden }
        }
        .onChange(of: chrome.isSidebarHidden) { _, hidden in if !isShotRendering { storedSidebarHidden = hidden } }
        .onChange(of: parts.inspector != nil, initial: true) { _, has in chrome.pageHasInspector = has }
        .onChange(of: parts.searchItems != nil, initial: true) { _, has in chrome.pageHasSearch = has }
        .onChange(of: parts.dialog?.id, initial: true) { old, new in
            chrome.isDialogOpen = new != nil
            if new != nil, old == nil { focusBeforeDialog = focus }
            if new != nil { focus = .dialog }
            if new == nil, old != nil { focus = FrameFocusTarget.returning(to: focusBeforeDialog) }
        }
        // The search is cleared by the router itself, before the new page's first-row rule runs (`FrameRouter.open`).
        .onChange(of: page) { chrome.pageChanged(to: page) }
        .onChange(of: presentation) { old, new in
            let opened = new == .overlay, closed = old == .overlay && !opened
            if opened { focus = .inspector }
            if closed { focus = .content }
        }
        // Esc closes the dialog first, then every overlay the frame holds; popovers and menus close themselves on Esc.
        .onExitCommand {
            switch FrameEscape.target(hasDialog: modal, presentation: presentation, isHelpOpen: chrome.isHelpOpen) {
            case .dialog: parts.dialog?.cancel()
            case .overlays, .nothing: chrome.closeOverlays()
            }
        }
        // Z undoes the newest write (RD39). This root is an ancestor of the toolbar's search field, and SwiftUI offers a key
        // press here before the field inserts it, so a z typed while text is edited is left to the field. A dialog waits.
        .onKeyPress(keys: ["z"]) { press in
            guard FramePlainKeys.undoMayAct(modifiers: press.modifiers, isModal: modal, firstResponder: NSApp.keyWindow?.firstResponder),
                  toasts.canUndoByKey else { return .ignored }
            toasts.undoKey()
            return .handled
        }
    }
}
