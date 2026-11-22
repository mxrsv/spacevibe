import Foundation
import SwiftUI
import Testing
@testable import SpaceVibe

/// What Clean shows in each state (RD-R2 Clean, RD-R13, RD-R17, CL-R1 to CL-R6), from `CleanSynthetic` at 2 and 10 CLIs.
@Suite("Clean page")
struct CleanPageTests {
    private typealias S = CleanSynthetic

    private func page(_ state: S.State, clis: Int = 2, ticked: Set<String> = [], move: CleanMoveRun.Snapshot = .idle) -> CleanPage {
        CleanPage(S.inputs(state, clis: clis), ticked: ticked, move: move)
    }

    @Test("the hero is what can be cleaned, the same figure as the sidebar, at 2 and 10 CLIs")
    func heroIsSidebar() {
        for clis in [2, 10] {
            let world = S.world(.normal, clis: clis)
            guard case .bytes(let bytes) = world.figure(for: .clean, loading: [], failed: []) else {
                Issue.record("no byte figure at \(clis) CLIs")
                continue
            }
            let shown = page(.normal, clis: clis)
            #expect(shown.hero == CleanPage.figure(bytes))
            #expect(FrameSidebarValue(figure: .bytes(bytes), page: .clean).text == NumberWording.bytes(bytes))
            // Claude Code's logs and caches are locked by its waiting session, Codex's caches by an unmeasurable one: only
            // Codex logs (90 days) and the open Skills and Subagents count.
            #expect(bytes == 780_000_000 + 48_000 + 12_000 + 3_400 + (world.clean.agentRows.contains { $0.id == "skill::figma-export" && $0.isSuggested } ? 9_000 : 0))
        }
    }

    @Test("the hero names the suggested Hooks; the bar is selected against what can be cleaned; bytes in use are text")
    func band() {
        let shown = page(.normal, ticked: ["logs:codex"])
        #expect(shown.heroLabel == "can be cleaned · 3 Hooks to remove")
        let cleanable = S.world(.normal, clis: 2).clean.cleanableBytes!
        #expect(shown.barShare == Double(780_000_000) / Double(cleanable))
        #expect(shown.barText == "780 MB selected · 6.49 GB more in use", "Claude logs 6.2 GB + its caches 50 MB + Codex cache 240 MB")
        #expect(shown.primary == .remove(bytes: 780_000_000, count: 1))
        #expect(shown.primary.title(narrow: false) == "Remove 780 MB")
    }

    @Test("the button: nothing ticked asks to select; only Hooks ticked counts rows; a locked tick never counts")
    func primary() {
        #expect(page(.normal).primary.title(narrow: false) == "Select rows to remove")
        #expect(!page(.normal).primary.isEnabled)
        let hooks = page(.normal).rows.filter { $0.section == .agents && $0.isMono && $0.isOpen }.map(\.id)
        let onlyHooks = page(.normal, ticked: Set(hooks))
        #expect(onlyHooks.primary.title(narrow: false) == "Remove \(hooks.count) selected")
        let locked = page(.normal, ticked: ["logs:claude", "claude:debug"])
        #expect(locked.ticked.isEmpty && !locked.primary.isEnabled)
    }

    @Test("a locked row keeps its checkbox disabled and says why: the sessions by name and the core's sentence")
    func lockNote() throws {
        let shown = page(.normal)
        let logs = try #require(shown.row("logs:claude"))
        #expect(!logs.isOpen)
        guard case .lock(let note) = logs.detail else { Issue.record("no lock"); return }
        #expect(note.title == "In use by 1 session")
        #expect(note.sessions.map(\.pid) == [47_812] && note.sessions.first?.title == "Refactor the billing webhook")
        #expect(note.footnote == "Claude Code has 1 running session, so its logs stay until it ends. Stopping them is in Activity.")
        let cache = try #require(shown.row("codex:cache"))
        guard case .lock(let cacheNote) = cache.detail else { Issue.record("no cache lock"); return }
        #expect(cacheNote.footnote.contains("Caches stay locked while any session of this CLI is open, idle ones too."))
        // Codex logs stay open while its caches are locked (RD35 vs RD27).
        #expect(shown.row("logs:codex")?.isOpen == true)
        guard case .ages(let ages, let selected) = shown.row("logs:codex")?.detail else { Issue.record("no age control"); return }
        #expect(ages == [30, 90, 180] && selected == 90)
    }

