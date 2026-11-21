import SwiftUI

/// A page's toolbar (RD-R1, RD32, RD-R17 Layout): the title with its click-only `?` and quiet line, the page's own
/// controls, the inspector button and the fixed-width primary slot at the end. Glass controls on macOS 26; a solid strip
/// with a hairline under it on macOS 15 and with Reduce Transparency.
struct FrameToolbar: View {
    let page: FramePage
    let content: FramePageContent
    /// Below 1100 pt with the overlay open the toolbar narrows beside it and leaves the title out (the mock's `.ovo .ttl`).
    let hidesTitle: Bool
    let chrome: FrameChrome
    /// The page's search (`FramePageContent.searchItems`), and whether the main column is narrow enough to fold the field to
    /// its icon button.
    var search: FrameSearch?
    var searchFolds = false
    @Environment(\.materialLook) private var look

    var body: some View {
        @Bindable var chrome = chrome
        let topInset = look == .glass ? SpaceRole.step12 : 0
        HStack(spacing: SpaceRole.step8) {
            if !hidesTitle {
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
            }
            Spacer(minLength: 0)
            if let controls = content.toolbarControls { controls }
            if let items = content.searchItems, let search {
                @Bindable var search = search
                SearchField(text: $search.text, label: "Search \(items)", folded: searchFolds, focusRequest: search.focusRequest)
            }
            if content.inspector != nil {
                let label = "\(chrome.isInspectorShown ? "Hide" : "Show") Inspector (\(FrameCommandMap.inspector))"
                Button { chrome.toggleInspector() } label: { SpaceVibeIcon(frame: .sidebarSimple, size: .control) }
                    .buttonStyle(PushButtonStyle(.icon, isActive: chrome.isInspectorShown))
                    .focusEffectDisabled()
                    .help(label)
                    .accessibilityLabel(label)
                    .accessibilityAddTraits(chrome.isInspectorShown ? .isSelected : [])
                    .accessibilityValue(chrome.isInspectorShown ? "On" : "Off")
            }
            if let primary = content.primary { FrameToolbarSlot { primary } }
        }
        .padding(.horizontal, SpaceRole.step12)
        .frame(height: FrameRole.toolbarHeight(look) - topInset)
        .padding(.top, topInset)
        .frame(maxWidth: .infinity)
        .frameToolbarSurface()
    }

    private var help: some View {
        Text(content.help)
            .typeRole(.quiet)
            .foregroundStyle(ColorRole.ink2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: FrameRole.helpPopoverWidth, alignment: .leading)
            .padding(SpaceRole.step12)
            .accessibilityLabel(content.help)
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
