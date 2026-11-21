import Foundation
import Testing
@testable import SpaceVibe

/// RB-R8, the redesign's Settings window: Show and Balance pins (and their feed into the store's facts), Open at login, the
/// Limits pane's snapshot line, the Data pane's folders, the Journal window and the window's states.
@Suite("Settings window")
@MainActor
struct SettingsWindowTests {
    private let two = FrameTestData.registry
    private let ten = SettingsWindowShots.registry(count: 10)

    private func suite() -> (UserDefaults, String) {
        let name = "dev.spacevibe.tests.settings-window.\(UUID().uuidString)"
        return (UserDefaults(suiteName: name)!, name)
    }

    // MARK: Show and Balance pins

    @Test("before any choice the first two CLIs that hold Skills or Subagents are pinned; ineligible and fourth pins are refused")
    func pins() {
        let prefs = CLIPreferences(defaults: nil)
        #expect(prefs.pins(in: two) == ["claude", "codex"])
        #expect(prefs.pins(in: []) == [])
        #expect(prefs.setPinned(true, for: "aider", in: ten) == .cannotBalance, "Aider holds neither")
        #expect(prefs.setPinned(true, for: "cursor", in: ten) == nil)
        #expect(prefs.pins(in: ten) == ["claude", "codex", "cursor"])
        #expect(prefs.setPinned(true, for: "kiro", in: ten) == .pinsFull)
        #expect(prefs.pins(in: ten) == ["claude", "codex", "cursor"], "a refused pin changes nothing")
        #expect(prefs.setPinned(false, for: "codex", in: ten) == nil)
        #expect(prefs.setPinned(true, for: "qwen", in: ten) == nil, "Qwen Code holds Subagents only: it can be compared")
        #expect(prefs.pins(in: ten) == ["claude", "cursor", "qwen"], "registry order, not click order")
        #expect(prefs.setPinned(false, for: "claude", in: ten) == nil && prefs.setPinned(false, for: "cursor", in: ten) == nil)
        #expect(prefs.pins(in: ten) == ["qwen"], "below two pins Balance is off, and the choice stays")
    }

    @Test("at least one CLI stays shown, also when an older stored value hides every one")
    func showGuard() {
        let prefs = CLIPreferences(defaults: nil)
        #expect(prefs.setShown(false, for: "codex", in: two) == nil)
        #expect(prefs.setShown(false, for: "claude", in: two) == .lastShown)
        #expect(prefs.hidden(in: two) == ["codex"])
        #expect(prefs.setShown(true, for: "codex", in: two) == nil && prefs.hidden(in: two).isEmpty)
        let stale = CLIPreferences(defaults: nil, hidden: ["claude", "codex", "gone"])
        #expect(stale.hidden(in: two) == ["codex"], "the first registry CLI is shown again; an unknown id is ignored")
    }

