import AppKit
import SwiftUI

/// The redesign's window root, drawn instead of `AppShell` while `SPACEVIBE_REDESIGN=1` is on in a development build
/// (`LaunchMode.Surface`). The frame of RD-R1: the floating sidebar, the page's toolbar, the list on one solid window
/// surface and the trailing inspector, docked from 1100 pt and an overlay below (RD-R13).
///
/// It owns the frame's `FrameModel` (RB-S5), so the store exists only with the switch on: it reads at first appearance, on
/// app activation and on ⌘R (`FrameCommands`). Each region hands its page's parts through `content`; a region not built yet
/// is `FramePageContent.notBuilt`. The look is decided once here (`frameLookRoot`, AR8), and the toasts of the write path
/// show here (`FrameToastHost`).
struct AppFrame: View {
    typealias PageContent = @MainActor (FramePage, FrameModel) -> FramePageContent

    @State private var model: FrameModel
    @State private var chrome = FrameChrome()
    private let forcedLook: MaterialLook?
    private let sidebarValues: FrameSidebarValues?
    private let content: PageContent

    /// - `look`: pins Glass or Solid (a screenshot); nil decides from the OS and Reduce Transparency.
    /// - `sidebarValues`: fixed values (a screenshot); nil reads them from the store.
    @MainActor
    init(page: FramePage = .inbox, env: AppEnvironment? = nil, look: MaterialLook? = nil,
         sidebarValues: FrameSidebarValues? = nil, content: @escaping PageContent = { page, model in .region(page, model: model) }) {
        let env = env ?? .shared
        _model = State(initialValue: FrameModel(core: env.goCore, toasts: env.toasts, route: FrameRoute(page: page)))
        forcedLook = look
        self.sidebarValues = sidebarValues
        self.content = content
    }

    var body: some View {
        FrameWindow(model: model, chrome: chrome, sidebarValues: sidebarValues, content: content)
            .frameLookRoot(forced: forcedLook)
            .environment(chrome)
            .focusedSceneValue(\.frameCommandTarget, FrameCommandTarget(model: model, chrome: chrome))
            .task { await model.store.start() }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                Task { await model.store.refresh() }
            }
    }
}

/// Where keyboard focus goes when the overlay inspector opens and closes (RD-R16 Dialogs: focus moves in and returns).
private enum FrameFocusTarget: Hashable {
    case content, inspector
}

private struct FrameWindow: View {
    let model: FrameModel
    let chrome: FrameChrome
    let sidebarValues: FrameSidebarValues?
    let content: AppFrame.PageContent
    @Environment(\.materialLook) private var look
    @Environment(ToastCenter.self) private var toasts
    @Environment(\.openWindow) private var openWindow
    @FocusState private var focus: FrameFocusTarget?

    var body: some View {
        let page = model.router.route.page
        let parts = content(page, model)
        let presentation = chrome.presentation
        ZStack(alignment: .topTrailing) {
            FrameWindowSurface()
            HStack(spacing: 0) {
                FrameSidebar(current: page, values: sidebarValues ?? .from(model.store),
                             open: { model.router.open($0) },
                             openSettings: { openWindow(id: SettingsWindowFrame.windowID) })
                    .frame(width: FrameRole.sidebarWidth(look))
                ZStack(alignment: .top) {
                    parts.body
                        .safeAreaPadding(EdgeInsets(top: SpaceRole.toolbarClearance(look), leading: SpaceRole.step12,
                                                    bottom: SpaceRole.step24, trailing: SpaceRole.step20))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .focusable()
                        .focused($focus, equals: .content)
                        .focusEffectDisabled()
                        // Return opens the inspector on the selected row (RD-R16); a region's list keys do the same.
                        .onKeyPress(.return) {
                            guard model.router.route.selection != nil, parts.inspector != nil else { return .ignored }
                            chrome.openInspector()
                            return .handled
                        }
                    FrameToolbar(page: page, content: parts, hidesTitle: presentation == .overlay, chrome: chrome)
                        .padding(.trailing, presentation == .overlay ? page.inspectorWidth.points : 0)
                }
                if presentation == .docked, let inspector = parts.inspector {
                    FrameInspector(content: inspector, overlayActions: nil, isOverlay: false) { chrome.closeOverlays() }
                        .frame(width: page.inspectorWidth.points)
                }
            }
            if presentation == .overlay, let inspector = parts.inspector {
                FrameInspector(content: inspector, overlayActions: parts.overlayActions, isOverlay: true) { chrome.closeOverlays() }
                    .frame(width: page.inspectorWidth.points)
                    .padding(.top, FrameRole.toolbarHeight(look))
                    .focusable()
                    .focused($focus, equals: .inspector)
                    .focusEffectDisabled()
            }
            // The write path's toasts (AR4): above the list and the overlay inspector, bottom centre of the window.
            FrameToastHost()
        }
        .ignoresSafeArea()
        .frameWindowBackground()
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { chrome.setWindowWidth($0) }
        .onChange(of: parts.inspector != nil, initial: true) { _, has in chrome.pageHasInspector = has }
        .onChange(of: page) { chrome.pageChanged() }
        .onChange(of: presentation) { old, new in
            let opened = new == .overlay, closed = old == .overlay && !opened
            if opened { focus = .inspector }
            if closed { focus = .content }
        }
        // Esc closes every overlay the frame holds; popovers, menus and sheets close themselves on Esc.
        .onExitCommand { chrome.closeOverlays() }
        // Z undoes the newest write (RD39); a text field takes the letter first, so typing a z never undoes.
        .onKeyPress(keys: ["z"]) { press in
            guard press.modifiers.isEmpty, toasts.canUndoByKey else { return .ignored }
            toasts.undoKey()
            return .handled
        }
    }
}
