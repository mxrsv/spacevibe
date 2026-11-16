import Foundation

/// How a `config.toml` value may be shown on the Rules page (the reading note and the Answer), in Codex's own terms. Pure.
///
/// Values come from `config.toml`, where any string could be a secret (AGENTS.md S-R3), so free text is shown only when it
/// reads as a plain word ("on-request", "dev"); anything else shows as `hiddenText`. The meaning of each `approval_policy`
/// value follows Codex's `AskForApproval` (`untrusted` asks unless a rule allows the command, `on-failure` is an alias of
/// `on-request`, `never` never asks).
enum CodexWording {
    static let hiddenText = "text, not shown"

    /// A config string as it may be shown: itself when it is a short lowercase word, else `hiddenText`.
    static func word(_ text: String) -> String { isWord(text) ? text : hiddenText }

    static func isWord(_ text: String) -> Bool {
        (1...24).contains(text.count)
            && text.unicodeScalars.allSatisfy { ("a"..."z").contains($0) || ("0"..."9").contains($0) || $0 == "-" || $0 == "_" }
            && text.unicodeScalars.filter { ("0"..."9").contains($0) }.count <= 2
    }

    /// The `approval_policy` string, `granular` for the table form, nil when unset. `on-failure` stays as written.
    static func approval(_ codex: CoreCodexPermissions) -> String? {
        switch codex.approvalPolicy {
        case .mode(let text): text
        case .granular: "granular"
        case nil: nil
        }
    }
}
