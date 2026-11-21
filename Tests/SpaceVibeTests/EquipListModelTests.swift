import Foundation
import Testing
@testable import SpaceVibe

/// The Skills and Subagents page model (RB-R2): what each state shows, that the hero, the group head and the toolbar count the
/// same rows, the logo states at 2, 6 and 10 CLIs (RD-R11, RD16, RD31, D53; the 6 and 10 CLI data is an illustration, RD42),
/// the tile grid's shape (RD-R12) and the per-CLI sheet's lines and button (RD-R11 "Bulk and Remove…").
@Suite("Skills and Subagents model")
struct EquipListModelTests {
    typealias D = EquipShotData

    static let now = FrameTestData.now

    static func model(_ kind: EquipKind = .skills, specs: [D.Spec]? = nil, clis: Int = 2, view: EquipViewState = EquipViewState(),
                      unreadable: Set<String> = [], scanning: Bool = false, kept: Set<String> = [], loading: Set<FrameSource> = [],
                      loadout override: CoreLoadoutRows?? = nil, failure: String? = nil) -> EquipListModel {
        let registry = D.registry(count: clis)
        let rows = override ?? D.loadout(kind.kind, specs: specs ?? (kind == .skills ? D.skills : D.subagents), registry: registry, now: now,
                                         unreadable: unreadable, scanning: scanning)
        var snapshot = FrameTestData.snapshot(rows ?? FrameTestData.loadout(), registry: registry)
        if rows == nil { snapshot.loadout = nil }
        var facts = FrameFacts()
        facts.findings.kept = kept
        let world = FrameWorld(snapshot: snapshot, facts: facts, now: now)
        return EquipListModel.make(kind: kind, world: world, loading: loading, failed: failure == nil ? [] : [.loadout], failure: failure,
                                   view: view, now: now)
    }

    static func toggle(_ row: EquipListRow?, _ cli: String) -> CLIToggleState? { row?.toggles.first { $0.cli.id == cli } }

    // MARK: Hero, head, toolbar

    @Test("the hero counts every Never ran row, plugin and project ones too; Select N Suggested counts only what it ticks")
    func heroAndSuggested() {
        let list = Self.model()
        #expect(list.phase == .normal)
        #expect(list.figure == .count(5, tone: .attention))
        #expect(list.heroFigure == .value("5", unit: nil) && list.heroLabel == "never ran")
        #expect(Set(list.neverRan.map(\.name)) == ["pdf-extract", "changelog-writer", "release-notes", "checkout-flows", "brand-voice"])
        // release-notes is 2 hours old (D63), checkout-flows a project item, brand-voice a plugin's: never suggested.
        #expect(Set(list.suggested) == ["skill::pdf-extract", "skill::changelog-writer"])
        #expect(list.showsNeverRanHead && list.neverRanSeverity == .attention)
        #expect(list.primaryTitle == "Select rows to remove")
    }

    @Test("a kept row is not suggested; nothing suggested leaves the head neutral")
    func keptNotSuggested() {
        let list = Self.model(kept: ["skill::pdf-extract", "skill::changelog-writer"])
        #expect(list.suggested.isEmpty && list.neverRanSeverity == .none)
        #expect(list.neverRan.count == 5, "Keep only stops the suggestion; the row still never ran")
    }

    @Test("rows are sorted by sessions over the shown CLIs, most first; Last ran is the most recent day")
    func sortAndLastRan() {
        let list = Self.model()
        let totals = list.all.map(\.total)
        #expect(totals == totals.sorted(by: >))
        #expect(list.all.first?.name == "lint-fixer" && list.all.first?.total == 67)
        #expect(list.row("skill::sql-explainer")?.lastRan == "19 days ago")
        #expect(list.row("skill::pdf-extract")?.lastRan == NumberWording.missing)
        #expect(list.row("skill::pdf-extract")?.subline == "added 41 days ago · Pull text and tables out of PDF files")
        #expect(list.row("skill:~/work/payments-web:checkout-flows")?.subline?.hasPrefix("Project · payments-web · added 30 days ago") == true)
    }

