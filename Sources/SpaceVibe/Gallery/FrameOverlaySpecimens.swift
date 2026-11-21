import SwiftUI

/// The redesign's feedback and overlay blocks (RB-S4, DS-R10) open, dark beside light: the write toast and the refused-write
/// toast, the empty, scanning and error states, the three pick menus, the legend, the shared-file confirmation, the per-CLI
/// sheet, the remove confirmation and the Stop alert's wording. Overlays are drawn in place (open) rather than anchored, so
/// every state shows at once; the Stop alert is the system's and only its text is drawn.
struct FrameOverlaySpecimens: View {
    var body: some View {
        FrameSpecimenColumns {
            toasts
            states
            menus
            popovers
            sheets
            stopAlert
        }
    }

    private static let refusedLong = "Couldn’t add pdf-extract to Codex: ~/.codex/skills/pdf-extract already exists and is not a "
        + "SpaceVibe copy, and ~/.agents/skills/pdf-extract is read by Codex, Cursor CLI and Amp, so SpaceVibe left both in place "
        + "rather than guess which one you meant to keep. Rename one of them in Finder and try again. Nothing changed."

    private var toasts: some View {
        FrameSpecimenGroup(title: "Toasts: done with Undo, a long one that wraps, Stop (no Undo); refused, refused long with Details, opened, partial") {
            VStack(alignment: .leading, spacing: SpaceRole.step12) {
                WriteToast(message: "Removed lint-staged.sh from Claude Code", undo: {})
                WriteToast(message: "Removed 3 Skills, 2 Subagents and \(FrameSpecimenData.longName) from Claude Code, Codex, Cursor CLI and Amp. settings.json was edited", undo: {})
                WriteToast(message: "Stopped pid 48211. This can’t be undone.")
                RefusedWriteToast(message: "Couldn’t remove lint-staged.sh: ~/.claude/settings.json changed since SpaceVibe read it. Nothing changed.",
                                  actionTitle: "Reload", actionIcon: .arrowClockwise, action: {}) {}
                RefusedWriteToast(message: Self.refusedLong, actionTitle: "Show in Finder", actionIcon: .folderOpen, action: {}) {}
                RefusedWriteToast(message: Self.refusedLong, expanded: true) {}
                RefusedWriteToast(message: "Moved 2 of 3. ~/.codex/cache is in use, so it stayed in place. Undo puts back what moved.",
                                  isPartial: true, actionTitle: "Undo", actionIcon: .arrowCounterClockwise, action: {}) {}
            }
        }
    }

    private var states: some View {
        FrameSpecimenGroup(title: "Empty, scanning (with and without a total), error") {
            VStack(alignment: .leading, spacing: SpaceRole.step12) {
                PageEmptyState(icon: .clean, title: "Nothing to clean",
                               text: "Every item ran, no session log is older than 90 days, the caches are empty.") {
                    Button {} label: { PushButtonLabel("Scan Again", icon: .arrowClockwise) }.buttonStyle(PushButtonStyle(.control))
                }
                StatusBanner(.scanning(progress: 0.35), title: "Reading the process table and session logs…")
                StatusBanner(.scanning(progress: nil), title: "Counting sessions", detail: "The first scan of 4,830 logs")
                StatusBanner(.problem(.critical), title: "Unmeasurable",
                             detail: "~/.codex/sessions could not be read, so these Windows are Unmeasurable, not 0%.") {
                    Button {} label: { PushButtonLabel("Try Again", icon: .arrowClockwise, size: .small) }
                        .buttonStyle(PushButtonStyle(.control, size: .small))
                }
                StatusBanner(.problem(.attention), title: "Codex folder could not be read",
                             detail: "~/.codex could not be read, so every Codex figure is Unmeasurable here, not zero.")
            }
        }
    }

    private var options: [CLIMenuEntries.Option] {
        FrameSpecimenData.clis.enumerated().map { index, cli in
            CLIMenuEntries.Option(cli: cli, isSupported: index != 9 && index != 8, isReadOnly: index != 0)
        }
    }

