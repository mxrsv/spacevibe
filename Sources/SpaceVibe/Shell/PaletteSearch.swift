import Foundation

struct PaletteSection: Identifiable {
    let title: String
    let entries: [PaletteEntry]

    var id: String { title }
}

/// Builds what the palette lists: "Go to" (the tabs), "Actions" (the active tab's, plus global ones, plus Undo of the newest
/// write in `toasts`' session stack). Matching is case-insensitive and every word of the query must appear in the title or
/// the keywords.
@MainActor
enum PaletteSearch {

    static func sections(shell: ShellModel, toasts: ToastCenter? = nil, query: String) -> [PaletteSection] {
        let words = query.lowercased().split(whereSeparator: \.isWhitespace).map(String.init)

        let goTo = shell.tabs.enumerated().map { index, tab in
            PaletteEntry(
                id: "goto.\(tab.id)",
                title: tab.title,
                glyph: tab.glyph,
                trailing: "\u{2318}\(index + 1)",
                keywords: ["go to"]
            ) { shell.select(tab.id) }
        }

        let theme = shell.appearance.choice.toggled
        let global = PaletteEntry(
            id: "shell.theme",
            title: "Switch to \(theme.rawValue) theme",
            glyph: theme == .light ? ContentGlyph.sun : ContentGlyph.moon,
            keywords: ["appearance", "dark", "light", "mode"]
        ) { shell.appearance.toggle() }
        let settings = PaletteEntry(
            id: "shell.settings",
            title: "Settings",
            glyph: ContentGlyph.sliders,
            trailing: "\u{2318},",
            keywords: ["preferences", "appearance", "theme", "font size", "update"]
        ) { shell.openSettings() }
        var actions = shell.activeTab.paletteActions
        // Only the newest item, so Undo stays last in, first out.
        if let newest = toasts?.undoStack.last {
            actions.append(PaletteEntry(
                id: "shell.undo",
                title: "Undo: \(newest.label)",
                glyph: SpaceVibeGlyph.undo,
                trailing: ToastAction.undoKeyCap,
                keywords: ["revert", "restore"]
            ) { [toasts] in toasts?.undoLast() })
        }
        actions += [global, settings]

        let sections = [
            PaletteSection(title: "Go to", entries: goTo.filter { matches($0, words) }),
            PaletteSection(title: "Actions", entries: actions.filter { matches($0, words) }),
        ]
        return sections.filter { !$0.entries.isEmpty }
    }

    private static func matches(_ entry: PaletteEntry, _ words: [String]) -> Bool {
        guard !words.isEmpty else { return true }
        let haystack = ([entry.title] + entry.keywords).joined(separator: " ").lowercased()
        return words.allSatisfy { haystack.contains($0) }
    }
}