    @Test("Never ran and a CLI pick filter the rows; a new filter clears the ticks")
    func filters() {
        let never = Self.model(view: EquipViewState(filter: .neverRan))
        #expect(never.visible.count == 5 && never.visible.allSatisfy(\.isNeverRan))
        let codex = Self.model(view: EquipViewState(cli: "codex"))
        #expect(codex.visible.allSatisfy { $0.row.presence("codex") == .on })
        #expect(!codex.visible.contains { $0.name == "review-pr" })
        #expect(codex.noMatch == "No Skill is loaded by Codex.")
        let ticked = EquipViewState(ticked: ["skill::pdf-extract"])
        #expect(ticked.filtering(.neverRan).ticked.isEmpty && ticked.scoping("codex").ticked.isEmpty)
    }

    @Test("ticks: only the user's own rows shown; the toolbar and the head count the same rows")
    func picked() {
        let view = EquipViewState(ticked: ["skill::pdf-extract", "skill::brand-voice", "skill:~/work/payments-web:checkout-flows", "skill::lint-fixer"])
        let list = Self.model(view: view)
        #expect(list.picked.map(\.name) == ["lint-fixer", "pdf-extract"])
        #expect(list.primaryTitle == "Remove 2 selected…")
        #expect(!list.row("skill::brand-voice")!.isTickable && !list.row("skill:~/work/payments-web:checkout-flows")!.isTickable)
        #expect(!list.tickable.contains("skill::brand-voice"))
        // A tick on a row the filter hides is not acted on.
        let hidden = Self.model(view: EquipViewState(filter: .neverRan, ticked: ["skill::lint-fixer"]))
        #expect(hidden.picked.isEmpty)
    }

    @Test("Select N Suggested then pressed again: ticks the suggested rows, then clears them")
    func togglingSuggested() {
        let list = Self.model(view: EquipViewState(filter: .neverRan))
        let once = list.view.togglingAll(list.suggested)
        #expect(once.ticked == Set(list.suggested))
        #expect(once.togglingAll(list.suggested).ticked.isEmpty)
    }

    // MARK: States

    @Test("scanning: every row listed with pending counts, no Never ran head, no primary, nothing tickable or pressable")
    func scanning() {
        let list = Self.model(view: EquipViewState(filter: .neverRan), scanning: true)
        #expect(list.isScanning && list.phase == .normal)
        #expect(list.visible.count == D.skills.count, "the filter waits for the counts")
        #expect(list.figure == .pending && list.heroFigure == .scanning)
        #expect(!list.showsNeverRanHead && list.primaryTitle == nil && list.tickable.isEmpty)
        #expect(list.all.allSatisfy { $0.isPending && $0.lastRan == nil })
        let commit = list.row("skill::commit-helper")
        #expect(Self.toggle(commit, "claude")?.presence == .on(.pending) && Self.toggle(commit, "claude")?.isToggle == false)
        #expect(SessionsCell.value(total: 0, top: 1, floor: false, pending: true) == .pending)
    }

    @Test("empty, loading and failed")
    func phases() {
        let empty = Self.model(specs: [])
        #expect(empty.phase == .empty && empty.primaryTitle == nil)
        #expect(empty.emptyTitle == "No Skills installed")
        #expect(Self.model(.subagents, specs: []).emptyText.contains("agents folder"))
        let loading = Self.model(loading: [.loadout], loadout: .some(nil))
        #expect(loading.phase == .loading && loading.figure == .pending)
        let failed = Self.model(loadout: .some(nil), failure: "could not read")
        #expect(failed.phase == .failed("could not read") && failed.heroFigure == .unmeasurable)
    }

    @Test("an unreadable Codex folder: its band, every Codex cell unknown, `+?` on the total, never Never ran")
    func unreadable() {
        let list = Self.model(unreadable: ["codex"])
        #expect(list.unreadable.map(\.id) == ["codex"])
        let pdf = list.row("skill::pdf-extract")
        #expect(pdf?.row.status == .unknown && pdf?.hasUnknown == true && pdf?.isNeverRan == false)
        #expect(Self.toggle(pdf, "codex")?.presence == .unreadable && Self.toggle(pdf, "codex")?.badge == .unknown)
        #expect(list.heroLabel == "never ran · \(list.unknownCount) Unmeasurable" && list.unknownCount > 0)
        #expect(SessionsCell.value(total: 31, top: 67, floor: true, pending: false) == .count(31, share: 31.0 / 67, floor: true))
    }