    @Test("Show and pins are saved under new keys and read back; the stores shared with v5 keep their keys")
    func persistence() {
        let (defaults, name) = suite()
        defer { defaults.removePersistentDomain(forName: name) }
        let prefs = CLIPreferences(defaults: defaults)
        prefs.setShown(false, for: "codex", in: two)
        prefs.setPinned(true, for: "cursor", in: ten)
        let again = CLIPreferences(defaults: defaults)
        #expect(again.hidden(in: two) == ["codex"])
        #expect(again.pins(in: ten) == ["claude", "codex", "cursor"])
        #expect(defaults.array(forKey: "spacevibe.hiddenCLIs") as? [String] == ["codex"])
        #expect(defaults.array(forKey: "spacevibe.balancePins") as? [String] == ["claude", "codex", "cursor"])
        // Theme, Session widget and Weekly lead: one stored value each, read by both shells.
        #expect(AppearanceStore.defaultsKey == "spacevibe.appearance")
        #expect(GlancePreferences.enabledKey == "spacevibe.glanceWidgetEnabled")
        #expect(LimitsCountdownPreferences.weeklyLeadKey == "spacevibe.weeklyCountdownLead")
        let new = [CLIPreferences.hiddenKey, CLIPreferences.pinsKey]
        #expect(Set(new).isDisjoint(with: [AppearanceStore.defaultsKey, AppearanceStore.fontSizeKey, GlancePreferences.enabledKey,
                                           GlancePreferences.placementKey, LimitsCountdownPreferences.weeklyLeadKey]))
    }

    @Test("the CLIs pane rows at 2 and 10 CLIs: the last shown cannot be hidden, a full set disables the unpinned switches")
    func cliRows() {
        let prefs = CLIPreferences(defaults: nil, pins: ["claude", "codex", "cursor"])
        let rows = SettingsCLIRow.rows(registry: ten, preferences: prefs)
        #expect(rows.map(\.id) == ten.map(\.id))
        #expect(rows.filter(\.isPinned).map(\.id) == ["claude", "codex", "cursor"])
        #expect(rows.filter(\.canChangePin).map(\.id) == ["claude", "codex", "cursor"], "three pinned: only unpinning is offered")
        #expect(rows.first { $0.id == "aider" }?.supports == "Nothing SpaceVibe can show")
        #expect(rows.first { $0.id == "cursor" }?.supports == "Skills · Subagents · Hooks · Rules")
        #expect(rows.allSatisfy { $0.isShown && $0.canChangeShow })
        #expect(SettingsCLIRow.footnote(pinCount: 3).hasSuffix("Three are pinned; unpin one to pin another."))
        #expect(!SettingsCLIRow.footnote(pinCount: 2).contains("Three are pinned"))

        let alone = CLIPreferences(defaults: nil, hidden: ["codex"])
        let small = SettingsCLIRow.rows(registry: two, preferences: alone)
        #expect(small.map(\.isShown) == [true, false])
        #expect(small.map(\.canChangeShow) == [false, true], "Claude Code is the only one shown")
        #expect(small.map(\.canChangePin) == [true, true], "two pinned of three possible")
    }

    @Test("the store's world takes hidden CLIs and pins from Settings; without preferences the facts stand as set")
    func storeFacts() async {
        let prefs = CLIPreferences(defaults: nil, hidden: ["codex"])
        let store = FrameStore(core: FrameFakeCore(), cliPreferences: prefs)
        await store.reread([.registry])
        #expect(store.world().clis.map(\.id) == ["claude"])
        #expect(store.world().facts.findings.pinned == ["claude", "codex"], "a hidden CLI stays pinned; Findings compares shown pins only")
        prefs.setShown(true, for: "codex", in: store.snapshot.registry)
        prefs.setPinned(false, for: "codex", in: store.snapshot.registry)
        #expect(store.world().clis.map(\.id) == ["claude", "codex"], "a change shows at once")
        #expect(store.world().facts.findings.pinned == ["claude"])

        let plain = FrameStore(core: FrameFakeCore())
        plain.facts.hidden = ["claude"]
        await plain.reread([.registry])
        #expect(plain.world().clis.map(\.id) == ["codex"])
        #expect(plain.world().facts.findings.pinned.isEmpty)
    }

    // MARK: Open at login

    @Test("Open at login is off until the switch asks; macOS's answer is reported as it is and a refusal changes nothing")
    func loginItem() {
        let service = StandInLoginItem(status: .off)
        let item = LoginItem(service: service)
        #expect(!item.status.isOn)
        #expect(item.set(true) == nil)
        #expect(item.status == .needsApproval && item.status.isOn, "registered, waiting for approval in System Settings")
        service.status = .on
        item.refresh()
        #expect(item.status == .on)
        service.failure = "Operation not permitted."
        #expect(item.set(false) == "Couldn\u{2019}t turn off Open at login: Operation not permitted. Nothing changed.")
        #expect(item.status == .on)

        let unavailable = LoginItem(service: StandInLoginItem(status: .unavailable(LoginItemWording.testLaunch)))
        #expect(unavailable.set(true) == nil && !unavailable.status.isOn && !unavailable.status.canChange)
        #expect(LoginItem.shared.status == .unavailable(LoginItemWording.testLaunch), "a test launch never reaches macOS")
        #expect(LoginItemWording.refused(turningOn: true, reason: nil) == "Couldn\u{2019}t turn on Open at login. Nothing changed.")
    }

    // MARK: Limits and Data

    @Test("the capture row ages the last snapshot, says when there is none, and reads a failed read as Unmeasurable")
    func snapshotLine() {
        let now = Date(timeIntervalSince1970: 2_000_000)
        #expect(SettingsLimitsWording.snapshot(SettingsFacts(statuslineAt: now.addingTimeInterval(-720), limits: .ready), now: now)
            == "Last snapshot 12 min ago.")
        #expect(SettingsLimitsWording.snapshot(SettingsFacts(limits: .ready), now: now)
            == "No snapshot yet, so Claude Code Windows are Unmeasurable.")
        let failed = SettingsFacts(limits: .failed("could not read limits.read"))
        #expect(SettingsLimitsWording.snapshot(failed, now: now).hasPrefix("Unmeasurable"))
        #expect(SettingsLimitsWording.failure(failed) == "could not read limits.read")
        #expect(SettingsLimitsWording.snapshot(SettingsFacts(), now: now).hasPrefix("Reading"))
        let helper = URL(fileURLWithPath: "/Applications/Space Vibe.app/Contents/Helpers/spacevibe")
        #expect(SettingsLimitsWording.command(remove: false, helper: helper) == "'/Applications/Space Vibe.app/Contents/Helpers/spacevibe' statusline install")
        #expect(SettingsLimitsWording.command(remove: true, helper: helper).hasSuffix("' statusline uninstall"))
    }

    @Test("the data folder is SPACEVIBE_HOME in a development build, else ~/.spacevibe; the trash sits inside it")
    func dataFolder() {
        let home = "/Users/someone"
        let plain = SettingsDataWording.dataFolder(environment: [:], home: home, overridesAllowed: true)
        #expect(plain.path == "/Users/someone/.spacevibe")
        #expect(SettingsDataWording.shown(plain, home: home) == "~/.spacevibe")
        let dev = SettingsDataWording.dataFolder(environment: ["SPACEVIBE_HOME": "/tmp/sv"], home: home, overridesAllowed: true)
        #expect(dev.path == "/tmp/sv" && SettingsDataWording.shown(dev, home: home) == "/tmp/sv")
        #expect(SettingsDataWording.dataFolder(environment: ["SPACEVIBE_HOME": "/tmp/sv"], home: home, overridesAllowed: false).path
            == "/Users/someone/.spacevibe", "a distribution build ignores the variable")
        #expect(SettingsDataWording.trashFolder(in: plain).path == "/Users/someone/.spacevibe/trash")
        #expect(SettingsDataWording.shown(URL(fileURLWithPath: "/Users/someoneelse/x"), home: home) == "/Users/someoneelse/x")
    }

    // MARK: Journal

    @Test("the Journal lists at most 200 newest first, marks undone rows, says empty plainly and never reads a failure as empty")
    func journalList() {
        let now = Date(timeIntervalSince1970: 1_763_900_000)
        func entry(_ n: Int, undone: Bool = false, label: String = "Removed a") -> CoreJournalEntry {
            CoreJournalEntry(id: "e\(n)", at: ISO8601DateFormatter().string(from: now.addingTimeInterval(TimeInterval(-n * 60))),
                             label: label, undone: undone, count: 1)
        }
        #expect(JournalList(history: nil, state: .loading, now: now).content == .pending)
        #expect(JournalList(history: nil, state: nil, now: now).content == .pending)
        let unreadable = JournalList(history: nil, state: .failed("journal is not valid"), now: now)
        #expect(unreadable.content == .unreadable && unreadable.failure == "journal is not valid")
        #expect(JournalList(history: CoreJournalHistory(entries: []), state: .ready, now: now).content == .empty)

        let entries = [entry(3), entry(1, undone: true), entry(2, label: "")] + (4...230).map { entry($0) }
        let list = JournalList(history: CoreJournalHistory(entries: entries), state: .failed("refresh failed"), now: now)
        guard case .rows(let rows) = list.content else { Issue.record("rows expected"); return }
        #expect(rows.count == 200)
        #expect(rows.prefix(3).map(\.id) == ["e1", "e2", "e3"], "newest first")
        #expect(rows[0].isUndone && !rows[1].isUndone)
        #expect(rows[1].label == "Change", "an unnamed change still reads as something")
        #expect(list.failure == "refresh failed", "a failed refresh keeps the rows and shows the error over them")
        #expect(rows[0].control == "journalUndo:e1")
        #expect(JournalList.date("2026-11-21T10:00:00Z") != nil && JournalList.date("2026-11-21T10:00:00.123Z") != nil)
    }

    @Test("Undo from the Journal runs journal.undo, toasts without Undo, re-reads the Journal; a 409 shows the refusal")
    func journalUndo() async {
        let core = FrameFakeCore()
        let toasts = ToastCenter(announce: false)
        let store = FrameStore(core: core)
        let writes = store.makeWrites(toasts: toasts)
        let entry = FrameTestData.entry("e7", label: "Removed ponytail")
        let accepted = await writes.perform(.journalUndo(entry, label: entry.label, touches: FrameWrite.journalSources(store)))
        #expect(accepted)
        #expect(core.calls.contains("journal.undo:e7") && core.calls.contains("journal.history"))
        #expect(toasts.current?.message == "Undid Removed ponytail" && toasts.current?.action == nil)
        #expect(FrameWrite.journalSources(store).isSuperset(of: [.inventory, .loadout, .kept, .rules(.global)]))

        core.undoResult = .failure(CoreError("Nothing changed: the file changed since this edit.", status: 409))
        core.reset()
        let refused = await writes.perform(.journalUndo(entry, label: entry.label, touches: [.loadout]))
        #expect(!refused)
        #expect(toasts.current?.tone == .danger && toasts.current?.message == "Nothing changed: the file changed since this edit.")
        #expect(!writes.isPending(FrameWrite.journalUndoControl("e7")))
    }

    // MARK: Blocks

    @Test("the switch block: primary track with a white knob when on, faint track with an ink knob in dark and white in light")
    func switchBlock() {
        #expect(FrameSwitch.knobInk(isOn: true, dark: true) == ColorRole.onPrimaryAction)
        #expect(FrameSwitch.knobInk(isOn: false, dark: true) == ColorRole.ink)
        #expect(FrameSwitch.knobInk(isOn: false, dark: false) == ColorRole.onPrimaryAction)
        #expect(FrameSwitch.trackHeight >= SizeRole.controlMini && FrameSwitch.knob < FrameSwitch.trackHeight)
    }

    // MARK: States

    @Test("each state opens the pane it changes, from synthetic data at 2 and 10 CLIs")
    func states() {
        #expect(SettingsWindowState.empty.openingPane == .limits && SettingsWindowState.error.openingPane == .limits)
        #expect(SettingsWindowState.worst.openingPane == .clis && SettingsWindowState.dialog.openingPane == .clis)
        #expect(SettingsWindowState.normal.openingPane == nil && SettingsWindowState.refused.openingPane == nil)
        let glance = GlancePreferences(defaults: UserDefaults(suiteName: "dev.spacevibe.tests.glance.\(UUID().uuidString)")!)
        let worst = SettingsWindowShots.preview(.worst, glance: glance)
        #expect(worst.facts.registry.count == 10 && worst.cli.hidden(in: worst.facts.registry) == ["opencode", "aider"])
        let dialog = SettingsWindowShots.preview(.dialog, glance: glance)
        #expect(dialog.cli.pins(in: dialog.facts.registry).count == CLIPreferences.maxPins)
        #expect(SettingsWindowShots.preview(.empty, glance: glance).facts.statuslineAt == nil)
        #expect(SettingsWindowShots.preview(.refused, glance: glance).refusal?.hasSuffix("Nothing changed.") == true)
        #expect(SettingsWindowShots.preview(.normal, glance: glance).refusal == nil)
    }
}