    private var menus: some View {
        FrameSpecimenGroup(title: "Menus: All CLIs at 10 CLIs (Not supported disabled), the CLI picker, the project picker; their buttons closed and open") {
            VStack(alignment: .leading, spacing: SpaceRole.step12) {
                MenuPanel(heading: CLIMenuEntries.scopeHeading, entries: CLIMenuEntries.scope(options, scope: nil),
                          footnote: CLIMenuEntries.scopeFootnote, pick: { _ in }, close: {})
                VStack(alignment: .leading, spacing: SpaceRole.step12) {
                    MenuPanel(entries: CLIMenuEntries.picker(options, chosen: "claude"), pick: { _ in }, close: {})
                    MenuPanel(entries: CLIMenuEntries.projects([
                        .init(name: "payments-web", path: "~/Development/payments-web"),
                        .init(name: "ledger-api", path: "~/Development/ledger-api"),
                        .init(name: FrameSpecimenData.longName, path: FrameSpecimenData.longPath),
                    ], chosen: "payments-web"), width: BlockRole.menuWidth + BlockRole.menuDetailMaxWidth, pick: { _ in }, close: {})
                }
            }
            HStack(spacing: SpaceRole.step8) {
                MenuTrigger(title: "All CLIs", isOpen: false, label: "CLIs shown") {}
                MenuTrigger(title: "Claude Code", lead: .cli(.claude), isOpen: true, label: "CLI") {}
                MenuTrigger(title: "payments-web", lead: .icon(.folderSimple), isOpen: false, label: "Project") {}
            }
        }
    }

    private var popovers: some View {
        FrameSpecimenGroup(title: "Legend popover and its button; the shared-file confirmation under a logo") {
            HStack(alignment: .top, spacing: SpaceRole.step12) {
                VStack(alignment: .leading, spacing: SpaceRole.step8) {
                    CLILegendButton(isOpen: true) {}
                    CLILegend(clis: FrameSpecimenData.clis) {}
                }
                SharedFileConfirmation(wording: .init(cli: "Codex", files: ["~/.agents/skills/pdf-extract"],
                                                      losers: ["Codex", "Cursor CLI", "Amp"], savable: ["Cursor CLI"],
                                                      savableShort: ["Cursor"]),
                                       cancel: {}, removeForAll: {}, copyThenRemove: {})
            }
        }
    }

    private var sheetModel: PerCLISheetModel {
        let lines = FrameSpecimenData.clis.prefix(7).enumerated().map { index, cli in
            PerCLISheetLine(cli: cli, folder: index == 1 ? "~/.agents/skills" : "~/.\(cli.id)/skills",
                            otherReaders: index == 1 ? ["Cursor CLI", "Amp"] : [], itemCount: 3 - index % 3,
                            via: index == 5 ? ["Claude Code"] : [],
                            losers: index == 1 ? [cli, FrameSpecimenData.cli(2), FrameSpecimenData.cli(5)] : [cli])
        }
        return PerCLISheetModel(mode: .remove, itemCount: 3, noun: "Skill", lines: lines, ticked: ["codex", "claude"])
    }

    private var sheets: some View {
        FrameSpecimenGroup(title: "Per-CLI sheet (two ticked, a shared folder, a via line, 7 CLIs so it scrolls); nothing ticked; remove confirmation with 8 items") {
            VStack(alignment: .leading, spacing: SpaceRole.step12) {
                PerCLISheet(model: sheetModel, toggle: { _ in }, switchMode: { _ in }, cancel: {}, confirm: {})
                    .frame(height: SpecimenSize.sheet)
                PerCLISheet(model: PerCLISheetModel(mode: .add, itemName: FrameSpecimenData.longName, itemCount: 1, noun: "Skill",
                                                    lines: Array(sheetModel.lines.prefix(3))),
                            toggle: { _ in }, switchMode: { _ in }, cancel: {}, confirm: {})
                    .frame(height: SpecimenSize.sheet)
            }
            RemoveConfirmation(items: (0 ..< 8).map { index in
                RemoveConfirmation.Item(id: "\(index)", name: index == 0 ? FrameSpecimenData.longName : "skill-\(index)",
                                        icon: index % 3 == 2 ? .hooks : .skills,
                                        losers: index == 0 ? FrameSpecimenData.clis.prefix(4).map(\.name) : ["Claude Code"])
            }, cancel: {}, remove: {})
            .frame(height: SpecimenSize.sheet)
        }
    }

    private var stopAlert: some View {
        let text = StopAlertText(sessions: (0 ..< 7).map { index in
            StopAlertText.Session(title: index == 0 ? "Fix flaky checkout test" : "Session \(index)", pid: Int32(48211 + index), cli: "Claude Code")
        })
        return FrameSpecimenGroup(title: "Stop alert (system alert, destructive role, Cancel default): its wording for 7 sessions") {
            Text(text.title).typeRole(.bodyMedium).foregroundStyle(ColorRole.ink)
            Text(text.message).typeRole(.quiet).foregroundStyle(ColorRole.ink2).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: SpaceRole.step8) {
                Button {} label: { Text("Cancel") }.buttonStyle(PushButtonStyle(.control))
                Button {} label: { Text(text.confirmTitle) }.buttonStyle(PushButtonStyle(.destructive))
            }
        }
    }

    private enum SpecimenSize {
        /// Room for a sheet and its scrim.
        static let sheet: CGFloat = 640
    }
}
