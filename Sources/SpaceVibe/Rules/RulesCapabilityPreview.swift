import Foundation

/// A capability change waiting for its preview or its confirmation (the mock's `capPreview`; "Inferred, not decided":
/// Capability write). It carries the file it was asked for, and the write goes to exactly that file, never to whatever is
/// shown when the button is pressed.
struct RulesPreviewRequest: Equatable, Sendable {
    enum Phase: Equatable, Sendable {
        /// `rules.preview` has not answered: the confirm button shows pending.
        case loading
        case ready(CoreCapabilityPreview)
        case failed(String)
    }

    let file: FrameScope
    let capability: CoreCapability
    let verdict: CoreVerdict
    var phase: Phase = .loading
}

/// What the preview popover says, from `rules.preview` (it writes nothing). Pure.
struct RulesPreviewText: Equatable, Sendable {
    /// "Push and deploy → Deny".
    let title: String
    /// What the write would change, or "Nothing to change: …".
    let what: String
    /// Said when the cell will still not read the chosen verdict (a rule that stays wins).
    let warning: String?
    /// "Change to Deny", or "Nothing to change" (disabled).
    let confirmTitle: String
    /// The file already holds that: the write is not offered and nothing is written.
    let isNothing: Bool
    /// The toast after the core accepted it: "Push and deploy: Bash(git push:*) now Deny in ~/.claude/settings.json".
    let doneLabel: String

    init(row: RulesCapabilityRow, preview: CoreCapabilityPreview, fileName: String) {
        let verdict = PermissionDial.title(preview.verdict)
        title = "\(row.label) \u{2192} \(verdict)"
        // The same test as the v5 confirmation: the write would leave the file as it is.
        isNothing = Set(preview.replaces) == Set(preview.writes)
        let replaced = Set(preview.replaces.map(\.rule)), written = Set(preview.writes.map(\.rule))
        let changes = preview.replaces.filter { written.contains($0.rule) && $0.verdict != preview.verdict }.map(\.rule)
        let adds = preview.writes.filter { !replaced.contains($0.rule) }.map(\.rule)
        let removes = preview.replaces.filter { !written.contains($0.rule) }.map(\.rule)
        if isNothing {
            what = "Nothing to change: the rules of this cell already say \(verdict)."
        } else {
            let parts = [
                changes.isEmpty ? nil : "Changes \(changes.joined(separator: ", ")) to \(verdict)",
                adds.isEmpty ? nil : "Adds \(adds.joined(separator: ", ")) as \(verdict)",
                removes.isEmpty ? nil : "Removes \(removes.joined(separator: ", "))",
            ]
            what = parts.compactMap { $0 }.joined(separator: "; ") + " in \(fileName). Path and command rules stay."
        }
        if preview.resulting != CoreCapabilityState(rawValue: preview.verdict.rawValue) {
            let replacedPairs = Set(preview.replaces)
            let kept = row.cell.rules.filter { !replacedPairs.contains(CoreVerdictRule(verdict: $0.verdict, rule: $0.rule)) && $0.verdict != preview.verdict }
            let reads = Self.stateWord(preview.resulting)
            if kept.isEmpty {
                warning = "The cell will read \(reads): a rule that stays in this file still wins."
            } else {
                let named = kept.map { "\($0.rule) (\($0.verdict.rawValue))" }.joined(separator: ", ")
                warning = "The cell will read \(reads), because \(named) still \(kept.count == 1 ? "applies" : "apply")."
            }
        } else {
            warning = nil
        }
        confirmTitle = isNothing ? "Nothing to change" : "Change to \(verdict)"
        let rules = (changes + adds).isEmpty ? row.label : (changes + adds).joined(separator: ", ")
        doneLabel = "\(row.label): \(rules) now \(verdict) in \(fileName)"
    }

    static func stateWord(_ state: CoreCapabilityState) -> String {
        switch state {
        case .allow: "Allow"
        case .ask: "Ask"
        case .deny: "Deny"
        case .mixed: "Mixed"
        case .none: "No rule"
        }
    }
}

/// The words of the Rules page's writes and of the Add Rule sheet. Pure.
enum RulesWriteWording {
    /// "Changed Bash from Allow to Ask in ~/.claude/settings.json" (the mock's toast).
    static func changed(_ rule: CoreRule, to verdict: CoreVerdict, in fileName: String) -> String {
        "Changed \(rule.rule) from \(PermissionDial.title(rule.verdict)) to \(PermissionDial.title(verdict)) in \(fileName)"
    }

    static func added(_ rule: String, as verdict: CoreVerdict, in fileName: String) -> String {
        "Added \(rule) as \(PermissionDial.title(verdict)) in \(fileName)"
    }

    /// "Removed Rule Bash. settings.json was edited", "Removed 3 Rules. settings.local.json was edited" (the mock's
    /// `removeIds` toast, with the file the rules were in).
    static func removed(_ rules: [CoreRule], from fileName: String) -> String {
        let what = rules.count == 1 ? "Rule \(rules[0].rule)" : NumberWording.plural(rules.count, "Rule")
        return "Removed \(what)" + FrameWrite.edited((fileName as NSString).lastPathComponent)
    }

    /// The Add Rule sheet's line before anything is written: "Writes Bash(git log:*) as Ask to ~/.claude/settings.json."
    static func addPreview(_ draft: String, as verdict: CoreVerdict, to fileName: String) -> String {
        let rule = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rule.isEmpty else { return "Type Tool or Tool(pattern), for example Bash(git log:*)." }
        return "Writes \(rule) as \(PermissionDial.title(verdict)) to \(fileName)."
    }

    /// The sentence for a check that answers "not valid" with no message of its own (the v5 page's).
    static let invalidRule = "That is not a valid rule. Use Tool or Tool(pattern) on one line."
    static let wholeToolWarning = "A bare tool name allows every call of that tool. Ask or narrow it."
}
