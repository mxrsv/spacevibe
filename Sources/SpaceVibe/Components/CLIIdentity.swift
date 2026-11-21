import Foundation

/// A CLI as a block shows it: its registry id (`clis.registry`, RB-E1), its full name for labels and VoiceOver, and the short
/// name a narrow tile or a sheet button uses. Blocks take this plain value; they never read the registry or the store.
struct CLIIdentity: Hashable, Identifiable, Sendable {
    let id: String
    let name: String
    let shortName: String

    init(id: String, name: String, shortName: String? = nil) {
        self.id = id
        self.name = name
        self.shortName = shortName ?? Self.defaultShortName(id: id, name: name)
    }

    /// The short names the reference mock writes (`SHORT` in `src/b-chrome.js`): the first word for a two-word name ("Cursor"
    /// for Cursor CLI), "Claude" for Claude Code, the name itself otherwise.
    static func defaultShortName(id: String, name: String) -> String {
        if id == "claude" { return "Claude" }
        let words = name.split(separator: " ")
        guard words.count > 1, let last = words.last, last == "CLI" || last == "Code" else { return name }
        return words.dropLast().joined(separator: " ")
    }

    static let claude = CLIIdentity(id: "claude", name: "Claude Code")
    static let codex = CLIIdentity(id: "codex", name: "Codex")
}

/// Names joined for a sentence: "Codex", "Codex and Amp", "Codex, Cursor CLI and Amp" (the mock's `cliNames`).
enum CLINames {
    static func sentence(_ names: [String]) -> String {
        switch names.count {
        case 0: return ""
        case 1: return names[0]
        default: return names.dropLast().joined(separator: ", ") + " and " + names[names.count - 1]
        }
    }

    static func sentence(_ clis: [CLIIdentity]) -> String { sentence(clis.map(\.name)) }
}