    @Test("a processes or unknown lock says so without naming sessions")
    func otherLocks() {
        let processes = CleanLockNote(id: "caches:codex", lock: CleanLock(reason: .processes, message: "Codex is running (1 process), so its caches are in use."),
                                      isCache: true, activity: nil)
        #expect(processes.title == "In use" && processes.sessions.isEmpty && !processes.footnote.contains("Activity"))
        let unknown = CleanLockNote(id: "logs:codex", lock: CleanLocks.unknown("Codex"), isCache: false, activity: nil)
        #expect(unknown.title == "Process check failed")
    }

    @Test("plugin, project and Codex-only Hook rows are listed read-only and never offered (CL-R1)")
    func readOnly() {
        let row = FrameTestData.item("design-kit", owner: "design-plugin", cells: ["claude": FrameTestData.sessions(0), "codex": .missing])
        let world = FrameWorld(snapshot: FrameTestData.snapshot(FrameTestData.loadout([row])), now: FrameTestData.now)
        let rows = CleanRows(world: world, wording: InboxWording(world: world, now: FrameTestData.now), now: FrameTestData.now, phase: .ready,
                             open: world.clean.openIDs)
        let model = rows.agent(world.clean.agentRows[0])
        #expect(model.sub?.hasPrefix("Owned by the design-plugin plugin · read-only · Never ran Skill") == true)
        #expect(!model.isOpen)
    }

    @Test("empty log rows are not offered; an unreadable logs folder is an Unmeasurable row that cannot be ticked")
    func honestLogs() throws {
        #expect(page(.empty).rows.isEmpty)
        let error = page(.error)
        let codex = try #require(error.row("logs:codex"))
        #expect(codex.size == .quiet("Unmeasurable") && !codex.isOpen)
        #expect(codex.sub?.hasPrefix("Unmeasurable: ") == true && codex.sub?.hasSuffix("/sessions could not be read") == true)
        #expect(error.banners.contains { if case .unreadable = $0 { true } else { false } })
    }

    @Test("Tidy: nothing listed, no button, the one quiet line; the first scan: …, Measuring…, skeleton sections")
    func emptyAndMeasuring() {
        let tidy = page(.empty)
        #expect(tidy.hero == .clear("Tidy") && tidy.heroLabel == "Nothing to clean")
        #expect(tidy.isTidy && tidy.primary == .hidden && !tidy.showsBand && tidy.sections.isEmpty)
        let measuring = page(.scanning)
        #expect(measuring.phase == .measuring && measuring.hero == .scanning && measuring.barText == "Measuring…")
        #expect(measuring.primary == .measuring && measuring.primary.isLoading && !measuring.canScanAgain)
        // The mock's scanning: each CLI the scan covers lists its log row, "Counting files…", the size a skeleton.
        let logs = try? #require(measuring.sections.first { $0.section == .logs })
        #expect(logs?.skeletons == 0 && logs?.rows.map(\.title) == ["Claude Code session logs", "Codex session logs"])
        #expect(logs?.rows.allSatisfy { $0.sub == "Counting files…" && $0.size == .pending } == true)
        #expect(logs?.rows.last?.detail == .ages([30, 90, 180], selected: 90))
        if case .lock(let note) = logs?.rows.first?.detail { #expect(note.title == "In use by 1 session") } else {
            Issue.record("Claude Code's running session holds its logs before any count")
        }
        let hook = measuring.rows.first { $0.id == "hook::h1" }
        #expect(hook?.size == .pending, "no figure, not even a Hook's note, while measuring")
        #expect(measuring.sections.contains { $0.section == .caches && $0.skeletons > 0 })
        #expect(measuring.rows.allSatisfy { !$0.isOpen })
        let many = page(.scanning, clis: 10)
        #expect(many.sections.first { $0.section == .logs }?.rows.count == 2, "only the CLIs clean.scan covers (RD42)")
    }

