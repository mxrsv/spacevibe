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

/// The sheet's Add to / Remove from switch: two segments on a control fill, the chosen one on the selection fill.
private struct ModeSwitch: View {
    let mode: PerCLISheetModel.Mode
    let select: (PerCLISheetModel.Mode) -> Void

    var body: some View {
        HStack(spacing: 0) {
            segment("Add to", .add)
            segment("Remove from", .remove)
        }
        .padding(SizeRole.segmentedInset)
        .frame(height: SizeRole.segmentedSmall)
        .background(RoundedRectangle(cornerRadius: RadiusRole.step6, style: .continuous).fill(ColorRole.controlFill))
        .fixedSize()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Mode")
    }

    private func segment(_ title: String, _ value: PerCLISheetModel.Mode) -> some View {
        let isOn = mode == value
        return Button { select(value) } label: {
            Text(title)
                .typeRole(.quietMedium)
                .foregroundStyle(isOn ? ColorRole.ink : ColorRole.controlSecondaryInk)
                .padding(.horizontal, SpaceRole.step10)
                .frame(height: SizeRole.segmentSmall)
                .background(RoundedRectangle(cornerRadius: RadiusRole.step4, style: .continuous)
                    .fill(isOn ? ColorRole.selectionFill : .clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .focusEffectDisabled()
        .accessibilityAddTraits(isOn ? [.isSelected] : [])
    }
}
