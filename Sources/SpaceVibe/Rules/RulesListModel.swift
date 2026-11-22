import Foundation

/// The Rules page's view state that is not in the route (AR3): the CLI page chosen with the CLI pop-up, and the ticked
/// rules of the file shown. The file itself is the route's scope (AR5).
struct RulesViewState: Equatable, Sendable {
    var cli = RulesListModel.editableCLI
    var ticked: Set<String> = []
    /// Project was picked while Claude Code knows no project: the route keeps the global file, the page says so.
    var wantsProjects = false
}

/// One capability row of Claude Code's grid (the mock's `.cap`): the engine's cell (`rules.snapshot` `grid`) with its icon,
/// why line and whether its dial may be pressed.
struct RulesCapabilityRow: Identifiable, Equatable, Sendable {
    let cell: CoreCapabilityCell
    /// False for a Mixed cell (the engine refuses it) and for a file that cannot be read or does not parse.
    let isEditable: Bool

    var id: CoreCapability { cell.capability }
    var label: String { cell.label }
    var isMixed: Bool { cell.state == .mixed }
    /// The dial's chosen step; nil for no rule and for Mixed.
    var selection: CoreVerdict? { CoreVerdict(rawValue: cell.state.rawValue) }

    var icon: FrameIcon {
        switch cell.capability {
        case .read: .eye
        case .edit: .fileText
        case .run: .terminalWindow
        case .network: .plugsConnected
        case .push: .arrowUp
        case .secrets: .lockKey
        }
    }

    /// "Read-only: any: allow · scoped: allow/deny" for Mixed (the mock's `mixedWhy`), "2 rules", or "No rules". A wide rule
    /// is "any"; a path or command rule is "scoped", except under Push and deploy and Secrets, whose own rules are "own".
    var why: String {
        if isMixed {
            let ownsNarrow = cell.capability == .push || cell.capability == .secrets
            let wide = cell.rules.filter(WholeToolRule.isWide), narrow = cell.rules.filter { !WholeToolRule.isWide($0) }
            let parts = [Self.part("any:", wide), ownsNarrow ? nil : Self.part("scoped:", narrow), ownsNarrow ? Self.part("own:", narrow) : nil]
            return "Read-only: " + parts.compactMap { $0 }.joined(separator: " \u{00B7} ")
        }
        return cell.rules.isEmpty ? "No rules" : NumberWording.plural(cell.rules.count, "rule")
    }

    private static func part(_ head: String, _ rules: [CoreRule]) -> String? {
        guard !rules.isEmpty else { return nil }
        let verdicts = CoreVerdict.allCases.filter { verdict in rules.contains { $0.verdict == verdict } }
        return "\(head) \(verdicts.map(\.rawValue).joined(separator: "/"))"
    }
}

/// One rule row of the table (the mock's Rules `.tr`).
struct RulesRuleRow: Identifiable, Equatable, Sendable {
    let rule: CoreRule

    var id: String { rule.id }
    /// An allow that covers a whole tool (the engine's `wide`, RB-E6): the `Whole tool` chip, the red `Remove Rule` and
    /// `Change to Ask`. A bare MCP tool name is never one (RD-R17 Honesty): the engine never flags it.
    var isWideAllow: Bool { rule.verdict == .allow && WholeToolRule.isWide(rule) }

    var permissionIcon: FrameIcon {
        switch rule.verdict {
        case .allow: .check
        case .ask: .question
        case .deny: .prohibit
        }
    }
}

/// What the Claude Code page draws below the hero.
enum RulesPhase: Equatable, Sendable {
    /// The file has not been read yet: the scanning band and skeleton rows.
    case loading
    /// The file could not be read and nothing was read before.
    case failed(String)
    /// Rules › Project with no project known to Claude Code.
    case noProjects
    /// The project shown is no longer listed (the last refresh dropped it).
    case projectGone
    /// The file holds no rule: the empty state with `Add Rule…`.
    case empty
    case normal
}

/// The toolbar's fixed slot (RD-R17 Layout): `Add Rule…` (the page's one primary, RD11), `Remove N selected` once rules are
/// ticked, or nothing while there is nothing to act on.
enum RulesPrimary: Equatable, Sendable {
    case none, addRule
    case removeSelected(Int)
}