    @Test("the confirmation names every target of the press: shared equipment with its readers, then each ticked log and cache")
    func confirmationNamesEverything() {
        let world = S.world(.normal, clis: 10)
        let ticked = Set(world.clean.suggestedAgents + world.clean.suggestedLogs + ["claude:debug"])
        let page = CleanPage(S.inputs(.normal, clis: 10), ticked: ticked)
        let items = page.confirmationItems(world)
        #expect(items.first?.id == "skill::pdf-extract", "the shared file it asks about leads")
        #expect(items[1].id == "logs:codex", "the logs come before the rest, so the five shown lines name every kind")
        #expect(items.filter { $0.detail == nil }.allSatisfy { !$0.losers.isEmpty })
        let log = items.first { $0.id == "logs:codex" }
        #expect(log?.name == "Codex session logs" && log?.detail == "1,310 files older than 90 days, to the macOS Trash")
        #expect(items.contains { $0.id == "claude:debug" } == false, "a locked cache is never ticked, so never named")
        #expect(items.count == page.request(world).rows.count + page.request(world).logs.count + page.request(world).caches.count)
    }

    @Test("Clean rows are never selected: no click target; Space ticks only the open row the arrow keys reached")
    @MainActor
    func rowsNotSelected() {
        let row = ItemRow(label: "Codex session logs") { EmptyView() }
        #expect(row.select == nil && !row.isSelected)
        let model = FrameModel(core: UnservedCore(), toasts: ToastCenter(announce: false))
        let state = CleanPageState()
        let page = page(.normal)
        let actions = CleanActions(model: model, state: state, page: page, world: S.world(.normal, clis: 2))
        #expect(actions.toggleFocused("logs:codex") && state.ticked == ["logs:codex"])
        #expect(!actions.toggleFocused("logs:claude"), "locked by a running session")
        #expect(!actions.toggleFocused(nil) && state.ticked == ["logs:codex"])
    }

    @Test("a failed first scan: ? Unmeasurable, the core's sentence with Try Again, nothing listed")
    func failed() {
        let world = S.world(.normal, clis: 2)
        let failed = CleanPage(CleanInputs(world: world, figure: .failed, failure: "Could not read ~/.claude.", now: S.now))
        #expect(failed.hero == .unmeasurable && failed.sections.isEmpty && failed.primary == .hidden)
        #expect(failed.banners.first == .failed("Could not read ~/.claude.") && failed.banners.first?.retries == true)
        let rescan = CleanPage(CleanInputs(world: world, figure: world.figure(for: .clean, loading: [], failed: []), rescanFailure: "x", now: S.now))
        #expect(rescan.banners.contains(.rescanFailed("x")) && !rescan.sections.isEmpty, "a failed Scan Again keeps the last rows")
    }

    @Test("an unreadable usage archive and a stranded move are shown, never dropped")
    func problems() {
        let worst = page(.worst)
        #expect(worst.banners.contains { if case .usage(let p) = $0 { !p.isEmpty } else { false } })
        #expect(worst.banners.contains { if case .stranded(let p) = $0 { p.first?.contains("interrupted Clean move") == true } else { false } })
    }

    @Test("while moving: ticks stay drawn, nothing can be ticked, the button and the band show the progress")
    func moving() {
        let progress = CoreCleanProgress(phase: "moving", done: 655, total: 1_310, bytes: 390_000_000)
        let shown = page(.normal, ticked: ["logs:codex"], move: CleanMoveRun.Snapshot(isRunning: true, progress: progress))
        #expect(shown.phase == .moving && shown.ticked == ["logs:codex"])
        #expect(shown.rows.allSatisfy { !$0.isOpen } && shown.sections.allSatisfy { $0.pick == .none })
        #expect(shown.primary.title(narrow: false) == "Moving 50%" && !shown.canScanAgain)
        #expect(shown.moveBand?.text == "Moving 655 of 1,310 files · 390 MB of 780 MB")
        let reading = CleanMoveBand(progress: CoreCleanProgress(phase: "reading", done: 3, total: 9, bytes: 0), selectedBytes: 1, isCancelling: false)
        #expect(reading.text == "Keeping the usage of 3 of 9 logs" && CleanMoveBand.percent(nil) == nil)
    }

