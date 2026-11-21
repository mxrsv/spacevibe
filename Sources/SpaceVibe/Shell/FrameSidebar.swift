import SwiftUI

/// The frame's sidebar (RD-R1, RD23): the window's traffic lights at the top, the three groups of pages, and Settings at the
/// foot, which opens the Settings window (RD4). Values come from the store through `FrameSidebarValues` (AR3).
struct FrameSidebar: View {
    let current: FramePage
    let values: FrameSidebarValues
    let open: (FramePage) -> Void
    let openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: FrameRole.trafficLightClearance)
            ForEach(FramePage.SidebarGroup.allCases) { group in
                VStack(spacing: SpaceRole.step2) {
                    FrameSidebarGroupHead(title: group.title)
                    ForEach(group.pages) { page in item(page) }
                }
                .padding(.bottom, SpaceRole.step12)
                .accessibilityElement(children: .contain)
                .accessibilityLabel(group.title)
            }
            Spacer(minLength: 0)
            FrameSidebarFootItem(title: "Settings", shortcutHint: FrameCommandMap.settings.description, action: openSettings)
                .padding(.horizontal, SpaceRole.step6)
        }
        .padding(.horizontal, SpaceRole.step8)
        .padding(.bottom, SpaceRole.step12)
        .frame(maxHeight: .infinity, alignment: .top)
        .frameSidebarSurface()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Sidebar")
    }

    private func item(_ page: FramePage) -> some View {
        let value = values[page]
        return FrameSidebarItem(title: page.title, icon: page.icon, iconTone: page.categoryTone, value: value.text,
                                mark: value.mark, isCurrent: page == current, spokenLabel: value.spokenLabel(for: page)) {
            open(page)
        }
    }
}
