import SwiftUI

/// Synthetic tabs for isolated shell/palette tests and Settings shots; never registered at runtime.
@MainActor
enum DemoTabs {
    static func make() -> [any SpaceVibeTab] {
        [DemoTab(id: "agents", title: "Agents", glyph: ContentGlyph.stack),
         DemoTab(id: "activity", title: "Activity", glyph: ContentGlyph.pulse),
         DemoTab(id: "limits", title: "Limits", glyph: ContentGlyph.gauge)]
    }
}

@MainActor
private final class DemoTab: SpaceVibeTab {
    let id: String
    let title: String
    let glyph: any GlyphSource

    init(id: String, title: String, glyph: any GlyphSource) {
        self.id = id
        self.title = title
        self.glyph = glyph
    }

    var paletteItems: [PaletteEntry] {
        guard id == "agents" else { return [] }
        return ["ponytail", "impeccable", "review-change", "skill-creator"].map { name in
            PaletteEntry(id: "demo.skill.\(name)", title: name, glyph: CategoryGlyph.skill, keywords: ["skill"]) {}
        }
    }
    var paletteActions: [PaletteEntry] {
        guard id == "agents" else { return [] }
        return [PaletteEntry(id: "demo.rescan", title: "Rescan usage", glyph: ContentGlyph.enter) {}]
    }
    var content: AnyView { AnyView(Text(title).spaceVibeText(.heading)) }
}
