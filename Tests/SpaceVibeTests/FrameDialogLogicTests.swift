import Testing
@testable import SpaceVibe

/// The pure rules under the redesign's dialogs and toasts (RB-S4): capped lists (RD-R16), the Stop alert's wording, the toast
/// line limits (RD-R17) and the per-CLI sheet's count (RD-R11).
@Suite("Frame dialogs: capped lists, Stop, toasts, per-CLI sheet")
struct FrameDialogLogicTests {
    @Test("a dialog lists at most 5 rows, then and N more", arguments: [0, 1, 5, 6, 8, 40])
    func capped(count: Int) {
        let list = CappedList(Array(0 ..< count))
        #expect(list.shown == Array(0 ..< min(count, 5)))
        #expect(list.hiddenCount == max(0, count - 5))
        let more = list.moreLine(one: "item")
        if count <= 5 { #expect(more == nil) } else { #expect(more == "and \(count - 5) more \(count - 5 == 1 ? "item" : "items")") }
    }

    @Test("Stop names the pid and the consequence, lists 5 sessions and the rest as a count, and keeps Cancel first")
    func stopAlert() {
        let one = StopAlertText(sessions: [.init(title: "Fix flaky checkout test", pid: 48211, cli: "Claude Code")])
        #expect(one.title == "Stop “Fix flaky checkout test”?")
        #expect(one.confirmTitle == "Stop Session 48211")
        #expect(one.lines == ["Claude Code · Fix flaky checkout test · pid 48211"])
        #expect(one.message.hasSuffix("This can’t be undone."))
        let many = StopAlertText(sessions: (0 ..< 7).map { .init(title: "S\($0)", pid: Int32(100 + $0), cli: "Codex") })
        #expect(many.title == "Stop 7 sessions?")
        #expect(many.confirmTitle == "Stop 7 Sessions")
        #expect(many.lines.count == 6 && many.lines.last == "and 2 more sessions")
    }

    @Test("a refused write says Nothing changed first; other messages stay as they are")
    func refusedOrder() {
        #expect(ToastText.refusedMessage("Couldn’t remove x: settings.json changed. Nothing changed.")
            == "Nothing changed. Couldn’t remove x: settings.json changed.")
        #expect(ToastText.refusedMessage("Moved 2 of 3. Undo puts back what moved.") == "Moved 2 of 3. Undo puts back what moved.")
        #expect(ToastText.refusedMessage("Nothing changed.") == "Nothing changed.")
    }

    @Test("a refused toast clamps at 3 lines and offers Details only when the text needs more")
    func refusedLines() {
        let short = "Nothing changed. ~/.claude/settings.json changed since SpaceVibe read it."
        let long = String(repeating: "~/.codex/skills/pdf-extract already exists and is not a SpaceVibe copy. ", count: 8)
        #expect(ToastText.lineCount(short, width: 520) == 1)
        #expect(ToastText.lineCount(long, width: 300) > 3)
        #expect(!ToastText.needsDetails(short, width: 520))
        #expect(ToastText.needsDetails(long, width: 300))
        #expect(!ToastText.needsDetails(long, width: 0), "no Details before the width is known")
        #expect(ToastText.lineCount("", width: 300) == 0)
        #expect(ToastText.lineLimit(expanded: false) == 3 && ToastText.lineLimit(expanded: true) == nil)
        #expect(ToastText.lineCount(short, width: 120) > ToastText.lineCount(short, width: 520), "it wraps, never cuts")
    }

    // MARK: Per-CLI sheet

    private let cursor = CLIIdentity(id: "cursor", name: "Cursor CLI")
    private let amp = CLIIdentity(id: "amp", name: "Amp")

    private func removeSheet(items: Int = 1) -> PerCLISheetModel {
        PerCLISheetModel(mode: .remove, itemName: "pdf-extract", itemCount: items, noun: "Skill", lines: [
            PerCLISheetLine(cli: .claude, folder: "~/.claude/skills", losers: [.claude]),
            PerCLISheetLine(cli: .codex, folder: "~/.agents/skills", otherReaders: ["Cursor CLI", "Amp"], losers: [.codex, cursor, amp]),
            PerCLISheetLine(cli: cursor, folder: "~/.claude/skills", via: ["Claude Code"]),
        ])
    }

    @Test("nothing is ticked at first, so the button asks for a CLI and cannot confirm")
    func sheetStartsEmpty() {
        let sheet = removeSheet()
        #expect(sheet.ticked.isEmpty && !sheet.canConfirm)
        #expect(sheet.confirmTitle == "Select a CLI")
        #expect(sheet.title == "Remove pdf-extract from…")
        #expect(sheet.sharedWarning == nil)
    }