/// Everything the Rules page shows, derived from the store's readings and the page's view state. Pure (AR3), so the tests
/// drive it. The reference mock's `pageRules` (`src/d-hooks-rules.js`): one page per CLI, Claude Code's editable, every
/// other CLI read only in its own terms (the owner's 2026-11-04 pick).
struct RulesListModel: Equatable {
    /// The one CLI whose rules SpaceVibe writes.
    static let editableCLI = "claude"
    /// The other CLIs' lines beside the hero before `+N more CLIs`.
    static let summaryLimit = 3

    let cliOptions: [CLIMenuEntries.Option]
    /// The CLI page shown: the chosen one while it has Rules, else Claude Code.
    let cli: CoreRegistryCLI
    /// Every other shown CLI with Rules, each in its own terms; the first `summaryLimit` stand beside Claude Code's hero.
    let others: [RulesReadOnlyPage]

    // Claude Code's page
    let file: FrameScope
    let fileName: String
    let projects: [RulesProject]
    let hero: PageHero.Figure
    let heroLabel: String
    let phase: RulesPhase
    /// The file cannot be read or does not parse: the band says so, and nothing on the page writes (mock "not shown").
    let problem: String?
    let capabilities: [RulesCapabilityRow]
    let rows: [RulesRuleRow]
    let ticked: Set<String>
    /// The toolbar's search (⌘F): `rows` keeps only the rules whose text it matches; the hero, the grid and the strip count
    /// every rule.
    let query: FrameSearchQuery

    /// The search hides every rule of the file: "No rules match" with Clear Search.
    var isSearchMiss: Bool { phase == .normal && !query.isEmpty && rows.isEmpty }

    var isClaudePage: Bool { cli.id == Self.editableCLI }
    var isGlobal: Bool { file == .global && phase != .noProjects }
    var isWritable: Bool { problem == nil && (phase == .normal || phase == .empty) }
    /// The CLI page shown when it is not Claude Code's.
    var readOnly: RulesReadOnlyPage? { isClaudePage ? nil : others.first { $0.cli.id == cli.id } }
    var shownSummaries: [RulesReadOnlyPage] { Array(others.prefix(Self.summaryLimit)) }
    var hiddenSummaryCount: Int { max(0, others.count - Self.summaryLimit) }

    /// The ticked rules among those shown: what `Remove N selected` takes, all from the one file shown.
    var removal: [CoreRule] { isWritable ? rows.filter { ticked.contains($0.id) }.map(\.rule) : [] }

    var primary: RulesPrimary {
        guard isClaudePage, isWritable, phase == .normal else { return .none }
        return removal.isEmpty ? .addRule : .removeSelected(removal.count)
    }

    var project: RulesProject? { projects.first { $0.dir == file.dir } }

    func row(_ id: String?) -> RulesRuleRow? { rows.first { $0.id == id } }

    /// The rule table's zebra, as the mock's group draws it (`.tr:nth-child(odd)`, `style.css:142`): the head row is the
    /// group's first child, so the second rule, the fourth and so on carry the stripe.
    static func isStriped(_ index: Int) -> Bool { !index.isMultiple(of: 2) }

    /// The capability a rule belongs to, by the engine's grid; nil for a rule outside the six (a `Skill` or MCP rule).
    func capability(of rule: CoreRule) -> RulesCapabilityRow? { capabilities.first { $0.cell.rules.contains { $0.id == rule.id } } }

    /// "Global", or "Project · payments-web · Shared".
    var scopeTitle: String {
        guard let project else { return "Global" }
        return "Project \u{00B7} \(project.name) \u{00B7} \(file.scope == .local ? "Local" : "Shared")"
    }

    // MARK: Building

    /// From the store's world, the states of its sources and the route's file.
    @MainActor
    static func from(_ store: FrameStore, view: RulesViewState, file: FrameScope, query: FrameSearchQuery = FrameSearchQuery(""),
                     now: Date = Date()) -> RulesListModel {
        let world = store.world(now: now)
        return RulesListModel(world: world, states: store.states, file: file, view: view,
                              figure: world.figure(for: .rules, loading: store.loading, failed: store.failedEmpty), query: query)
    }

