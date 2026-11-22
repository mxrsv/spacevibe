import SwiftUI

/// A sentence with code in it (the mock's `<span class="mono">` inside a quiet line): the words in `quiet`, each rule, path or
/// command in `mono`, all in one wrapping text in one ink. Used where a preview names what it will write
/// (`RulesPreviewPopover`).
struct InlineCodeText: View {
    /// One run of the sentence: plain words or code.
    struct Span: Hashable, Sendable {
        let text: String
        let isCode: Bool

        static func words(_ text: String) -> Span { Span(text: text, isCode: false) }
        static func code(_ text: String) -> Span { Span(text: text, isCode: true) }
    }

    let spans: [Span]
    var ink: Color = ColorRole.ink2

    init(_ spans: [Span], ink: Color = ColorRole.ink2) {
        self.spans = spans
        self.ink = ink
    }

    var body: some View {
        spans.reduce(Text(verbatim: "")) { text, span in
            text + Text(verbatim: span.text).typeRole(span.isCode ? .mono : .quiet)
        }
        .typeRole(.quiet)
        .foregroundStyle(ink)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityLabel(Self.plain(spans))
    }

    /// The sentence as one string (VoiceOver, tests).
    static func plain(_ spans: [Span]) -> String { spans.map(\.text).joined() }

    /// `items` as code spans joined by ", " words.
    static func codeList(_ items: [String]) -> [Span] {
        items.enumerated().flatMap { index, item in index == 0 ? [Span.code(item)] : [.words(", "), .code(item)] }
    }
}