    // MARK: Logo toggles at 2 CLIs

    @Test("2 CLIs: on, off, last copy by files, Never ran dot on both owners, plugin and project locks")
    func togglesAtTwo() {
        let list = Self.model()
        let commit = list.row("skill::commit-helper")
        #expect(Self.toggle(commit, "claude")?.presence == .on(.sessions(31)) && Self.toggle(commit, "claude")?.isToggle == true)
        let changelog = list.row("skill::changelog-writer")
        #expect(Self.toggle(changelog, "claude")?.hold == .lastCopy && Self.toggle(changelog, "claude")?.isToggle == false)
        #expect(Self.toggle(changelog, "codex")?.presence == .off && Self.toggle(changelog, "codex")?.isToggle == true)
        let pdf = list.row("skill::pdf-extract")
        #expect(Self.toggle(pdf, "claude")?.showsNeverRanDot == true && Self.toggle(pdf, "codex")?.showsNeverRanDot == true)
        #expect(Self.toggle(list.row("skill::brand-voice"), "claude")?.hold == .readOnly(owner: "plugin"))
        #expect(Self.toggle(list.row("skill::brand-voice"), "codex")?.isToggle == false, "a plugin's item cannot be added either")
        #expect(Self.toggle(list.row("skill:~/work/payments-web:checkout-flows"), "claude")?.hold == .readOnly(owner: "project payments-web"))
        // At 2 CLIs no file is shared: turning off never asks (the mock's MOCK.na).
        for row in list.all {
            for state in row.toggles {
                if case .confirm = EquipToggles.intent(state, row: row.row, readers: row.readers) { Issue.record("\(row.name) asks at 2 CLIs") }
            }
        }
        #expect(EquipToggles.intent(Self.toggle(commit, "claude")!, row: commit!.row, readers: commit!.readers) == .removeFrom(cli: "claude"))
        #expect(EquipToggles.intent(Self.toggle(changelog, "codex")!, row: changelog!.row, readers: changelog!.readers) == .add(cli: "codex"))
        #expect(EquipToggles.intent(Self.toggle(changelog, "claude")!, row: changelog!.row, readers: changelog!.readers) == .none)
    }

    // MARK: Many CLIs (illustration, RD42)

    @Test("6 CLIs: via logos are not toggles and carry the link badge; the Never ran dot stays on the owner only")
    func viaAtSix() {
        let list = Self.model(clis: 6)
        let commit = list.row("skill::commit-helper")
        let cursor = Self.toggle(commit, "cursor")
        #expect(cursor?.hold == .via(["Claude Code", "Codex"]) && cursor?.badge == .link && cursor?.isToggle == false)
        #expect(cursor?.presence == .on(.unmeasurable), "Cursor CLI keeps no log: on, never 0")
        #expect(Self.toggle(commit, "copilot")?.presence == .off)
        let pdf = list.row("skill::pdf-extract")
        #expect(Self.toggle(pdf, "amp")?.ownsFile == false && Self.toggle(pdf, "amp")?.showsNeverRanDot == false)
        #expect(Self.toggle(pdf, "claude")?.showsNeverRanDot == true)
        // Amp has no Subagents: Not supported, a dash, never Missing.
        let reviewer = Self.model(.subagents, clis: 6).row("agent::code-reviewer")
        #expect(Self.toggle(reviewer, "amp")?.presence == .notSupported(noun: "Subagents"))
    }

    @Test("6 CLIs: turning off a shared file asks, names every reader, and offers a copy to the CLIs that can keep it")
    func sharedAtSix() throws {
        let list = Self.model(clis: 6)
        let commit = try #require(list.row("skill::commit-helper"))
        let claude = try #require(Self.toggle(commit, "claude"))
        #expect(claude.sharedWith == ["Cursor CLI", "opencode", "Amp"])
        guard case .confirm(let removal) = EquipToggles.intent(claude, row: commit.row, readers: commit.readers) else {
            Issue.record("a shared file must ask")
            return
        }
        #expect(removal.members == ["claude:skill:commit-helper"])
        // Cursor CLI and Amp still read ~/.agents/skills; opencode reads only ~/.claude/skills.
        #expect(removal.losers == ["claude", "opencode"] && removal.savable == ["opencode"])
        #expect(removal.wording.files == ["~/.claude/skills/commit-helper"])
        #expect(removal.wording.removeTitle == "Remove for 2 CLIs")
        #expect(removal.wording.copyTitle == "Copy to opencode first, then remove")
    }

