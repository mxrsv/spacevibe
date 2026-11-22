import SwiftUI

/// The Inbox inspector (the reference mock's `inboxInspector`): what the selected finding is about, by its kind. A Window shows
/// its meter and facts, a waiting session its process, a Rule its file, a Hook its command, a Skill or Subagent its CLI tiles.
/// Nothing selected shows the empty state (RD41: nothing is pre-selected).
struct InboxInspector: View {
    let row: InboxRowModel?
    let world: FrameWorld
    let now: Date
    let actions: InboxActions
    let hasRows: Bool

    @Environment(ToastCenter.self) private var toasts

    var body: some View {
        let actions = actions.using(toasts)
        if let row {
            VStack(alignment: .leading, spacing: SpaceRole.step16) {
                switch row.finding.subject {
                case .window(let pace): window(pace)
                case .session(let session): self.session(session, row: row, actions: actions)
                case .rule(let rule, let file): self.rule(rule, file: file, row: row, actions: actions)
                case .failingHook(let item, let errors): hook(item, errorsLastWeek: errors, actions: actions)
                case .row(let item) where item.kind == .hook:
                    hook(item, errorsLastWeek: world.facts.findings.hookErrorsLastWeek?[item.id], actions: actions)
                case .row(let item), .balance(let item, _, _): self.item(item, row: row, actions: actions)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            PageEmptyState(icon: .sidebarSimple, text: hasRows ? "Select a row to see its details." : "Nothing selected.")
        }
    }

    private var wording: InboxWording { InboxWording(world: world, now: now) }

    // MARK: Window

    @ViewBuilder
    private func window(_ pace: WindowPace) -> some View {
        let entry = world.snapshot.limits?.limits.first { $0.cli.rawValue == pace.cli }
        InspectorTitle(wording.windowTitle(pace)) { FrameGlyph(.limits, side: SizeRole.icon20, ink: ColorRole.ink3) }
        ShareMeter(share: (pace.left ?? 0) / 100, height: .hero, tone: pace.severity == .critical ? .critical : .attention,
                   paceTick: pace.timeLeft.map { min(0.98, $0 / 100) }, label: "Left")
        KeyValueList(facts: InboxInspectorFacts.window(pace, entry: entry, now: now))
    }

    // MARK: Session

    @ViewBuilder
    private func session(_ session: CoreActivitySession, row: InboxRowModel, actions: InboxActions) -> some View {
        let cli = CLIIdentity(id: session.cli.rawValue, name: world.cliName(session.cli.rawValue))
        InspectorTitle(session.title) { CLILogo(cli, size: SizeRole.logo20) }
        InspectorNote(cli.name)
        KeyValueList(facts: InboxInspectorFacts.session(session))
        InspectorSection("Current tool") {
            if let tool = session.currentTool {
                CommandBlock("\(tool.name)\n\(tool.target)")
            } else {
                InspectorNote("None running.")
            }
        }
        InspectorNote("Answer in the terminal. SpaceVibe only shows that it is waiting.", icon: .infoFill)
        InspectorActions(actions: [
            row.actions.first { $0.id == InboxAction.terminalNotFound.id }.map { terminal in
                InspectorAction(id: "terminal", title: terminal.title, icon: .terminalWindow, isEnabled: terminal.isEnabled) {
                    actions.perform(terminal, on: row)
                }
            },
            InspectorAction(id: "copyID", title: "Copy Session Id", icon: .copy) { actions.copy(session.id) },
        ].compactMap { $0 })
    }

    // MARK: Rule

    /// The mock's `ruleInspector`: the rule, its Capability, Scope and File, the whole-tool warning, and the Allow / Ask /
    /// Deny dial (RD46), which writes the rule's own file with Undo and waits while that write runs.
    @ViewBuilder
    private func rule(_ rule: CoreRule, file: FrameScope, row: InboxRowModel, actions: InboxActions) -> some View {
        InspectorTitle("Rule") { FrameGlyph(.rules, side: SizeRole.icon20, ink: ColorRole.toneRules) }
        CommandBlock(rule.rule)
        KeyValueList(facts: InboxInspectorFacts.rule(rule, file: file, world: world))
        InspectorNote(RulesWriteWording.wholeToolWarning, icon: .warningFill, iconInk: ColorRole.stateAttention)
        InspectorSection("Permission") {
            // Pending at the control while a change writes (FE-L2): the step it is moving to shows the pending mark and no
            // step takes a press until the write is done.
            // A change of the same rule started on another page has no step to show: the dial is then disabled instead.
            let pending = actions.pendingVerdict(rule, in: file)
            PermissionDial(selection: rule.verdict, label: "Permission", pending: pending) {
                actions.changeVerdict(rule, in: file, to: $0)
            }
            .disabled(pending == nil && actions.isPending(.changeToAsk, row))
        }
    }

    // MARK: Hook

    @ViewBuilder
    private func hook(_ item: FrameRow, errorsLastWeek: Int?, actions: InboxActions) -> some View {
        let hook = item.hooks.first
        // A Hook's name is its script, in mono as the mock's `hookInspector` title.
        InspectorTitle(item.name, isMono: true) { FrameGlyph(.hooks, side: SizeRole.icon20, ink: ColorRole.toneHooks) }
        if let hook {
            let matcher = hook.matcher.map { " · Matcher \($0)" } ?? ""
            InspectorNote("\(hook.event)\(matcher) · \(world.cliName(hook.cli.rawValue))")
            InspectorSection("Command") { CommandBlock(hook.command) }
        }
        KeyValueList(facts: InboxInspectorFacts.hook(item, errorsLastWeek: errorsLastWeek, cliName: world.cliName, now: now))
        if let hook {
            InspectorActions(actions: [InspectorAction(id: "copy", title: "Copy Command", icon: .copy) { actions.copy(hook.command) }])
        }
    }

    // MARK: Skill or Subagent

    @ViewBuilder
    private func item(_ item: FrameRow, row: InboxRowModel, actions: InboxActions) -> some View {
        let isAgent = item.kind == .agent
        InspectorTitle(item.name) {
            FrameGlyph(isAgent ? .subagents : .skills, side: SizeRole.icon20, ink: isAgent ? ColorRole.toneSubagents : ColorRole.toneSkills)
        }
        if let description = item.items.first?.description, !description.isEmpty {
            InspectorNote(description)
        }
        InspectorActions(actions: InboxInspectorFacts.itemActions(row).map { action in
            InspectorAction(id: action.id, title: InboxInspectorFacts.itemActionTitle(action),
                            icon: action.isDestructive ? .trash : nil, isLoading: actions.isPending(action, row),
                            isDestructive: action.isDestructive) { actions.perform(action, on: row) }
        })
        InspectorSection("CLIs") {
            let states = CLIToggleStates.states(of: item, in: world)
            CLITileGrid(states: states, toggle: { actions.toggleTile($0, row: item) },
                        pending: actions.isItemBusy(item.id) ? Set(states.map(\.cli.id)) : [])
        }
        KeyValueList(facts: InboxInspectorFacts.item(item, world: world, now: now))
        if let path = item.items.first?.path {
            InspectorActions(actions: [InspectorAction(id: "finder", title: "Show in Finder", icon: .folderOpen) { actions.showInFinder(path) }])
        }
    }
}

/// The inspector's facts per kind, as label and value. Pure, so the tests read them.
enum InboxInspectorFacts {
    /// The buttons of a Skill or Subagent finding's inspector: a Clean up row's `Remove` (`Remove…` when it asks); a Balance
    /// finding's `Add to <CLI>` and Keep only, never a removal (it is the most-used item).
    static func itemActions(_ row: InboxRowModel) -> [InboxAction] {
        switch row.finding.subject {
        case .balance: row.actions.filter { if case .addTo = $0 { true } else { false } } + row.actions.filter { $0 == .keep || $0 == .stopKeeping }
        default: row.actions.filter(\.isDestructive)
        }
    }

    /// A button's title there: a removal is the short `Remove`, with the ellipsis only when it asks first (a file another CLI
    /// reads, as the row's `Remove…`); a removal that goes at once with Undo has none. Every other action keeps its title.
    static func itemActionTitle(_ action: InboxAction) -> String {
        if case .remove(_, let asks) = action { return asks ? "Remove\u{2026}" : "Remove" }
        return action.title
    }

    static func window(_ pace: WindowPace, entry: CoreLimitsEntry?, now: Date) -> [InspectorFact] {
        let left = pace.over > 0 ? "0% · over by \(InboxWording.percent(pace.over))" : InboxWording.percent(pace.left ?? 0)
        let time = pace.timeLeft.map { "\(Int($0.rounded()))%" } ?? "No window length"
        let resetsIn = LimitsWording.resetsIn(pace.window, now: now).map { ", in \($0)" } ?? ""
        var facts: [InspectorFact] = [
            InspectorFact(key: "Left", value: left),
            InspectorFact(key: "Time left", value: time),
            InspectorFact(key: "Resets", value: "\(LimitsWording.resetsAt(pace.window, now: now))\(resetsIn)"),
        ]
        if let entry, let source = LimitsWording.source(entry) {
            let age = entry.at.map { ", \(LimitsWording.readAge(at: Date(timeIntervalSince1970: $0), now: now))" } ?? ""
            facts.append(InspectorFact(key: "Source", value: "\(source.title)\(age)"))
        }
        return facts
    }

    /// Capability (the engine's grid of the rule's own file; "No capability" for a rule outside the six), Scope and File.
    static func rule(_ rule: CoreRule, file: FrameScope, world: FrameWorld) -> [InspectorFact] {
        let capability = world.snapshot.rules[file]?.grid.first { cell in cell.rules.contains { $0.id == rule.id } }
        return [
            InspectorFact(key: "Capability", value: capability?.label ?? "No capability"),
            InspectorFact(key: "Scope", value: file.dir == nil ? "Global" : "Project · \(InboxWording.place(file))"),
            InspectorFact(key: "File", value: InboxWording.settingsFile(file), isMono: true),
        ]
    }

    static func session(_ session: CoreActivitySession) -> [InspectorFact] {
        let reason = session.stateReason.isEmpty ? "" : " · \(session.stateReason)"
        var facts: [InspectorFact] = [
            InspectorFact(key: "Project", value: session.project ?? "No project"),
            InspectorFact(key: "State", value: "Waiting\(reason)"),
            InspectorFact(key: "Process", value: "\(session.pid)"),
        ]
        if let age = session.ageMs { facts.append(InspectorFact(key: "Age", value: ActivityFormat.span(age))) }
        let cost = session.cost.map { "\(NumberWording.money($0.usd)) (estimate, API-equivalent rates)" }
            ?? "Unmeasurable: \(session.costNote ?? "no price or no log")"
        facts.append(InspectorFact(key: "Cost", value: cost))
        return facts
    }

    static func hook(_ item: FrameRow, errorsLastWeek: Int?, cliName: (String) -> String, now: Date) -> [InspectorFact] {
        guard let hook = item.hooks.first else { return [] }
        var facts: [InspectorFact] = []
        switch item.cell(hook.cli.rawValue) {
        case .runs(let runs, let errors, _, _, _):
            facts.append(InspectorFact(key: "Runs", value: NumberWording.count(runs)))
            if item.isDead { facts.append(InspectorFact(key: "Script", value: "File is missing")) }
            if errors > 0 || (errorsLastWeek ?? 0) > 0 {
                let week = errorsLastWeek.map { "\(NumberWording.count($0)) in 7 days · " } ?? ""
                facts.append(InspectorFact(key: "Errors", value: "\(week)\(NumberWording.count(errors)) of \(NumberWording.plural(runs, "run")) in all"))
            }
        case .unmeasurable:
            facts.append(InspectorFact(key: "Runs", value: "Unmeasurable: \(cliName(hook.cli.rawValue)) logs no Hook runs"))
            if item.isDead { facts.append(InspectorFact(key: "Script", value: "File is missing")) }
        default:
            if item.isDead { facts.append(InspectorFact(key: "Script", value: "File is missing")) }
        }
        if let seen = item.firstSeen {
            facts.append(InspectorFact(key: "Added", value: added(seen, now: now)))
        }
        facts.append(InspectorFact(key: "File", value: (hook.file as NSString).abbreviatingWithTildeInPath, isMono: true))
        return facts
    }

    /// Owner, the files (one fact for the item's own files, one for the shared ones with who reads them), Added. Keys stay
    /// unique: the list keys its lines by them.
    static func item(_ item: FrameRow, world: FrameWorld, now: Date) -> [InspectorFact] {
        var facts = [InspectorFact(key: "Owner", value: "You")]
        let readers = world.readers(of: item)
        var own: [String] = [], shared: [String] = [], seen: Set<String> = []
        for member in item.items where seen.insert(member.path).inserted {
            let readBy = readers?.members.first { $0.id == member.id }?.readBy.filter { id in world.clis.contains { $0.id == id } } ?? []
            let path = (member.path as NSString).abbreviatingWithTildeInPath
            if readBy.count > 1 { shared.append("\(path), read by \(CLINames.sentence(readBy.map(world.cliName)))") } else { own.append(path) }
        }
        if !own.isEmpty { facts.append(InspectorFact(key: own.count == 1 ? "File" : "Files", value: own.joined(separator: "\n"), isMono: true)) }
        if !shared.isEmpty { facts.append(InspectorFact(key: "Shared", value: shared.joined(separator: "\n"), isMono: true)) }
        if let seen = item.firstSeen { facts.append(InspectorFact(key: "Added", value: added(seen, now: now))) }
        return facts
    }

    /// "3 days ago": the D63 note without its leading "added".
    static func added(_ date: Date, now: Date) -> String {
        let text = DayWording.added(secondsAgo: now.timeIntervalSince(date))
        return text.hasPrefix("added ") ? String(text.dropFirst("added ".count)) : text
    }
}
