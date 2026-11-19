import SwiftUI

/// Everything the UI knows about one CLI: its name, its mark, its colour and the facts its wording depends on. Each value is
/// one entry of `CLIRegistry`; a screen reads these fields and never branches on which CLI it holds (MC-R1).
struct CLIIdentity: Sendable {
    /// The id the core writes on the wire (`claude`, `codex`, `gemini`).
    let id: String
    /// The CLI's name as the app writes it (GLOSSARY).
    let label: String
    let mark: CLIMarkArt
    let tone: CLITone
    /// Where its Limits reading comes from, which decides what the Limits page says before and about a reading.
    let limitsReading: CLILimitsReading
    /// Whether SpaceVibe reads its sessions from a log. Without one, Activity shows a band that says so.
    let readsSessionLog: Bool
    /// Whether it logs hook runs, so a hook only it has can be counted.
    let logsHookRuns: Bool
    /// Whether a subagent with no `tools` line inherits every tool (Claude Code's subagent docs), so a copy made into it, which
    /// carries no `tools` line, can use every tool.
    let subagentWithoutToolsGetsEveryTool: Bool
}

/// A CLI's brand mark: an SVG in `Resources/Brand`. A monochrome mark is drawn as a template in `brandMonochrome`; any other
/// keeps the artwork's own colours.
struct CLIMarkArt: Sendable {
    let fileName: String
    let isMonochrome: Bool
}

/// The colour a CLI carries (identity only, never a state or the accent; `CLIRegistryTests`). Built from a `PaletteValue`
/// token, so a test reads the token's values and a view reads the colour made from it once.
struct CLITone: Sendable {
    /// The identity colour's values.
    let fillValue: ColorValue
    /// How much of the fill a usage bar takes; nil draws the fill as it is.
    let barOpacity: Double?

    /// The identity colour: a mark's stand-in dot.
    let fill: Color
    /// A usage bar's fill (the Skills pane's meters).
    let bar: Color

    init(fill: ColorValue, barOpacity: Double? = nil) {
        fillValue = fill
        self.barOpacity = barOpacity
        let fillColor = fill.color
        self.fill = fillColor
        bar = barOpacity.map { fillColor.opacity($0) } ?? fillColor
    }
}

/// Where a CLI's usage limits are read from.
enum CLILimitsReading: Sendable {
    /// A cache the CLI writes only after it has fetched usage once (`/usage`); the status line can also feed it.
    case usageCache
    /// The limits the CLI logs after each turn.
    case lastTurn
    /// The CLI keeps no usage limit on disk: it reads "not measurable".
    case notKept
}
