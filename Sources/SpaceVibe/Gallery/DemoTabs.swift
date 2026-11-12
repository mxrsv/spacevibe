import SwiftUI

/// Synthetic tabs for isolated shell/palette tests and Settings shots; never registered at runtime.
@MainActor
enum DemoTabs {
    static func make() -> [any SpaceVibeTab] {
        [DemoTab(id: "agents", title: "Agents", icon: .loadout),
         DemoTab(id: "activity", title: "Activity", icon: .activity),
         DemoTab(id: "limits", title: "Limits", icon: .limits)]
    }
}

@MainActor
private final class DemoTab: SpaceVibeTab {
    let id: String
    let title: String
    let icon: SpaceVibeGlyph

    init(id: String, title: String, icon: SpaceVibeGlyph) {
        self.id = id
        self.title = title
        self.icon = icon
    }

    var paletteItems: [PaletteEntry] {
        guard id == "agents" else { return [] }
        return ["ponytail", "impeccable", "review-change", "skill-creator"].map { name in
            PaletteEntry(id: "demo.skill.\(name)", title: name, icon: .skill, keywords: ["skill"]) {}
        }
    }
    var paletteActions: [PaletteEntry] {
        guard id == "agents" else { return [] }
        return [PaletteEntry(id: "demo.rescan", title: "Rescan usage", icon: .refresh) {}]
    }
    var content: AnyView { AnyView(Text(title).spaceVibeText(.heading)) }
}