    @Test("the button counts every CLI that loses the item, readers of a shared folder included")
    func sheetCountsLosers() {
        let codex = removeSheet().toggling("codex")
        #expect(codex.affected.map(\.id) == ["codex", "cursor", "amp"])
        #expect(codex.confirmTitle == "Remove from 3 CLIs")
        #expect(codex.sharedWarning == "Shared files: this also removes it for Cursor CLI and Amp.")
        let both = codex.toggling("claude")
        #expect(both.affected.map(\.id) == ["claude", "codex", "cursor", "amp"], "line order, each CLI once")
        #expect(both.confirmTitle == "Remove from 4 CLIs")
        let three = PerCLISheetModel(mode: .remove, itemCount: 3, noun: "Skill", lines: removeSheet().lines).toggling("claude")
        #expect(three.confirmTitle == "Remove 3 from 1 CLI")
        #expect(three.title == "Remove 3 Skills from…")
        #expect(three.sharedWarning == nil)
    }

    @Test("a via line cannot be ticked; unticking clears; switching mode clears the ticks")
    func sheetTicks() {
        let sheet = removeSheet()
        #expect(sheet.toggling("cursor") == sheet, "via: removed only with Claude Code's folder")
        #expect(sheet.toggling("codex").toggling("codex").ticked.isEmpty)
        #expect(sheet.toggling("nope") == sheet)
        #expect(sheet.toggling("codex").switching(to: .add, lines: sheet.lines).ticked.isEmpty)
        #expect(sheet.lines[2].detail == "Via Claude Code’s folder: removed only with it")
        #expect(sheet.lines[1].detail == "~/.agents/skills · also read by Cursor CLI and Amp")
        #expect(sheet.lines[0].detail == "~/.claude/skills")
    }

    @Test("an add counts only the ticked CLIs")
    func sheetAdd() {
        let add = PerCLISheetModel(mode: .add, itemCount: 2, noun: "Subagent", lines: [
            PerCLISheetLine(cli: .codex, folder: "~/.codex/agents", losers: [.codex, cursor]),
            PerCLISheetLine(cli: amp, folder: "~/.config/amp/agents"),
        ]).toggling("codex").toggling("amp")
        #expect(add.affected.map(\.id) == ["codex", "amp"])
        #expect(add.confirmTitle == "Add 2 to 2 CLIs")
        #expect(add.title == "Add 2 Subagents to…")
        #expect(add.sharedWarning == nil)
    }

    @Test("the shared-file confirmation names every other loser and who can keep a copy")
    func sharedFile() {
        let wording = SharedFileConfirmation.Wording(cli: "Codex", files: ["~/.agents/skills/pdf-extract"],
                                                     losers: ["Codex", "Cursor CLI", "Amp"], savable: ["Cursor CLI"],
                                                     savableShort: ["Cursor"])
        #expect(wording.sentence == "~/.agents/skills/pdf-extract is also how Cursor CLI and Amp get it. Removing it from Codex "
            + "removes it for them too. Cursor CLI can keep it with its own copy.")
        #expect(wording.removeTitle == "Remove for 3 CLIs")
        #expect(wording.copyTitle == "Copy to Cursor first, then remove")
        let alone = SharedFileConfirmation.Wording(cli: "Codex", files: ["a", "b"], losers: ["Codex", "Amp"], savable: [])
        #expect(alone.sentence == "a and b are also how Amp gets it. Removing it from Codex removes it for it too.")
        #expect(alone.copyTitle == nil)
    }

    @Test("the shared-file confirmation when no other CLI loses it: a whole sentence, never an empty list of names")
    func sharedFileNoOtherLoser() {
        let wording = SharedFileConfirmation.Wording(cli: "Codex", files: ["~/.agents/skills/pdf-extract"], losers: ["Codex"], savable: [])
        #expect(wording.sentence == "~/.agents/skills/pdf-extract is read by other CLIs too, but each of them keeps the item from another "
            + "folder, so only Codex loses it.")
        #expect(wording.removeTitle == "Remove for 1 CLI" && wording.copyTitle == nil)
    }

    @Test("the remove confirmation names every reader and counts the items")
    func removeConfirmation() {
        #expect(RemoveConfirmation.title(1) == "Remove 1 item?" && RemoveConfirmation.title(8) == "Remove 8 items?")
        #expect(RemoveConfirmation.confirmTitle(1_204) == "Remove 1,204")
        #expect(RemoveConfirmation.fromLine(["Claude Code", "Codex", "Amp"]) == "From Claude Code, Codex and Amp")
    }
}
