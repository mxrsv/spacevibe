import AppKit
import SwiftUI

/// The Skills or Subagents inspector (RD15, RD-R12; the mock's `tileInspector`): the name with the kind's icon in its tone, the
/// description (clamped, with More), `Remove…` (or the read-only line of a plugin or project item), the `CLIs` tile grid (the
/// same toggles as the row's logos, heat against the item's top CLI, at most 3 rows), the facts (Owner, each file and who reads
/// it, Added) and Show in Finder. Nothing selected: the empty state (RD41: nothing is pre-selected).
struct EquipInspector: View {
    let state: EquipPageState

    var body: some View {
        let list = state.list()
        if let row = list.row(state.router?.route.selection) {
            EquipInspectorBody(row: row, list: list, state: state)
        } else {
            PageEmptyState(icon: .sidebarSimple, text: "Select a row to see its details.")
        }
    }
}

/// One fact line of the inspector (the mock's `dl.kv`).
struct EquipFact: Equatable, Sendable {
    let key: String
    let value: String
    var isPath = false
    /// A quiet line under the value ("read by Codex and Amp").
    var note: String?
}

private struct EquipInspectorBody: View {
    let row: EquipListRow
    let list: EquipListModel
    let state: EquipPageState

    var body: some View {
        VStack(alignment: .leading, spacing: SpaceRole.step16) {
            VStack(alignment: .leading, spacing: SpaceRole.step4) {
                InspectorTitle(row.name) {
                    FrameGlyph(list.kind.page.icon, side: SizeRole.icon20, ink: list.kind.page.categoryTone)
                }
                description
            }
            action
            InspectorSection("CLIs") { EquipTileCell(row: row, state: state) }
            Grid(alignment: .topLeading, horizontalSpacing: SpaceRole.step8, verticalSpacing: SpaceRole.step6) {
                ForEach(Array(EquipInspectorFacts.facts(row, clis: list.clis, now: Date()).enumerated()), id: \.offset) { _, fact in
                    GridRow {
                        Text(fact.key).typeRole(.quiet).foregroundStyle(ColorRole.ink3)
                        VStack(alignment: .leading, spacing: 0) {
                            if fact.isPath {
                                MiddleTruncatedText(fact.value).typeRole(.mono).foregroundStyle(ColorRole.ink)
                            } else {
                                Text(fact.value).typeRole(.quiet).foregroundStyle(ColorRole.ink).fixedSize(horizontal: false, vertical: true)
                            }
                            if let note = fact.note {
                                Text(note).typeRole(.quiet).foregroundStyle(ColorRole.ink3).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
            }
            if let path = row.row.items.first?.path {
                Button { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)]) } label: {
                    PushButtonLabel("Show in Finder", icon: .folderOpen, size: .small)
                }
                .buttonStyle(PushButtonStyle(.control, size: .small))
                .focusEffectDisabled()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var description: some View {
        if let text = row.row.items.first?.description, !text.isEmpty {
            let long = EquipInspectorFacts.isLong(text)
            InspectorNote(text)
                .lineLimit(long && !state.isDescriptionExpanded ? EquipInspectorFacts.clampedLines : nil)
            if long {
                Button(state.isDescriptionExpanded ? "Less" : "More") { state.isDescriptionExpanded.toggle() }
                    .buttonStyle(PushButtonStyle(.link, size: .small))
                    .focusEffectDisabled()
            }
        }
    }

    @ViewBuilder
    private var action: some View {
        if let owner = EquipInspectorFacts.readOnlyLine(row) {
            HStack(spacing: SpaceRole.step6) {
                FrameGlyph(.lockSimple, side: SizeRole.icon14, ink: ColorRole.ink3)
                Text(owner).typeRole(.quiet).foregroundStyle(ColorRole.ink3).lineLimit(1)
            }
            .accessibilityElement(children: .combine)
        } else {
            Button { state.openSheet(.remove, rows: [row.id]) } label: { PushButtonLabel("Remove…", icon: .trash, size: .small) }
                .buttonStyle(PushButtonStyle(.destructive, size: .small, isLoading: state.isPending(EquipControl.sheet(list.kind.page))))
                .focusEffectDisabled()
                .disabled(!list.canRemove(row))
        }
    }
}

/// The tile grid with the shared-file confirmation anchored under the pressed tile.
private struct EquipTileCell: View {
    let row: EquipListRow
    let state: EquipPageState

    var body: some View {
        CLITileGrid(states: row.toggles) { toggle in state.press(toggle, on: row, from: .tile) }
            .popover(isPresented: isPresented, attachmentAnchor: .rect(.rect(anchor)), arrowEdge: .bottom) { confirmation }
    }

    private var prompt: EquipPageState.SharedPrompt? {
        guard let prompt = state.shared, prompt.anchor == .tile, prompt.removal.rowID == row.id else { return nil }
        return prompt
    }

    private var isPresented: Binding<Bool> {
        Binding(get: { prompt != nil }, set: { if !$0, prompt != nil { state.shared = nil } })
    }

    /// The pressed tile inside the grid (`CLITileGridLayout`: `max(3, ceil(N/3))` columns, 72 × 60, 6 apart).
    private var anchor: CGRect {
        let index = prompt.flatMap { prompt in row.toggles.firstIndex { $0.cli.id == prompt.removal.cli } } ?? 0
        let columns = CLITileGridLayout.columns(row.toggles.count)
        return CGRect(x: CGFloat(index % columns) * (BlockRole.tileWidth + BlockRole.tileGap),
                      y: CGFloat(index / columns) * (BlockRole.tileHeight + BlockRole.tileGap),
                      width: BlockRole.tileWidth, height: BlockRole.tileHeight)
    }

    @ViewBuilder
    private var confirmation: some View {
        if let prompt {
            SharedFileConfirmation(wording: prompt.removal.wording, cancel: { state.shared = nil },
                                   removeForAll: { state.confirmShared(copyFirst: false) },
                                   copyThenRemove: prompt.removal.savable.isEmpty ? nil : { state.confirmShared(copyFirst: true) })
        }
    }
}

/// The inspector's words, pure for the tests.
enum EquipInspectorFacts {
    /// A description longer than this is clamped to `clampedLines` with More (the mock's 160).
    static let longDescription = 160
    static let clampedLines = 3

    static func isLong(_ text: String) -> Bool { text.count > longDescription }

    /// "Read-only · project payments-web", "Read-only · design-kit plugin"; nil for the user's own.
    static func readOnlyLine(_ row: EquipListRow) -> String? {
        if row.row.isProject { return "Read-only · project \(EquipToggles.projectName(row.row) ?? "")" }
        guard row.row.isPlugin else { return nil }
        return "Read-only · \(pluginName(row.row)) plugin"
    }

    static func pluginName(_ row: FrameRow) -> String {
        row.items.first { FrameRow.isPluginOwner($0.owner) }?.owner ?? "a"
    }

    /// Owner, each file (`Shared` when several shown CLIs read it, with who), Added.
    static func facts(_ row: EquipListRow, clis: [CoreRegistryCLI], now: Date) -> [EquipFact] {
        var facts: [EquipFact] = []
        let owner = row.row.isProject ? "Project \(EquipToggles.projectName(row.row) ?? "")"
            : row.row.isPlugin ? "\(pluginName(row.row)) plugin" : "You"
        facts.append(EquipFact(key: "Owner", value: owner))
        let shown = clis.filter { $0.supports.supports(row.row.kind) }.map(\.id)
        var seen: Set<String> = []
        for item in row.row.items {
            let path = (item.path as NSString).abbreviatingWithTildeInPath
            guard seen.insert(path).inserted else { continue }
            let readBy = row.readers.readers?.members.first { $0.id == item.id }?.readBy.filter(shown.contains) ?? []
            let shared = readBy.count > 1
            facts.append(EquipFact(key: shared ? "Shared" : "File", value: path, isPath: true,
                                   note: shared ? "read by \(CLINames.sentence(row.readers.names(readBy)))" : nil))
        }
        if let seenAt = row.row.firstSeen {
            let added = DayWording.added(secondsAgo: now.timeIntervalSince(seenAt))
            facts.append(EquipFact(key: "Added", value: added.hasPrefix("added ") ? String(added.dropFirst("added ".count)) : added))
        }
        return facts
    }
}
