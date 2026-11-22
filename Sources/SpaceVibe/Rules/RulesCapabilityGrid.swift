import SwiftUI

/// Claude Code's six capabilities (the mock's `.cap` rows; the signature of the Rules page, design-notes §2): the icon, the
/// name, why the cell reads what it reads, and the Allow / Ask / Deny dial. A Mixed cell is locked and says which rules
/// disagree. A press opens the preview under the dial (`rules.preview`) before anything is written.
struct RulesCapabilityGrid: View {
    let list: RulesListModel
    let state: RulesPageState

    var body: some View {
        RowGroup {
            ForEach(Array(list.capabilities.enumerated()), id: \.element.id) { index, row in
                HStack(spacing: SpaceRole.step12) {
                    FrameGlyph(row.icon, side: SizeRole.icon20, ink: ColorRole.ink3)
                        .frame(width: TableColumnWidth.glyph)
                    Text(row.label)
                        .typeRole(.bodyMedium)
                        .foregroundStyle(ColorRole.ink)
                        .lineLimit(1)
                        .frame(width: TableColumnWidth.capabilityName, alignment: .leading)
                    Text(row.why)
                        .typeRole(.quiet)
                        .foregroundStyle(ColorRole.ink3)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .help(row.why)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    dial(row)
                        .frame(width: TableColumnWidth.capabilityDial, alignment: .leading)
                }
                .padding(.horizontal, SpaceRole.step12)
                .frame(maxWidth: .infinity, minHeight: SizeRole.listRow, alignment: .leading)
                .rowStripe(index.isMultiple(of: 2))
                .accessibilityElement(children: .contain)
                .accessibilityLabel("\(row.label), \(row.why)")
            }
        }
    }

    private func dial(_ row: RulesCapabilityRow) -> some View {
        let isOpen = state.preview.map { $0.capability == row.id && $0.file == list.file } ?? false
        // The track spans the 190 column (the mock's grid cell stretches `.dial`), its steps at the leading end.
        return PermissionDial(selection: row.selection, label: row.label, lockedWord: row.isMixed ? "Mixed" : nil, fillsWidth: true) { verdict in
            state.requestPreview(row, to: verdict)
        }
        .disabled(!row.isEditable && !row.isMixed)
        .help(row.isMixed ? "Mixed cells are read-only: change the rules below" : "Change \(row.label)")
        .anchoredOverlay(isPresented: isOpen, id: "rules.preview", placement: .popover, onOutsideTap: { state.closePreview() }) {
            if let request = state.preview {
                RulesPreviewPopover(row: row, request: request, fileName: list.fileName, state: state)
            }
        }
    }
}

/// What a capability change will write, before it writes (the mock's `capPreview`): the change, the file, the warning when
/// the cell will still not read the chosen verdict, Cancel and `Change to …`. A same-value press reads "Nothing to change"
/// with the button disabled, so nothing is written. Esc and an outside click close it.
struct RulesPreviewPopover: View {
    let row: RulesCapabilityRow
    let request: RulesPreviewRequest
    let fileName: String
    let state: RulesPageState

    var body: some View {
        PopoverPanel(label: "Preview", close: { state.closePreview() }) {
            switch request.phase {
            case .loading:
                Text("\(row.label) \u{2192} \(PermissionDial.title(request.verdict))").typeRole(.bodyMedium).foregroundStyle(ColorRole.ink)
                Text("Reading what would change\u{2026}").typeRole(.quiet).foregroundStyle(ColorRole.ink3)
                buttons(confirm: "Change to \(PermissionDial.title(request.verdict))", enabled: false, loading: true)
            case .failed(let message):
                Text("\(row.label) \u{2192} \(PermissionDial.title(request.verdict))").typeRole(.bodyMedium).foregroundStyle(ColorRole.ink)
                HStack(alignment: .firstTextBaseline, spacing: SpaceRole.step6) {
                    FrameGlyph(.xCircleFill, side: SizeRole.icon12, ink: ColorRole.stateCritical, label: "Refused")
                    Text(message).typeRole(.quiet).foregroundStyle(ColorRole.ink2).fixedSize(horizontal: false, vertical: true)
                }
                buttons(confirm: nil, enabled: false, loading: false)
            case .ready(let preview):
                let text = RulesPreviewText(row: row, preview: preview, fileName: fileName)
                Text(text.title).typeRole(.bodyMedium).foregroundStyle(ColorRole.ink)
                InlineCodeText(text.whatSpans)
                if let warning = text.warningSpans {
                    HStack(alignment: .firstTextBaseline, spacing: SpaceRole.step6) {
                        FrameGlyph(.warningFill, side: SizeRole.icon12, ink: ColorRole.stateAttention, label: "Needs attention")
                        InlineCodeText(warning)
                    }
                }
                buttons(confirm: text.confirmTitle, enabled: !text.isNothing, loading: false)
            }
        }
    }

    private func buttons(confirm: String?, enabled: Bool, loading: Bool) -> some View {
        HStack(spacing: SpaceRole.step8) {
            Spacer(minLength: 0)
            Button("Cancel") { state.closePreview() }
                .buttonStyle(PushButtonStyle(.quiet, size: .small))
                .focusEffectDisabled()
                .keyboardShortcut(.cancelAction)
            if let confirm {
                Button(confirm) { state.confirmPreview(row, fileName: fileName) }
                    .buttonStyle(PushButtonStyle(.control, size: .small, isLoading: loading))
                    .focusEffectDisabled()
                    .disabled(!enabled)
            }
        }
    }
}
