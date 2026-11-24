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
