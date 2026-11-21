import Foundation
import Testing
@testable import SpaceVibe

/// The engine the Skills and Subagents write tests talk to: the shot data's rows at 2 or 6 CLIs, and a log of every write
/// with what it was sent. A refusal answers 409 on every write.
final class EquipFakeCore: UnservedCore, @unchecked Sendable {
    let registry: [CoreRegistryCLI]
    let rows: CoreLoadoutRows
    var refuses = false
    private let lock = NSLock()
    private var _writes: [String] = []
    var writes: [String] { lock.withLock { _writes } }

    init(clis: Int, kind: CoreKind = .skill) {
        registry = EquipShotData.registry(count: clis)
        rows = EquipShotData.loadout(kind, specs: kind == .skill ? EquipShotData.skills : EquipShotData.subagents, registry: registry,
                                     now: Date())
    }

    private func write(_ line: String) throws -> CoreJournalEntry {
        lock.withLock { _writes.append(line) }
        if refuses { throw CoreError("Couldn’t remove commit-helper: ~/.claude/skills changed since SpaceVibe read it. Nothing changed.", status: 409) }
        return FrameTestData.entry("e\(writes.count)")
    }

    override func clisRegistry() async throws -> CoreRegistryResult { CoreRegistryResult(clis: registry) }
    override func loadoutRows() async throws -> CoreLoadoutRows { rows }
    override func usageScan(progress: (@Sendable (CoreUsageProgress) -> Void)?) async throws -> CoreUsageResult {
        let cli = CoreCLITotals(skill: [:], agent: [:], hook: [:])
        let window = CoreLogWindow(files: 0, oldest: nil, newest: nil)
        return CoreUsageResult(totals: CoreUsageTotals(claude: cli, codex: cli), sessions: CoreUsageSessions(claude: 0, codex: 0),
                               windows: CoreUsageWindows(claude: window, codex: window), files: 0)
    }
    override func journalHistory() async throws -> CoreJournalHistory { CoreJournalHistory(entries: []) }
    override func findingsKept() async throws -> CoreKeptFindings { CoreKeptFindings(kept: []) }
    override func loadoutCopyTo(id: String, targets: [String]) async throws -> CoreCopyToResult {
        CoreCopyToResult(entry: try write("copyTo \(id) \(targets)"), alsoReaders: [])
    }
    override func loadoutRemoveFrom(id: String, clis: [String]) async throws -> CoreRemoveFromResult {
        CoreRemoveFromResult(entry: try write("removeFrom \(id) \(clis)"), lost: clis, stillHave: [])
    }
    override func loadoutRemoveMany(ids: [String]) async throws -> CoreRemoveManyResult {
        CoreRemoveManyResult(entry: try write("removeMany \(ids)"), lost: ["claude", "opencode"])
    }
}

/// Every write path of the Skills and Subagents page, over the fake engine (build-review list, RB-R2): a logo or tile turned
/// on (`loadout.copyTo`), turned off where only that CLI reads the file (`loadout.removeFrom`), a shared file confirmed
/// (`loadout.removeMany` with exactly the members named, or a copy first), the per-CLI sheet (one `loadout.removeMany`, or one
/// `loadout.copyTo` per row), each with its Undo; the refusal paths; and the presses that must write nothing.
@Suite("Skills and Subagents writes")
@MainActor
struct EquipWritesTests {
    /// The page state holds its model weakly (one per frame, dropped with it): the test keeps the model alive.
    @MainActor
    final class Models {
        var all: [FrameModel] = []
    }

    private let models = Models()

    private func setUp(clis: Int = 2, kind: EquipKind = .skills) async -> (EquipFakeCore, FrameModel, EquipPageState, ToastCenter) {
        let core = EquipFakeCore(clis: clis, kind: kind.kind)
        let toasts = ToastCenter(announce: false)
        let model = FrameModel(core: core, toasts: toasts, route: FrameRoute(page: kind.page))
        await model.store.start()
        model.store.stop()
        models.all.append(model)
        return (core, model, EquipPageState.of(model, kind: kind), toasts)
    }

