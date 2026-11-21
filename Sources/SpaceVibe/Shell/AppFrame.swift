import AppKit
import SwiftUI

/// The redesign's window root, drawn instead of `AppShell` while `SPACEVIBE_REDESIGN=1` is on in a development build
/// (`LaunchMode.Surface`). For now it is only the seam RB-S3 builds the frame on: the eight pages in sidebar order and an
/// empty state on each, composed from the existing blocks. It owns the frame's `FrameModel`, so the store exists only with
/// the switch on: it reads at first appearance, on app activation and on ⌘R.
struct AppFrame: View {
    @State private var model: FrameModel

    @MainActor
    init(page: FramePage = .inbox, env: AppEnvironment? = nil) {
        let env = env ?? .shared
        _model = State(initialValue: FrameModel(core: env.goCore, toasts: env.toasts, route: FrameRoute(page: page)))
    }

    private var page: FramePage { model.router.route.page }

    var body: some View {
        ZStack(alignment: .topLeading) {
            HiddenKey(KeyboardShortcut("r", modifiers: .command)) { Task { await model.store.refresh(force: true) } }
            frame
        }
        .task { await model.store.start() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await model.store.refresh() }
        }
    }

    private var frame: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: SpaceRole.titleBarClearance)
                VStack(spacing: SpaceRole.step4) {
                    ForEach(FramePage.allCases) { item in
                        SidebarPageItem(title: item.title, glyph: Self.glyph(of: item), isCurrent: item == page) { model.router.open(item) }
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Sections")
                Spacer(minLength: 0)
            }
            .appSidebarSurface()
            ContentPanel {
                QuietEmptyState("Not built yet", message: "\(page.title) has no view in the redesign yet.", placement: .list)
            }
        }
        .pageBackground()
        .ignoresSafeArea()
    }

    /// Stand-ins from the v5 icon data until RB-S6 brings the redesign's icon set.
    private static func glyph(of page: FramePage) -> any GlyphSource {
        switch page {
        case .inbox: ContentGlyph.stack
        case .clean: ContentGlyph.trash
        case .skills: CategoryGlyph.skill
        case .subagents: CategoryGlyph.subagent
        case .hooks: CategoryGlyph.hook
        case .rules: ContentGlyph.rule
        case .limits: ContentGlyph.gauge
        case .activity: ContentGlyph.pulse
        }
    }
}