    @Test("Select N Suggested per section ticks the open suggested rows; all ticked turns it into Clear Selection")
    func sectionPick() {
        let shown = page(.normal)
        let logs = shown.sections.first { $0.section == .logs }
        #expect(logs?.pick == .select(1) && logs?.suggested == ["logs:codex"])
        let all = page(.normal, ticked: ["logs:codex"])
        #expect(all.sections.first { $0.section == .logs }?.pick == .clear)
        #expect(shown.sections.first { $0.section == .caches }?.pick == CleanSectionModel.Pick.none, "every cache is locked")
    }

    @Test("the request takes only ticked open rows: a Hook's Claude Code members, logs at their age, caches by id")
    func request() {
        let world = S.world(.normal, clis: 2)
        let hook = world.clean.agentRows.first { $0.row.kind == .hook && !$0.isReadOnly }!.id
        let request = page(.normal, ticked: ["skill::pdf-extract", hook, "logs:codex", "logs:claude", "claude:debug"]).request(world)
        #expect(request.rows.map(\.id) == ["skill::pdf-extract", hook])
        #expect(request.members.contains("claude:skill:pdf-extract") && request.members.contains("codex:skill:pdf-extract"))
        #expect(request.logs == [CoreCleanLogPick(cli: "codex", olderThanDays: 90)] && request.caches.isEmpty)
        #expect(request.groupNames["logs:codex"] == "Codex session logs")
    }

    @Test("the request names every member that shares a ticked row's file, another row's link included, and asks first")
    func requestNamesLinks() {
        var snapshot = InboxBuildReviewTests.linkWorld().snapshot
        snapshot.clean = FrameTestData.cleanScan(items: ["skill::foo": 4_096])
        let world = FrameWorld(snapshot: snapshot, now: FrameTestData.now)
        let inputs = CleanInputs(world: world, figure: world.figure(for: .clean, loading: [], failed: []), now: FrameTestData.now)
        let shown = CleanPage(inputs, ticked: ["skill::foo"])
        #expect(shown.ticked == ["skill::foo"])
        #expect(shown.request(world).members == ["claude:skill:foo", "codex:skill:bar"])
        #expect(shown.sharedRows(world).map(\.id) == ["skill::foo"], "Codex would keep a dangling link: the readers are named first")
    }

    @Test("the band's note names only what keeps a moved log's totals: the usage counts, not Limits or Activity")
    func noteIsTrue() {
        #expect(!CleanPage.note.contains("Limits") && !CleanPage.note.contains("Activity"))
        #expect(CleanPage.note.hasSuffix("which the usage counts on Skills, Subagents and Hooks still include."))
    }

    @Test("at 2 CLIs no file is shared, so removal never asks; at 10 a shared ~/.agents/skills file names its readers")
    func confirmation() {
        let two = S.world(.normal, clis: 2)
        #expect(page(.normal, ticked: ["skill::pdf-extract"]).sharedRows(two).isEmpty)
        let ten = S.world(.normal, clis: 10)
        let shown = CleanPage(S.inputs(.normal, clis: 10), ticked: ["skill::pdf-extract"])
        #expect(shown.sharedRows(ten).map(\.id) == ["skill::pdf-extract"])
    }

    @Test("CLIs the scan does not cover are named once, never offered; at 2 CLIs there is none")
    func notOffered() {
        #expect(page(.normal).notOfferedLine == nil)
        let line = page(.normal, clis: 10).notOfferedLine ?? ""
        #expect(line.hasPrefix("Cursor CLI, GitHub Copilot") && line.hasSuffix(": log paths are not verified yet, so they are not offered."))
    }

    @Test("worst-case data: every figure is worded, no NaN, no made-up zero")
    func worst() {
        for clis in [2, 10] {
            let shown = page(.worst, clis: clis, ticked: Set(S.world(.worst, clis: clis).clean.openIDs))
            let texts = shown.rows.flatMap { [$0.title, $0.sub ?? ""] } + [shown.barText, shown.primary.title(narrow: false), shown.heroLabel]
            #expect(!texts.contains { $0.contains("NaN") || $0.contains("nil") })
            #expect(shown.primary.isEnabled)
        }
    }
}