    private func toggle(_ state: EquipPageState, _ id: String, _ cli: String) -> (EquipListRow, CLIToggleState)? {
        guard let row = state.list().row(id), let toggle = row.toggles.first(where: { $0.cli.id == cli }) else { return nil }
        return (row, toggle)
    }

    @Test("an off logo copies into that CLI (copyTo) and the toast offers Undo")
    func turnOn() async throws {
        let (core, _, state, toasts) = await setUp()
        let (row, codex) = try #require(toggle(state, "skill::changelog-writer", "codex"))
        await state.press(codex, on: row, from: .row)?.value
        #expect(core.writes == ["copyTo claude:skill:changelog-writer [\"codex\"]"])
        #expect(toasts.current?.message == "Added changelog-writer to Codex" && toasts.undoStack.count == 1)
    }

    @Test("an on logo whose file only that CLI reads is removed from it (removeFrom), with Undo")
    func turnOff() async throws {
        let (core, _, state, toasts) = await setUp()
        let (row, claude) = try #require(toggle(state, "skill::commit-helper", "claude"))
        await state.press(claude, on: row, from: .row)?.value
        #expect(core.writes == ["removeFrom claude:skill:commit-helper [\"claude\"]"])
        #expect(toasts.current?.message == "Removed commit-helper from Claude Code" && toasts.undoStack.count == 1)
    }

    @Test("the last copy, a via logo and a plugin's logo write nothing")
    func heldLogos() async throws {
        let (core, _, state, _) = await setUp(clis: 6)
        let (last, lastClaude) = try #require(toggle(state, "skill::changelog-writer", "claude"))
        #expect(state.press(lastClaude, on: last, from: .row) == nil)
        let (shared, cursor) = try #require(toggle(state, "skill::commit-helper", "cursor"))
        #expect(state.press(cursor, on: shared, from: .tile) == nil)
        let (plugin, pluginClaude) = try #require(toggle(state, "skill::brand-voice", "claude"))
        #expect(state.press(pluginClaude, on: plugin, from: .row) == nil)
        #expect(core.writes.isEmpty && state.shared == nil)
    }

    @Test("a shared file asks first; Remove for N CLIs removes exactly the members named, in one removeMany")
    func sharedRemove() async throws {
        let (core, _, state, toasts) = await setUp(clis: 6)
        let (row, claude) = try #require(toggle(state, "skill::commit-helper", "claude"))
        #expect(state.press(claude, on: row, from: .row) == nil)
        #expect(core.writes.isEmpty, "nothing is written before the confirmation")
        #expect(state.shared?.anchor == .row && state.shared?.removal.wording.removeTitle == "Remove for 2 CLIs")
        await state.confirmShared(copyFirst: false)?.value
        #expect(core.writes == ["removeMany [\"claude:skill:commit-helper\"]"])
        #expect(state.shared == nil && toasts.current?.message == "Removed commit-helper from Claude Code and opencode")
    }

    @Test("Copy to …, then remove: the copy first, then the removal, each with its Undo")
    func sharedCopyThenRemove() async throws {
        let (core, _, state, toasts) = await setUp(clis: 6)
        let (row, claude) = try #require(toggle(state, "skill::commit-helper", "claude"))
        state.press(claude, on: row, from: .tile)
        await state.confirmShared(copyFirst: true)?.value
        #expect(core.writes == ["copyTo claude:skill:commit-helper [\"opencode\"]", "removeMany [\"claude:skill:commit-helper\"]"])
        #expect(toasts.undoStack.count == 2)
    }