    @Test("2, 6 and 10 CLIs: one strip slot per CLI, wrapping at 5; the tile grid never exceeds 3 rows; one layout")
    func shapeAtMany() {
        for count in [2, 6, 10] {
            let list = Self.model(clis: count)
            #expect(list.all.allSatisfy { $0.toggles.count == count })
            #expect(CLIToggleStrip.columns(count) == min(count, 5))
            #expect(CLIToggleStrip.rowHeight(count) == (count > 5 ? .tableWrapped : .table))
            #expect(CLITileGridLayout.rows(count) <= 3 && CLITileGridLayout.columns(count) == max(3, (count + 2) / 3))
        }
        let ten = Self.model(clis: 10)
        #expect(Self.toggle(ten.row("skill::commit-helper"), "qwen")?.presence == .notSupported(noun: "Skills"))
        #expect(Self.toggle(ten.row("skill::commit-helper"), "antigravity")?.presence == .on(.unmeasurable))
    }

    @Test("worst case at 10 CLIs: long and non-Latin names and huge counts are listed whole, in order, with no lost row")
    func worst() {
        let list = Self.model(specs: D.worst(.skill), clis: 10)
        #expect(list.all.count == D.worst(.skill).count)
        #expect(list.all.first?.name == "Rút trích văn bản từ PDF 📄" && list.all.first?.total == 4_830_113)
        #expect(SessionsCell.value(total: 4_830_113, top: 4_830_113, floor: false, pending: false) == .count(4_830_113, share: 1, floor: false))
        #expect(NumberWording.compactCount(4_830_113) == "4.8M")
    }

    // MARK: Sheet

    @Test("Remove…: nothing ticked, own folders tickable first, via lines shown and not tickable, the button counts every loser")
    func removeSheet() throws {
        let list = Self.model(clis: 6)
        var sheet = EquipSheetState(mode: .remove, rowIDs: ["skill::commit-helper"])
        let first = EquipSheet.model(sheet, rows: list.all, kind: .skills, clis: list.clis)
        #expect(first.title == "Remove commit-helper from…" && first.ticked.isEmpty && !first.canConfirm)
        #expect(first.lines.map(\.id) == ["claude", "codex", "cursor", "opencode", "amp"])
        #expect(first.lines.filter(\.isTickable).map(\.id) == ["claude", "codex"])
        #expect(first.lines.first { $0.id == "codex" }?.folder == "~/.agents/skills")
        #expect(first.lines.first { $0.id == "claude" }?.otherReaders == ["Cursor CLI", "opencode", "Amp"])
        #expect(first.lines.first { $0.id == "amp" }?.detail == "Via Claude Code and Codex’s folder: removed only with it")
        sheet.ticked = ["claude"]
        let claudeOnly = EquipSheet.model(sheet, rows: list.all, kind: .skills, clis: list.clis)
        #expect(claudeOnly.confirmTitle == "Remove from 2 CLIs" && claudeOnly.sharedWarning == "Shared files: this also removes it for opencode.")
        sheet.ticked = ["claude", "codex"]
        let both = EquipSheet.model(sheet, rows: list.all, kind: .skills, clis: list.clis)
        #expect(both.confirmTitle == "Remove from 5 CLIs")
        let removal = try #require(EquipSheet.removal(sheet, rows: list.all))
        #expect(removal.members == ["claude:skill:commit-helper", "agents:skill:commit-helper"] && removal.rows.map(\.id) == ["skill::commit-helper"])
    }

