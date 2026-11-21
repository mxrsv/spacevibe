import Foundation

/// A Hook's name: the script it runs, one rule on every surface (RD-R17). The inventory gives a Hook no name, only its command, so
/// the name is read from the command's shell words: `sh '$HOME/x.sh'`, `bash -c '…'`, `python3 ~/y.py`, never "the text after the
/// last /". This is the reference mock's `hookLabel` (`src/a-core.js`), ported rule for rule except for environment assignments,
/// which the spec's rule wins over (a `KEY=value` word is not what a Hook runs):
///
/// 1. Split the command into words: an environment assignment (`KEY=value`, its value quoted or not, kept whole), a
///    single-quoted or double-quoted run, or a run of non-space characters. Strip one quote from each end of a word. A word that
///    still holds a space (a quoted `-c` body) is split once more the same way.
/// 2. Assignments (`^[A-Za-z_][A-Za-z0-9_]*=`) are dropped, at either level: `NODE_ENV=production FOO=1 ./x.sh` runs `x.sh`.
/// 3. The first word ending in a script extension (`.sh`, `.bash`, `.zsh`, `.py`, `.mjs`, `.cjs`, `.js`, `.ts`, `.rb`, `.pl`)
///    is the name, without its folders.
/// 4. Otherwise the first word that is not a launcher (`sh`, `bash`, `zsh`, `env`, `cd`, `npx`, `pnpx`, `bunx`, `uvx`, `exec`,
///    `&&`, `||`, `;`), a flag (`-…`) or a variable (`$…`), else the first word, else the command: without its folders and a
///    trailing `@version`, at most 40 characters.
///
/// The v5 Hooks tab names a Hook by the file name of the first script path the core found (`LoadoutRow.hookTitle`); that stays
/// as it is until the cut-over.
enum HookLabel {
    /// The longest name rule 4 gives; the view cuts it further by width.
    static let maxLength = 40

    private static let launchers: Set<String> = ["sh", "bash", "zsh", "env", "cd", "npx", "pnpx", "bunx", "uvx", "exec", "&&", "||", ";"]

    // JavaScript's `$` (end of input, no multiline flag) is ICU's `\z`, and its `\d` is ASCII only.
    private static let word = pattern(#"[A-Za-z_][A-Za-z0-9_]*=(?:'[^']*'|"[^"]*"|\S)*|'[^']*'|"[^"]*"|\S+"#)
    private static let assignment = pattern(#"^[A-Za-z_][A-Za-z0-9_]*="#)
    private static let edgeQuote = pattern(#"^['"]|['"]\z"#)
    private static let script = pattern(#"\.(sh|bash|zsh|py|mjs|cjs|js|ts|rb|pl)\z"#)
    private static let variable = pattern(#"^["']?\$"#)
    private static let folders = pattern(#"^.*/"#)
    private static let version = pattern(#"@[0-9.]+\z"#)

    static func of(_ command: String) -> String {
        let flat = words(command)
            .flatMap { $0.contains(" ") ? words($0) : [$0] }
            .filter { !matches(assignment, $0) }
        if let file = flat.first(where: { matches(script, $0) }) { return replacing(folders, in: file) }
        let tool = flat.first { !launchers.contains($0) && !$0.hasPrefix("-") && !matches(variable, $0) }
        let name = replacing(version, in: replacing(folders, in: tool ?? flat.first ?? command))
        return String(name.prefix(maxLength))
    }

    /// The words of `text`, quotes stripped. An assignment is dropped here, while its quoted value is still whole, so its spaces
    /// never split it; a quoted `-c` body starts with its quote, so it is kept and split by the caller.
    private static func words(_ text: String) -> [String] {
        let range = NSRange(text.startIndex..., in: text)
        return word.matches(in: text, range: range).compactMap { match in
            Range(match.range, in: text).map { String(text[$0]) }
        }
        .filter { !matches(assignment, $0) }
        .map { replacing(edgeQuote, in: $0) }
    }

    private static func matches(_ regex: NSRegularExpression, _ text: String) -> Bool {
        regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    private static func replacing(_ regex: NSRegularExpression, in text: String) -> String {
        regex.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: "")
    }

    private static func pattern(_ source: String) -> NSRegularExpression {
        do { return try NSRegularExpression(pattern: source) } catch { preconditionFailure("HookLabel pattern \(source): \(error)") }
    }
}

extension CoreInventoryHook {
    /// The name every new-frame surface shows for this Hook (`HookLabel`).
    var label: String { HookLabel.of(command) }
}
