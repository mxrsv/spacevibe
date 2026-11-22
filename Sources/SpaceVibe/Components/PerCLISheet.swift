import SwiftUI

/// The per-CLI sheet (DS-R10 "sheet"; RD-R11 "Bulk and Remove…"; the mock's `bulkSheet`) opened by `Add to…`, `Remove from…`
/// and an item's `Remove…`: the title, an Add to / Remove from switch, one line per CLI with its checkbox, logo, name, count
/// and the real folder with who else reads it, the shared-file warning, then Cancel (default) and the button that counts every
/// CLI that changes (`PerCLISheetModel.confirmTitle`). Nothing is ticked at first; a "via" line is shown dimmed and cannot be
/// ticked. The list scrolls past five lines so the buttons stay in reach (RD-R16).
struct PerCLISheet: View {
    let model: PerCLISheetModel
    var isWorking = false
    let toggle: (String) -> Void
    let switchMode: (PerCLISheetModel.Mode) -> Void
    let cancel: () -> Void
    let confirm: () -> Void

    var body: some View {
        DialogSheet(title: model.title, isWorking: isWorking, cancel: cancel) {
            VStack(alignment: .leading, spacing: SpaceRole.step10) {
                ModeSwitch(mode: model.mode, select: switchMode)
                    .frame(maxWidth: .infinity)
                    .padding(.top, SpaceRole.step4)
                lines
                if let warning = model.sharedWarning {
                    HStack(alignment: .firstTextBaseline, spacing: SpaceRole.step6) {
                        FrameGlyph(.warningFill, side: SizeRole.icon12, ink: ColorRole.stateAttention, label: "Needs attention")
                        Text(warning)
                            .typeRole(.quiet)
                            .foregroundStyle(ColorRole.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        } confirm: {
            Button(action: confirm) { Text(model.confirmTitle).frame(maxWidth: .infinity) }
                .buttonStyle(PushButtonStyle(model.mode == .add ? .primary : .destructive, isLoading: isWorking))
                .focusEffectDisabled()
                .disabled(!model.canConfirm)
        }
    }

    @ViewBuilder
    private var lines: some View {
        let list = VStack(alignment: .leading, spacing: SpaceRole.step10) {
            if model.lines.isEmpty {
                Text("No CLI to choose.").typeRole(.quiet).foregroundStyle(ColorRole.ink3)
            }
            ForEach(model.lines) { line in
                DialogListLine(name: lineName(line), detail: line.detail, detailIsPath: line.via.isEmpty,
                               isEnabled: line.isTickable) {
                    HStack(spacing: SpaceRole.step4) {
                        CheckboxCell(model.ticked.contains(line.id) && line.isTickable ? .on : .off, label: line.cli.name) {
                            toggle(line.id)
                        }
                        .disabled(!line.isTickable)
                        CLILogo(line.cli, size: SizeRole.logo16)
                    }
                    .frame(height: SizeRole.hitCell)
                }
            }
        }
        .padding(.vertical, SpaceRole.step6)
        if model.lines.count > DialogCap.rows {
            ScrollView { list }.frame(maxHeight: BlockRole.dialogListMaxHeight)
        } else {
            list
        }
    }

    /// "Codex · 3" when several items are picked.
    private func lineName(_ line: PerCLISheetLine) -> String {
        model.itemCount > 1 && line.isTickable ? "\(line.cli.name) · \(NumberWording.count(line.itemCount))" : line.cli.name
    }
}

/// The sheet's Add to / Remove from switch: the frame's segmented control at its regular size, as the mock's sheet draws its
/// `.seg` (`b-chrome.js`), so it has the control's hover, press, keyboard focus and ← →.
private struct ModeSwitch: View {
    let mode: PerCLISheetModel.Mode
    let select: (PerCLISheetModel.Mode) -> Void

    var body: some View {
        FrameSegmentedControl(segments: Self.segments, selection: Self.id(mode), label: "Mode") { id in
            select(id == Self.id(.remove) ? .remove : .add)
        }
    }

    static let segments = [FrameSegment(id: id(.add), title: "Add to"), FrameSegment(id: id(.remove), title: "Remove from")]

    static func id(_ mode: PerCLISheetModel.Mode) -> String { mode == .add ? "add" : "remove" }
}
