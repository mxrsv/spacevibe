import SwiftUI

/// A page's toolbar (RD-R1, RD32, RD-R17 Layout, RD57): Hide Sidebar (RD47), the title with its click-only `?` and quiet line,
/// the page's own controls, then the trailing group (`FrameToolbarTrailingGroup`: search, inspector button, 196 slot). It runs
/// from the sidebar to the window's right edge on every page, over the list and the inspector, so the trailing group sits at
/// the window's right edge whatever the page; the page's controls end 8 pt before it. With the sidebar hidden it starts after
/// the traffic lights. Glass controls on macOS 26; a solid strip with a hairline under it on macOS 15 and with Reduce
/// Transparency.
struct FrameToolbar: View {
    let page: FramePage
    let content: FramePageContent
    let chrome: FrameChrome
    /// The leading padding, the same on every page (`FrameRegionLayout.toolbarLeading`): after the traffic lights while the
    /// sidebar is hidden.
    let leading: CGFloat
    /// Whether this page's inspector is drawn now (`FrameChrome.presentation(on:hasInspector:)`), for the inspector button.
    let isInspectorShown: Bool
    /// The page's search (`FramePageContent.searchItems`), and whether the toolbar is narrow enough to fold the field to its
    /// icon button (`FrameRegionLayout.searchFolds`, the same on every page).
    var search: FrameSearch?
    var searchFolds = false
    @Environment(\.materialLook) private var look

    var body: some View {
        @Bindable var chrome = chrome
        HStack(spacing: SpaceRole.step8) {
            // RD47: Hide Sidebar first (the mock's `b-chrome.js` toolbar), the same command as ⌃⌘S.
            let sidebarLabel = "\(chrome.sidebarCommandTitle) (\(FrameCommandMap.sidebar))"
            Button { chrome.toggleSidebar() } label: { SpaceVibeIcon(frame: .sidebarSimple, size: .control) }
                .buttonStyle(PushButtonStyle(.icon))
                .focusEffectDisabled()
                .help(sidebarLabel)
                .accessibilityLabel(chrome.sidebarCommandTitle)
            HStack(alignment: .center, spacing: SpaceRole.step10) {
                HStack(spacing: SpaceRole.step4) {
                    Text(page.title)
                        .typeRole(.pageTitle)
                        .foregroundStyle(ColorRole.ink)
                        .lineLimit(1)
                        .fixedSize()
                        .accessibilityAddTraits(.isHeader)
                    FrameHelpButton(label: "What \(page.title) is for", isOpen: chrome.isHelpOpen) { chrome.isHelpOpen.toggle() }
                        .popover(isPresented: $chrome.isHelpOpen, arrowEdge: .bottom) { help }
                }
                if let subtitle = content.subtitle {
                    Text(subtitle)
                        .typeRole(.quiet)
                        .foregroundStyle(ColorRole.ink3)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            .padding(.leading, SpaceRole.step4)
            Spacer(minLength: 0)
            if let controls = content.toolbarControls { controls }
            FrameToolbarTrailingGroup(searchItems: content.searchItems, search: search, searchFolds: searchFolds,
                                      hasInspector: content.inspector != nil, isInspectorShown: isInspectorShown,
                                      pageTitle: page.title, primary: content.primary) { chrome.toggleInspector() }
        }
        .padding(.leading, leading)
        .padding(.trailing, FrameRole.toolbarTrailingInset)
        .frame(height: FrameRole.toolbarRowHeight(look))
        .padding(.top, FrameRole.toolbarTopInset(look))
        .frame(maxWidth: .infinity)
        .frameToolbarSurface()
    }

    private var help: some View {
        Text(content.help)
            .typeRole(.quiet)
            .foregroundStyle(ColorRole.ink2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: BlockRole.popoverWidth, alignment: .leading)
            .padding(SpaceRole.step12)
            .accessibilityLabel(content.help)
    }
}

/// The toolbar's trailing group (RD57): the search field, the inspector button and the 196 pt primary slot, the same width
/// on every page (`FrameRole.toolbarTrailingGroupWidth`), so nothing in it moves when the page changes. A page without a
/// search keeps the field's place empty; a page without an inspector keeps the button, disabled, as a macOS toolbar dims an
/// item that does not apply rather than removing it; a page with no button now keeps the slot empty (the mock's empty
/// `span.slot`, FE-L1). Pressing the folded search unfolds it to the left; the button and the slot stay.
struct FrameToolbarTrailingGroup: View {
    let searchItems: String?
    let search: FrameSearch?
    let searchFolds: Bool
    let hasInspector: Bool
    let isInspectorShown: Bool
    let pageTitle: String
    let primary: AnyView?
    let toggleInspector: () -> Void

    var body: some View {
        HStack(spacing: SpaceRole.step8) {
            if let searchItems, let search {
                @Bindable var search = search
                SearchField(text: $search.text, label: "Search \(searchItems)", folded: searchFolds, focusRequest: search.focusRequest)
            } else {
                Color.clear
                    .frame(width: searchFolds ? SizeRole.controlRegular : BlockRole.searchFieldWidth, height: SizeRole.controlRegular)
                    .accessibilityHidden(true)
            }
            inspectorButton
            if let primary {
                FrameToolbarSlot { primary }
            } else {
                FrameToolbarSlot()
            }
        }
    }

    private var inspectorButton: some View {
        let shown = hasInspector && isInspectorShown
        let label = "\(shown ? "Hide" : "Show") Inspector (\(FrameCommandMap.inspector))"
        return Button(action: toggleInspector) { SpaceVibeIcon(frame: .sidebarSimple, size: .control) }
            .buttonStyle(PushButtonStyle(.icon, isActive: shown))
            .focusEffectDisabled()
            .disabled(!hasInspector)
            .help(hasInspector ? label : "\(pageTitle) has no inspector")
            .accessibilityLabel(hasInspector ? label : "Show Inspector")
            .accessibilityAddTraits(shown ? .isSelected : [])
            .accessibilityValue(shown ? "On" : "Off")
    }
}

/// The trailing inspector (DS-R10): docked at 1100 pt and wider, an overlay over the list below, with a close button and the
/// selected row's actions repeated at its top. Esc closes the overlay (`AppFrame`); focus moves in when it opens and back to
/// the list when it closes.
struct FrameInspector: View {
    let content: AnyView
    let overlayActions: AnyView?
    let isOverlay: Bool
    let close: () -> Void

    var body: some View {
        SpaceVibeScrollView {
            VStack(alignment: .leading, spacing: SpaceRole.step16) {
                if isOverlay {
                    HStack(spacing: SpaceRole.step8) {
                        if let overlayActions { overlayActions }
                        Spacer(minLength: 0)
                        Button(action: close) { SpaceVibeIcon(frame: .x, size: .control) }
                            .buttonStyle(PushButtonStyle(.icon, size: .small))
                            .focusEffectDisabled()
                            .help("Close Inspector (Esc)")
                            .accessibilityLabel("Close Inspector (Esc)")
                    }
                }
                content
            }
            .padding(SpaceRole.step16)
        }
        .frameInspectorSurface(overlay: isOverlay)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Inspector")
    }
}