    @Test("a refused copy stops before the removal and shows the refusal")
    func sharedCopyRefused() async throws {
        let (core, _, state, toasts) = await setUp(clis: 6)
        core.refuses = true
        let (row, claude) = try #require(toggle(state, "skill::commit-helper", "claude"))
        state.press(claude, on: row, from: .tile)
        await state.confirmShared(copyFirst: true)?.value
        #expect(core.writes == ["copyTo claude:skill:commit-helper [\"opencode\"]"])
        #expect(toasts.current?.tone == .danger && toasts.undoStack.isEmpty)
    }

    @Test("Remove from… in the sheet: one removeMany of every member the ticked CLIs read, then the sheet closes and the ticks go")
    func sheetRemove() async {
        let (core, _, state, toasts) = await setUp(clis: 6)
        state.toggle("skill::commit-helper")
        state.openSheet(.remove, rows: state.list().picked.map(\.id))
        #expect(state.sheet?.ticked.isEmpty == true)
        #expect(state.confirmSheet() == nil, "nothing ticked: the button does nothing")
        state.sheetToggle("claude")
        state.sheetToggle("codex")
        state.sheetToggle("cursor")
        await state.confirmSheet()?.value
        #expect(core.writes == ["removeMany [\"claude:skill:commit-helper\", \"agents:skill:commit-helper\"]"])
        #expect(state.sheet == nil && state.view.ticked.isEmpty && toasts.undoStack.count == 1)
    }

    @Test("Add to… for several rows: one copyTo per row that lacks it; switching mode clears the ticks")
    func sheetAdd() async {
        let (core, _, state, _) = await setUp()
        state.openSheet(.remove, rows: ["skill::changelog-writer", "skill::review-pr", "skill::lint-fixer"])
        state.sheetToggle("claude")
        state.sheetSwitch(.add)
        #expect(state.sheet?.mode == .add && state.sheet?.ticked.isEmpty == true)
        state.sheetToggle("codex")
        await state.confirmSheet()?.value
        #expect(core.writes == ["copyTo claude:skill:changelog-writer [\"codex\"]", "copyTo claude:skill:review-pr [\"codex\"]"])
    }

    @Test("a refused sheet removal shows the refusal with no Undo and still closes the sheet")
    func sheetRefused() async {
        let (core, _, state, toasts) = await setUp()
        core.refuses = true
        state.openSheet(.remove, rows: ["skill::commit-helper"])
        state.sheetToggle("claude")
        await state.confirmSheet()?.value
        #expect(core.writes.count == 1 && toasts.current?.tone == .danger && toasts.undoStack.isEmpty && state.sheet == nil)
    }

    @Test("Select N Suggested shows Never ran first, ticks the suggested rows; pressed again it clears them")
    func selectSuggested() async {
        let (_, _, state, _) = await setUp()
        state.selectSuggested()
        #expect(state.view.filter == .neverRan && state.view.ticked == ["skill::pdf-extract", "skill::changelog-writer"])
        #expect(state.list().primaryTitle == "Remove 2 selected…")
        state.selectSuggested()
        #expect(state.view.ticked.isEmpty)
    }

    @Test("Subagents use the same page: their own words and rows")
    func subagents() async {
        let (_, _, state, _) = await setUp(kind: .subagents)
        let list = state.list()
        #expect(list.kind.noun == "Subagent" && list.figure == .count(1, tone: .attention))
        #expect(list.all.first?.name == "test-runner" || list.all.first?.name == "code-reviewer")
        #expect(list.neverRan.map(\.name) == ["db-migrator"])
    }

    @Test("the frame region draws Skills and Subagents, not the Not built yet state")
    func region() async {
        let (_, model, _, _) = await setUp()
        for page in [FramePage.skills, .subagents] {
            let content = FramePageContent.region(page, model: model)
            #expect(content.help == page.help && content.inspector != nil && content.primary != nil)
            // The fake holds Skills only: Subagents is the empty state, which has no toolbar controls (the mock's `mid`).
            #expect((content.toolbarControls != nil) == (page == .skills))
        }
    }
}

