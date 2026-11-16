/// Words for verdicts, grid states and the confirmation. Pure.
enum RulesWording {
    static func title(_ verdict: CoreVerdict) -> String {
        switch verdict {
        case .allow: "Allow"
        case .ask: "Ask"
        case .deny: "Deny"
        }
    }

    static func groupTitle(_ verdict: CoreVerdict) -> String {
        verdict == .ask ? "Ask first" : title(verdict)
    }

    static func stateLabel(_ state: CoreCapabilityState) -> String {
        switch state {
        case .allow: "Allow"
        case .ask: "Ask"
        case .deny: "Deny"
        case .mixed: "mixed"
        case .none: "no rule"
        }
    }

    static func setLabel(_ capabilityLabel: String, _ verdict: CoreVerdict) -> String {
        "Set \(capabilityLabel) to \(title(verdict))"
    }

    /// Shown when the global file could not be read: the badge and the Global scope cannot count rules they could not see.
    static let globalNotReadable = "~/.claude/settings.json could not be read, so its rules are not counted."
}

/// A grid write waiting for the user's confirmation: what `rules.preview` says it replaces and writes.
///
/// It carries the scope the preview was made for, and the write goes to exactly that scope, never to whatever is selected
/// when Confirm is pressed.
struct RulesPending: Equatable {
    let preview: CoreCapabilityPreview
    let scope: RulesScope
    let scopeTitle: String
    /// The grid row's own label ("Push and deploy"), as the core names the capability.
    let capabilityLabel: String

    var capability: CoreCapability { preview.capability }
    var verdict: CoreVerdict { preview.verdict }
    var question: String { "\(RulesWording.setLabel(capabilityLabel, verdict))?" }
    var location: String { "Writes to \(scopeTitle): \(preview.scopeLabel)." }

    /// The file already holds exactly what the write would produce.
    var isNoOp: Bool { Set(preview.replaces) == Set(preview.writes) }

    /// What to tell the user instead of opening a confirmation for a write that changes nothing. The cell may still read
    /// something else because a rule that stays wins, so the words come from the resulting state.
    var noOpMessage: String {
        if preview.resulting == CoreCapabilityState(rawValue: verdict.rawValue) {
            return "\(capabilityLabel) already reads \(RulesWording.title(verdict)) here."
        }
        return "\(capabilityLabel) stays \(RulesWording.stateLabel(preview.resulting)) here: a rule that stays in this file wins."
    }

    /// A rule that is kept (for example a bare `Bash` ask under Push and deploy) still wins over what is written.
    var warning: String? {
        guard preview.resulting != CoreCapabilityState(rawValue: verdict.rawValue) else { return nil }
        return "A rule that stays in this file still wins, so \(capabilityLabel) will read \(RulesWording.stateLabel(preview.resulting)), not \(RulesWording.title(verdict))."
    }
}