    @Test("Add to…: only CLIs that lack a row and can take a copy; the copy goes per row")
    func addSheet() {
        let list = Self.model()
        let sheet = EquipSheetState(mode: .add, rowIDs: ["skill::changelog-writer", "skill::review-pr", "skill::lint-fixer"], ticked: ["codex"])
        let model = EquipSheet.model(sheet, rows: list.all, kind: .skills, clis: list.clis)
        #expect(model.lines.map(\.id) == ["codex"] && model.lines[0].itemCount == 2 && model.lines[0].folder == "~/.codex/skills")
        #expect(model.title == "Add 3 Skills to…" && model.confirmTitle == "Add 3 to 1 CLI")
        let steps = EquipSheet.additions(sheet, rows: list.all, order: list.clis.map(\.id))
        #expect(steps.map(\.row.id) == ["skill::changelog-writer", "skill::review-pr"] && steps.allSatisfy { $0.targets == ["codex"] })
    }

    @Test("a row whose file another row reaches is removed with those members, through removeMany")
    func reachesOtherRows() throws {
        // "a" in Claude Code and Codex; "b" is a link in Claude Code's folder to Claude Code's copy of "a".
        let cells: CoreCLICells = ["claude": FrameTestData.sessions(2), "codex": FrameTestData.sessions(1)]
        let item = FrameTestData.item("a", cells: cells, folder: "/h/.claude/skills", realPath: "/h/.claude/skills/a")
        let codex = FrameTestData.item("a", cli: .codex, cells: cells, folder: "/h/.codex/skills", realPath: "/h/.codex/skills/a")
        var other = FrameTestData.item("b", cells: ["claude": FrameTestData.sessions(1), "codex": .missing],
                                       folder: "/h/.claude/skills", realPath: "/h/.claude/skills/a")
        other.owner = "link"
        var rows = FrameTestData.loadout([item, codex, other])
        rows.folders = [FrameTestData.folder("/h/.claude/skills", readBy: ["claude"], ownedBy: "claude"),
                        FrameTestData.folder("/h/.codex/skills", readBy: ["codex"], ownedBy: "codex")]
        let list = Self.model(loadout: rows)
        let row = try #require(list.row("skill::a"))
        let claude = try #require(Self.toggle(row, "claude"))
        #expect(EquipToggles.intent(claude, row: row.row, readers: row.readers) == .removeMembers(cli: "claude", members: ["claude:skill:a", "claude:skill:b"]))
    }

    @Test("without a readers map the only lit logo is the last copy, and a removal goes to the engine per row")
    func noReaders() throws {
        let rows = FrameTestData.loadout([FrameTestData.item("a", cells: ["claude": FrameTestData.sessions(2), "codex": .missing])])
        let list = Self.model(loadout: rows)
        let row = try #require(list.row("skill::a"))
        #expect(row.readers.readers == nil && Self.toggle(row, "claude")?.hold == .lastCopy)
        let sheet = EquipSheetState(mode: .remove, rowIDs: ["skill::a"], ticked: ["claude"])
        #expect(EquipSheet.removal(sheet, rows: list.all) == nil)
        #expect(EquipSheet.removeFromEach(sheet, rows: list.all, order: ["claude", "codex"]).map(\.clis) == [["claude"]])
    }

    // MARK: Inspector

    @Test("inspector facts: owner, each file with its readers, added; read-only lines for plugin and project")
    func inspector() throws {
        let list = Self.model(clis: 6)
        let commit = try #require(list.row("skill::commit-helper"))
        let facts = EquipInspectorFacts.facts(commit, clis: list.clis, now: Self.now)
        #expect(facts.first == EquipFact(key: "Owner", value: "You"))
        #expect(facts.contains(EquipFact(key: "Shared", value: "~/.agents/skills/commit-helper", isPath: true, note: "read by Codex, Cursor CLI and Amp")))
        #expect(EquipInspectorFacts.readOnlyLine(commit) == nil)
        #expect(EquipInspectorFacts.readOnlyLine(list.row("skill::brand-voice")!) == "Read-only · design-kit plugin")
        #expect(EquipInspectorFacts.readOnlyLine(list.row("skill:~/work/payments-web:checkout-flows")!) == "Read-only · project payments-web")
        let pdf = EquipInspectorFacts.facts(list.row("skill::pdf-extract")!, clis: list.clis, now: Self.now)
        #expect(pdf.last == EquipFact(key: "Added", value: "41 days ago"))
        #expect(EquipInspectorFacts.isLong(String(repeating: "a", count: 161)) && !EquipInspectorFacts.isLong("short"))
    }
}
