import Foundation

/// The lines of the frame's three pick menus (RD-R10; the mock's `cliPopup`, `rulesCliPop` and `projPop`). Pure: a page
/// passes plain values, `MenuPanel` draws the result, the tests check it.
enum CLIMenuEntries {
    /// The id of the "All CLIs" line.
    static let allID = "all"

    /// One CLI as the menus need it: who it is and whether it has the page's concept.
    struct Option: Hashable, Sendable {
        let cli: CLIIdentity
        var isSupported = true
        /// The CLI picker only: the page is read-only for this CLI ("Read only"; only Claude Code's Rules are written).
        var isReadOnly = false
    }

    // MARK: All CLIs (Skills, Subagents, Hooks, Inbox)

    static let scopeHeading = "Show"

    /// "All CLIs" with the CLI count, then every CLI in the fixed order; a CLI without the page's concept is listed, disabled,
    /// as Not supported. `scope` nil is All CLIs.
    static func scope(_ options: [Option], scope: String?) -> [MenuPanelEntry] {
        // A pick no option names (a CLI hidden in Settings since) reads as All CLIs, as the lists apply it.
        let scope = options.contains { $0.cli.id == scope } ? scope : nil
        let all = MenuPanelEntry(id: allID, title: "All CLIs", note: NumberWording.count(options.count), isChosen: scope == nil)
        return [all] + options.map { option in
            MenuPanelEntry(id: option.cli.id, title: option.cli.name, lead: .cli(option.cli),
                           note: option.isSupported ? nil : "Not supported",
                           isChosen: scope == option.cli.id, isEnabled: option.isSupported)
        }
    }

    /// The pop-up button's title: "All CLIs", or the chosen CLI's name.
    static func scopeTitle(_ options: [Option], scope: String?) -> String {
        options.first { $0.cli.id == scope }?.cli.name ?? "All CLIs"
    }

    // MARK: CLI picker (Rules)

    /// Every CLI; the chosen one checked; read-only ones say so; one without Rules is Not supported and disabled.
    static func picker(_ options: [Option], chosen: String) -> [MenuPanelEntry] {
        options.map { option in
            MenuPanelEntry(id: option.cli.id, title: option.cli.name, lead: .cli(option.cli),
                           note: !option.isSupported ? "Not supported" : option.isReadOnly ? "Read only" : nil,
                           isChosen: option.cli.id == chosen, isEnabled: option.isSupported)
        }
    }

    // MARK: Project picker (Rules › Project)

    struct Project: Hashable, Sendable {
        let name: String
        let path: String
    }

    /// One line per project: its name, its path in mono (both cut in the middle), the chosen one checked.
    static func projects(_ projects: [Project], chosen: String?) -> [MenuPanelEntry] {
        projects.map { MenuPanelEntry(id: $0.name, title: $0.name, note: $0.path, noteIsPath: true, isChosen: $0.name == chosen) }
    }
}
