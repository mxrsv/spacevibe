import Foundation
import Testing
@testable import SpaceVibe

/// The middle-cut line keeps the full text for its tooltip and draws one line in its own direction. The cut itself is SwiftUI's
/// `.truncationMode(.middle)` by measured width; the break-ui shots check it on screen (RD-A11).
@Suite("Middle truncated text")
struct MiddleTruncatedTextTests {
    private let isolate = "\u{2068}"
    private let popIsolate = "\u{2069}"

    @Test("the full text is kept as given, for the tooltip and the spoken label")
    func keepsFullText() {
        let long = "~/Development/clients/northwind-industries-holdings/payments-reconciliation-service-monorepo-eu-west-1"
        #expect(MiddleTruncatedText(long).text == long)
        #expect(MiddleTruncatedText("").text == "")
    }

    @Test("the drawn line is wrapped in a first-strong isolate, so each text keeps its own direction", arguments: [
        "pdf-form-extraction-and-validation-for-enterprise-invoices-v2",
        "نور-المراجع",
        "إصلاح اختبار الدفع المتقطع في خط التكامل الليلي",
        "日本語レビュー",
        "🚀 Ship v2 landing — fix hero CLS on Safari 17 (iOS) + Lighthouse ≥ 95",
        "x",
    ])
    func isolates(text: String) {
        #expect(MiddleTruncatedText.shown(text) == isolate + text + popIsolate)
    }

    @Test("line breaks become one space each run, so a multi-line command is cut in its middle")
    func oneLine() {
        #expect(MiddleTruncatedText.shown("echo a\necho b") == isolate + "echo a echo b" + popIsolate)
        #expect(MiddleTruncatedText.shown("a\r\nb\n\n\nc") == isolate + "a b c" + popIsolate)
        #expect(MiddleTruncatedText.shown("a\u{2028}b") == isolate + "a b" + popIsolate)
    }

    @Test("nothing to draw stays empty, with no stray isolate marks")
    func empty() {
        #expect(MiddleTruncatedText.shown("") == "")
        #expect(MiddleTruncatedText.shown("\n\n") == "")
    }
}
