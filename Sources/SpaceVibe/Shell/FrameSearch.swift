import Foundation
import Observation

/// The toolbar's search on the page showing (⌘F; the spec's "Inferred, not decided" line Search, D49): its text, and a
/// request to take the keyboard focus that ⌘F sends to the field. The text filters the page's list by name, description,
/// command and path (`FrameSearchQuery`); the hero and the sidebar keep counting everything (AR3). Another page starts with
/// an empty field, as its selection starts empty (RD41).
@MainActor
@Observable
final class FrameSearch {
    var text = ""
    /// Bumped by ⌘F; the field takes the focus whenever it changes.
    private(set) var focusRequest = 0

    var query: FrameSearchQuery { FrameSearchQuery(text) }

    func requestFocus() { focusRequest += 1 }

    func clear() { text = "" }
}

/// What the search field holds, as a filter. Pure. Every word must appear in one of a row's fields (name, description,
/// command, path), ignoring case and diacritics; an empty query keeps every row.
struct FrameSearchQuery: Equatable, Sendable {
    let words: [String]

    init(_ text: String) {
        words = text.split(whereSeparator: \.isWhitespace).map { Self.fold(String($0)) }
    }

    var isEmpty: Bool { words.isEmpty }

    /// Whether a row with these fields stays in the list.
    func matches(_ fields: [String?]) -> Bool {
        guard !isEmpty else { return true }
        let folded = fields.compactMap { $0 }.map(Self.fold)
        return words.allSatisfy { word in folded.contains { $0.contains(word) } }
    }

    /// `rows` with only those that match, in their order.
    func filter<Row>(_ rows: [Row], fields: (Row) -> [String?]) -> [Row] {
        isEmpty ? rows : rows.filter { matches(fields($0)) }
    }

    private static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }
}

/// The list's state when the search hides every row (the mock's "not shown": "No <items> match" with Clear Search,
/// `SearchNoMatchState`). The sentence under the title is the agent's ("Inferred, not decided": the mock draws none).
enum FrameSearchWording {
    static func noMatchTitle(_ items: String) -> String { "No \(items) match" }
    static func noMatchText(_ text: String) -> String {
        "Nothing here matches \u{201C}\(text.trimmingCharacters(in: .whitespacesAndNewlines))\u{201D}."
    }
}

extension FrameRow {
    /// What the search reads on a Skill, Subagent or Hook row: its name, every description and path, and a Hook's command,
    /// matcher, event and file (the spec's Search line: name, description, command and path).
    var searchFields: [String?] {
        [name] + items.flatMap { [$0.name, $0.description, $0.path] }
            + hooks.flatMap { [$0.command, $0.matcher, $0.event, $0.file] + $0.paths }
    }
}