    init(world: FrameWorld, states: [FrameSource: FrameSourceState], file: FrameScope, view: RulesViewState, figure: PageFigure,
         query: FrameSearchQuery = FrameSearchQuery("")) {
        self.query = query
        let snapshot = world.snapshot
        let global = snapshot.rules[.global]
        let supported = world.clis.filter(\.supports.rule)
        cliOptions = world.clis.map { cli in
            CLIMenuEntries.Option(cli: CLIIdentity(id: cli.id, name: cli.name), isSupported: cli.supports.rule, isReadOnly: cli.id != Self.editableCLI)
        }
        let claude = world.clis.first { $0.id == Self.editableCLI }
            ?? CoreRegistryCLI(id: Self.editableCLI, name: "Claude Code", supports: CoreRegistrySupports(skill: true, agent: true, hook: true, rule: true, logs: true, limits: true))
        cli = supported.first { $0.id == view.cli } ?? claude
        others = supported.filter { $0.id != Self.editableCLI }.map { RulesReadOnlyPage.of($0, global: global, state: states[.rules(.global)]) }

        projects = RulesScopes.projects(from: global?.projectDirs ?? [])
        self.file = file
        fileName = Self.fileName(file, projects: projects)
        ticked = view.ticked

        let count: Int? = if case .count(let n, _) = figure { n } else { nil }
        hero = switch figure {
        case .pending: .scanning
        case .count(let n, _): .value(NumberWording.count(n), unit: nil)
        default: .unmeasurable
        }
        heroLabel = Self.heroLabel(count: count, wideAllows: world.wideAllows)

        let reading = snapshot.rules[file]
        let state = states[.rules(file)]
        let readingMatches = reading.map { $0.scope == file.scope && $0.dir == file.dir } ?? false
        if file == .global, view.wantsProjects {
            phase = .noProjects
        } else if file != .global, global != nil, !(global?.projectDirs ?? []).contains(file.dir ?? "") {
            phase = .projectGone
        } else if let reading, readingMatches {
            phase = reading.rules.isEmpty && !reading.notReadable && reading.problems.isEmpty ? .empty : .normal
        } else if case .failed(let message) = state {
            phase = .failed(message)
        } else {
            phase = .loading
        }

        if let reading, readingMatches, phase == .normal || phase == .empty {
            let editable = RulesSnapshot(reading)
            problem = reading.notReadable || !reading.problems.isEmpty
                ? (reading.problems.first ?? "\(fileName) could not be read, so its rules are unknown, not empty.") : nil
            capabilities = reading.grid.map { RulesCapabilityRow(cell: $0, isEditable: editable.isEditable($0)) }
            rows = reading.rules.filter { $0.scope == file.scope && $0.dir == file.dir && query.matches([$0.rule]) }
                .sorted { $0.rule.localizedCompare($1.rule) == .orderedAscending }
                .map(RulesRuleRow.init)
        } else {
            problem = nil
            capabilities = []
            rows = []
        }
    }

    /// "2 rules allow a whole tool · 1 in Global, 1 in a project": every file is counted, as in Inbox and the sidebar
    /// ("Inferred, not decided": Project rules in Inbox), and the label says where once a project file holds one.
    static func heroLabel(count: Int?, wideAllows: [(rule: CoreRule, file: FrameScope)]) -> String {
        let head = count == 1 ? "rule allows a whole tool" : "rules allow a whole tool"
        guard count != nil else { return head }
        let inGlobal = wideAllows.filter { $0.file == .global }.count, inProjects = wideAllows.count - inGlobal
        guard inProjects > 0 else { return head }
        return head + " \u{00B7} \(NumberWording.count(inGlobal)) in Global, \(NumberWording.count(inProjects)) in \(inProjects == 1 ? "a project" : "projects")"
    }

    /// The file as the page names it: `~/.claude/settings.json`, `payments-web/.claude/settings.local.json`.
    static func fileName(_ file: FrameScope, projects: [RulesProject]) -> String {
        guard let dir = file.dir else { return "~/.claude/settings.json" }
        let name = projects.first { $0.dir == dir }?.name ?? (dir as NSString).lastPathComponent
        return "\(name)/.claude/settings\(file.scope == .local ? ".local" : "").json"
    }
}
