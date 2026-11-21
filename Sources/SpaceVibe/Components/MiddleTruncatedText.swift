import SwiftUI

/// One line of a long name, path or command, cut in the middle by its measured width (RD-R17): the start and the end, which tells
/// two names apart, stay, and the full text is the tooltip and the spoken label. The reference mock's character-count `midT` is
/// not ported; the layout measures the real glyphs.
///
/// It keeps its own text direction: an Arabic or Hebrew name reads right to left inside a left-to-right row, and a Latin command
/// stays left to right in any row (a first-strong isolate, the mock's `dir="auto"`). It picks no font or colour: the caller's
/// `.font` and `.foregroundStyle` reach it through the environment, so it carries whatever tokens the screen composes.
struct MiddleTruncatedText: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(verbatim: Self.shown(text))
            .lineLimit(1)
            .truncationMode(.middle)
            .help(text)
            .accessibilityLabel(Text(verbatim: text))
    }

    /// The one line drawn: each run of line breaks becomes one space, so a multi-line command is cut in the middle rather than
    /// after its first line, and the whole is wrapped in FSI … PDI so its direction comes from its own first strong letter.
    /// Nothing to draw stays empty.
    static func shown(_ text: String) -> String {
        let line = text.split(whereSeparator: \.isNewline).joined(separator: " ")
        return line.isEmpty ? "" : "\u{2068}\(line)\u{2069}"
    }
}
