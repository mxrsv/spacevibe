import Foundation

/// A CLI's Rules page when SpaceVibe does not write that CLI's permissions (RD-R10 Rules: read only in its own terms, the
/// owner's 2026-11-04 pick): the hero is the riskiest setting word, a list of the settings as the CLI names them, and the
/// one line the Claude Code page shows beside its hero. Pure. Codex is read from `rules.snapshot` `codex`, through the v5
/// `CodexReading` and `CodexWording` (a config value is shown only when it reads as a plain word, S-R3); a CLI the engine
/// has no permission reading for is Unmeasurable, never a made-up stance (FE-D3).
struct RulesReadOnlyPage: Identifiable, Equatable, Sendable {
    /// A reading that could not be made: the band's title and sentence.
    struct Banner: Equatable, Sendable {
        let title: String
        let detail: String
    }

    let cli: CoreRegistryCLI
    let hero: PageHero.Figure
    let heroLabel: String
    /// The line beside Claude Code's hero ("on-request · workspace-write", "Unmeasurable").
    let line: String
    let facts: [InspectorFact]
    let notes: [String]
    let banner: Banner?
    /// "Read from ~/.codex/config.toml. Shown only, never edited."; nil when nothing was read.
    let source: String?

    var id: String { cli.id }

    static let codexID = "codex"
    static let codexFile = "~/.codex/config.toml"
    static let unmeasurable = "Unmeasurable"

    /// `global` is the global `rules.snapshot` reading, which carries Codex's permissions; `state` that source's state.
    static func of(_ cli: CoreRegistryCLI, global: CoreRulesSnapshot?, state: FrameSourceState?) -> RulesReadOnlyPage {
        guard cli.id == codexID else {
            return RulesReadOnlyPage(cli: cli, hero: .unmeasurable, heroLabel: unmeasurable, line: unmeasurable, facts: [],
                                     notes: ["SpaceVibe cannot read \(cli.name)\u{2019}s permission settings yet."], banner: nil, source: nil)
        }
        guard let global else {
            if case .failed(let message) = state {
                return RulesReadOnlyPage(cli: cli, hero: .unmeasurable, heroLabel: unmeasurable, line: unmeasurable, facts: [], notes: [],
                                         banner: Banner(title: "Codex settings could not be read", detail: message), source: nil)
            }
            return RulesReadOnlyPage(cli: cli, hero: .scanning, heroLabel: "Reading \(codexFile)", line: "\u{2026}", facts: [], notes: [],
                                     banner: nil, source: nil)
        }
        return codex(cli, CodexReading(codex: global.codex, installed: true))
    }

    private static func codex(_ cli: CoreRegistryCLI, _ reading: CodexReading) -> RulesReadOnlyPage {
        let source = "Read from \(codexFile). Shown only, never edited."
        switch reading {
        case .known(let codex):
            let sandbox = codex.sandboxMode.map(CodexWording.word) ?? "not set"
            let approval = CodexWording.approval(codex).map(CodexWording.word)
            return RulesReadOnlyPage(cli: cli, hero: .value(sandbox, unit: nil), heroLabel: "sandbox \u{00B7} \(approvalPhrase(approval))",
                                     line: "\(approval ?? "approval not set") \u{00B7} \(sandbox)", facts: facts(codex),
                                     notes: codex.warnings, banner: nil, source: source)
        case .unknown(.notReadable):
            return RulesReadOnlyPage(cli: cli, hero: .unmeasurable, heroLabel: unmeasurable, line: unmeasurable, facts: [], notes: [],
                                     banner: Banner(title: "Codex settings could not be read",
                                                    detail: "\(codexFile) could not be read, so every Codex setting is Unmeasurable here, not the defaults."),
                                     source: nil)
        case .unknown(let reason):
            return RulesReadOnlyPage(cli: cli, hero: .unmeasurable, heroLabel: unmeasurable, line: unmeasurable, facts: [],
                                     notes: [sentence(reason)], banner: nil, source: reason == .noFile ? nil : source)
        case .notInstalled:
            return RulesReadOnlyPage(cli: cli, hero: .unmeasurable, heroLabel: unmeasurable, line: "Not installed", facts: [],
                                     notes: ["Codex is not installed on this Mac."], banner: nil, source: nil)
        }
    }

    /// The approval policy as the hero says it, from Codex's `AskForApproval` (`CodexWording`): `on-failure` is an alias
    /// of `on-request`.
    static func approvalPhrase(_ word: String?) -> String {
        switch word {
        case "on-request", "on-failure": "asks on request"
        case "untrusted": "asks unless a rule allows"
        case "never": "never asks"
        case "granular": "granular approvals"
        case nil: "approval not set"
        case let word?: "approval \(word)"
        }
    }

    /// The settings in Codex's own names (the mock's `CLI_RULES.codex.kv`), then what its `.rules` files hold.
    static func facts(_ codex: CoreCodexPermissions) -> [InspectorFact] {
        var out = [
            InspectorFact(key: "Approval policy", value: CodexWording.approval(codex).map(CodexWording.word) ?? "not set"),
            InspectorFact(key: "Sandbox", value: codex.sandboxMode.map(CodexWording.word) ?? "not set"),
        ]
        if let write = codex.sandboxWorkspaceWrite {
            out.append(InspectorFact(key: "Network access", value: write.networkAccess.map { $0 ? "on" : "off" } ?? "not set"))
            if !write.writableRoots.isEmpty {
                out.append(InspectorFact(key: "Writable folders", value: NumberWording.count(write.writableRoots.count)))
            }
        }
        out.append(InspectorFact(key: "Trusted projects", value: NumberWording.count(codex.projects.filter { $0.trustLevel == "trusted" }.count)))
        let rules = codex.rules
        if rules.folderNotReadable {
            out.append(InspectorFact(key: "Command rules", value: "the rules folder can\u{2019}t be read"))
        } else if rules.files > 0 {
            var value = "\(NumberWording.count(rules.allow)) allow \u{00B7} \(NumberWording.count(rules.prompt)) prompt \u{00B7} \(NumberWording.count(rules.forbidden)) forbidden"
            if rules.unreadable > 0 { value += " \u{00B7} \(NumberWording.plural(rules.unreadable, "file")) unreadable" }
            out.append(InspectorFact(key: "Command rules", value: value))
        }
        return out
    }

    private static func sentence(_ reason: CodexReading.Reason) -> String {
        switch reason {
        case .noFile: "There is no \(codexFile), so Codex runs on its own defaults; SpaceVibe does not guess them."
        case .bothModels: "Codex has two permission models set, so its stance cannot be read."
        case .profile: "Codex takes its permissions from a profile, which SpaceVibe does not read."
        case .noSandbox: "sandbox_mode is not set in \(codexFile)."
        case .notRead, .notReadable: "Codex\u{2019}s settings were not read."
        }
    }
}
