import Foundation

/// The one table of per-CLI UI facts (MC-R1, MC17): each CLI's name, mark, colour tokens and the facts its wording reads.
/// Every other file asks this table through `cli.identity` (or the lists below) and never names a CLI itself;
/// `CLIBranchPolicyTests` fails on a CLI literal outside this file and the DTO layer in `Core/`. The facts the core also keeps
/// (id, label, which concepts, hook-run logging, limits reading) must match `core/testdata/cli-registry.json`, which the core
/// writes from its own registry (`CLIRegistryTests`).
///
/// Adding a CLI: add its case to the wire enums in `Core/`, add its entry here and its mark to `Resources/Brand`, and its
/// tokens to `PaletteValue`. The switches below are exhaustive, so the build fails until the entry exists; nothing falls
/// back to another CLI's look.
enum CLIRegistry {
    static let claude = CLIIdentity(
        id: "claude", label: "Claude Code",
        mark: CLIMarkArt(fileName: "claude-spark-clay.svg", isMonochrome: false),
        tone: CLITone(fill: PaletteValue.claude),
        limitsReading: .usageCache, readsSessionLog: true, logsHookRuns: true, approvalLimitCode: "claude-prompt-vs-busy",
        subagentWithoutToolsGetsEveryTool: true)

    /// Codex's colour is the text colour; its bar is a little quieter than Claude's clay.
    static let codex = CLIIdentity(
        id: "codex", label: "Codex",
        mark: CLIMarkArt(fileName: "codex-blossom-white.svg", isMonochrome: true),
        tone: CLITone(fill: PaletteValue.codex, barOpacity: Metrics.Bar.codexOpacity),
        limitsReading: .lastTurn, readsSessionLog: true, logsHookRuns: false, approvalLimitCode: "codex-tool-silent",
        subagentWithoutToolsGetsEveryTool: false)

    /// Gemini CLI has no brand colour in the app, so it reads neutral. It appears on Limits and Activity only.
    static let gemini = CLIIdentity(
        id: "gemini", label: "Gemini CLI",
        mark: CLIMarkArt(fileName: "gemini.svg", isMonochrome: false),
        tone: CLITone(fill: PaletteValue.fg2),
        limitsReading: .notKept, readsSessionLog: false, logsHookRuns: false, approvalLimitCode: nil,
        subagentWithoutToolsGetsEveryTool: false)

    /// The CLIs the inventory, Activity and the copy actions know, in display order.
    static let inventoryCLIs: [CoreCLI] = CoreCLI.allCases
    /// Every CLI the app shows (the Limits reading's), in display order.
    static let limitsCLIs: [CoreLimitsCLI] = CoreLimitsCLI.allCases

    static func identity(_ cli: CoreLimitsCLI) -> CLIIdentity {
        switch cli {
        case .claude: claude
        case .codex: codex
        case .gemini: gemini
        }
    }

    static func identity(_ cli: CoreCLI) -> CLIIdentity { identity(CoreLimitsCLI(cli)) }
}

extension CoreLimitsCLI {
    /// The same CLI as the Limits reading names it.
    init(_ cli: CoreCLI) {
        switch cli {
        case .claude: self = .claude
        case .codex: self = .codex
        }
    }
}

extension CoreCLI {
    /// The inventory's CLI for a Limits CLI, or nil for one the inventory does not list (Gemini CLI).
    init?(_ cli: CoreLimitsCLI) {
        switch cli {
        case .claude: self = .claude
        case .codex: self = .codex
        case .gemini: return nil
        }
    }
}
