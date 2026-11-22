import SwiftUI

/// Synthetic data for the frame blocks' gallery (S-R2: invented names only), with the break-ui extremes: 10 CLIs, a long
/// unbroken name, a non-Latin name, huge counts. The 8 CLIs after Claude Code and Codex are the mock's illustration (engine
/// support beyond the two is out of scope), drawn with their initial as a stand-in logo.
enum FrameSpecimenData {
    static let clis: [CLIIdentity] = [
        .claude, .codex,
        CLIIdentity(id: "cursor", name: "Cursor CLI"), CLIIdentity(id: "copilot", name: "Copilot CLI"),
        CLIIdentity(id: "opencode", name: "opencode"), CLIIdentity(id: "amp", name: "Amp"),
        CLIIdentity(id: "antigravity", name: "Antigravity CLI"), CLIIdentity(id: "kiro", name: "Kiro"),
        CLIIdentity(id: "qwen", name: "Qwen Code"), CLIIdentity(id: "aider", name: "Aider"),
    ]

    static func cli(_ index: Int) -> CLIIdentity { clis[index % clis.count] }

    static let longName = "migrate-tailwind-utility-classes-across-the-whole-monorepo-and-every-storybook-story"
    static let arabicName = "مراجعة-طلبات-الدمج"
    static let longPath = "~/Development/payments-web/.claude/skills/migrate-tailwind-utility-classes-across-the-whole-monorepo"

    /// One toggle state per row-toggle state the spec lists (RD-R11, RD-R16), in the 10 CLIs' order.
    static let everyToggleState: [(String, CLIToggleState)] = [
        ("On", CLIToggleState(cli: .claude, presence: .on(.sessions(31)))),
        ("On · shared", CLIToggleState(cli: .codex, presence: .on(.sessions(12)), sharedWith: ["Cursor CLI", "Amp"])),
        ("Never ran (owner)", CLIToggleState(cli: cli(2), presence: .on(.neverRan))),
        ("Never ran (reads)", CLIToggleState(cli: cli(3), presence: .on(.neverRan), ownsFile: false)),
        ("Off", CLIToggleState(cli: cli(4), presence: .off)),
        ("Off · no folder", CLIToggleState(cli: cli(7), presence: .off, hold: .noCopyTarget(folder: "skills"))),
        ("Via", CLIToggleState(cli: cli(5), presence: .on(.sessions(4)), hold: .via(["Claude Code"]))),
        ("Last copy", CLIToggleState(cli: .claude, presence: .on(.sessions(24)), hold: .lastCopy)),
        ("Unmeasurable", CLIToggleState(cli: cli(6), presence: .on(.unmeasurable))),
        ("Not supported", CLIToggleState(cli: cli(9), presence: .notSupported(noun: "Skills"))),
        ("Plugin", CLIToggleState(cli: .claude, presence: .on(.sessions(4)), hold: .readOnly(owner: "design-kit plugin"))),
        ("Unknown ?", CLIToggleState(cli: .codex, presence: .unreadable)),
        ("Pending", CLIToggleState(cli: .claude, presence: .on(.pending))),
    ]

    /// A Skill's states across the first `count` CLIs, with a mix of heat, a huge count and the odd states.
    static func row(_ count: Int) -> [CLIToggleState] {
        let sessions = [4_830_112, 27, 14, 0, 9, 4, 5, 3, 0, 0]
        return (0 ..< count).map { index in
            let cli = cli(index)
            switch index {
            case 3: return CLIToggleState(cli: cli, presence: .off)
            case 5: return CLIToggleState(cli: cli, presence: .on(.sessions(sessions[index])), hold: .via(["Claude Code"]))
            case 6: return CLIToggleState(cli: cli, presence: .on(.unmeasurable))
            case 7: return CLIToggleState(cli: cli, presence: .on(.neverRan))
            case 8: return CLIToggleState(cli: cli, presence: .notSupported(noun: "Skills"))
            case 9: return CLIToggleState(cli: cli, presence: .notSupported(noun: "Skills"))
            default: return CLIToggleState(cli: cli, presence: .on(.sessions(sessions[index])))
            }
        }
    }
}

/// The gallery's two themes side by side, each on the canvas, so every block shows dark and light at once (DS-R10). The
/// blocks' `ColorRole` colours follow the column's colour scheme.
struct FrameSpecimenColumns<Content: View>: View {
    @ViewBuilder var content: Content
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.materialLook) private var look

    /// One column at the full width, in the appearance it is shown in: each shot (`-dark`, `-light`, `-ic`) is one case, and
    /// nothing is cut at the right edge as two side-by-side columns were.
    var body: some View {
        VStack(alignment: .leading, spacing: SpaceRole.step16) {
            Text("\(colorScheme == .dark ? "Dark" : "Light") · \(look == .glass ? "Glass" : "Solid")\(ColorRoleValue.increasesContrast ? " · Increase Contrast" : "")")
                .typeRole(.pageTitle)
                .foregroundStyle(ColorRole.ink)
            content
        }
        .padding(SpaceRole.step24)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(ColorRole.canvasSurface)
    }
}

/// A labelled block on the group surface inside a column.
struct FrameSpecimenGroup<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: SpaceRole.step10) {
            Text(title).typeRole(.quiet).foregroundStyle(ColorRole.ink3)
            content
        }
        .padding(SpaceRole.step12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: RadiusRole.step10, style: .continuous).fill(ColorRole.groupSurface))
    }
}

/// A caption over one specimen.
struct FrameSpecimenCaption: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text).typeRole(.axisCaption).foregroundStyle(ColorRole.ink3).lineLimit(1)
    }
}
