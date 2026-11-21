import SwiftUI

/// One Clean row (the mock's `.tr` with `28px minmax(0,1fr) 190px 112px`): the checkbox, the name over its quiet line (a log
/// or cache row leads with its CLI's logo), the detail column (where the item is loaded, the lock, or the age control) and
/// the size, right-aligned. The detail and size columns keep fixed widths, so a long path or a lock never moves the rows
/// below (FE-L1). A row that cannot be ticked keeps its checkbox, disabled.
struct CleanRowView: View {
    let row: CleanRowModel
    let isTicked: Bool
    let isSelected: Bool
    let isKeyboardFocused: Bool
    let isMoving: Bool
    let openLock: String?
    let actions: CleanActions

    var body: some View {
        ItemRow(label: row.spoken, isSelected: isSelected, isKeyboardFocused: isKeyboardFocused, select: { actions.press(row) }) {
            HStack(spacing: SpaceRole.step12) {
                CheckboxCell(isTicked ? .on : .off, label: "Select \(row.title)") { actions.toggle(row) }
                    .disabled(!row.isOpen)
                name.frame(maxWidth: .infinity, alignment: .leading)
                detail.frame(width: TableColumnWidth.cleanDetail, alignment: .leading)
                size.frame(width: TableColumnWidth.cleanSize, alignment: .trailing)
            }
        }
        .accessibilityAction(named: isTicked ? "Untick" : "Tick") { actions.toggle(row) }
    }

    private var name: some View {
        HStack(spacing: SpaceRole.step8) {
            if let cli = row.cli {
                CLILogo(CLIIdentity(id: cli, name: actions.world.cliName(cli)), size: SizeRole.logo16)
            }
            VStack(alignment: .leading, spacing: 0) {
                MiddleTruncatedText(row.title)
                    .typeRole(row.isMono ? .mono : .bodyMedium)
                    .foregroundStyle(ColorRole.ink)
                if let sub = row.sub {
                    Text(sub)
                        .typeRole(.quiet)
                        .foregroundStyle(ColorRole.ink3)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .help(sub)
                }
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch row.detail {
        case .none:
            Color.clear.frame(height: SizeRole.hitCell)
        case .clis(let ids, let more):
            HStack(spacing: SpaceRole.step6) {
                ForEach(ids, id: \.self) { CLILogo(CLIIdentity(id: $0, name: actions.world.cliName($0)), size: SizeRole.logo16) }
                if more > 0 {
                    Text(verbatim: "+\(NumberWording.count(more))").typeRole(.quiet).foregroundStyle(ColorRole.ink3)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(CLINames.sentence(ids.map(actions.world.cliName)) + (more > 0 ? " and \(NumberWording.count(more)) more" : ""))
        case .lock(let note):
            CleanLockButton(note: note, isOpen: openLock == note.id, world: actions.world) { actions.state.toggleLock(note.id) }
        case .ages(let ages, let selected):
            FrameSegmentedControl(segments: ages.map { FrameSegment(id: String($0), title: "\($0)d") }, selection: String(selected),
                                  label: "Logs older than") { picked in
                if let days = Int(picked), let cli = row.cli { actions.setAge(days, cli: cli) }
            }
            .disabled(isMoving)
        }
    }

    @ViewBuilder
    private var size: some View {
        switch row.size {
        case .bytes(let text):
            Text(verbatim: text)
                .typeRole(.bodyMedium.figures)
                .foregroundStyle(ColorRole.ink)
                .lineLimit(1)
        case .note(let text):
            Text(text).typeRole(.quiet).foregroundStyle(ColorRole.ink2).lineLimit(1)
        case .quiet(let text):
            Text(text).typeRole(.quiet).foregroundStyle(ColorRole.ink3).lineLimit(1).truncationMode(.tail)
        case .pending:
            SkeletonLine(.short)
        }
    }
}

/// "In use by 2 sessions" with the lock glyph (the mock's `.lockrow`): a click opens the popover that names the sessions and
/// says why, not only a tooltip (the mock's `lockNote`). Esc and an outside click close it.
struct CleanLockButton: View {
    let note: CleanLockNote
    let isOpen: Bool
    let world: FrameWorld
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: SpaceRole.step8) {
                FrameGlyph(.lockSimple, side: SizeRole.icon12, ink: ColorRole.ink3)
                Text(note.title).typeRole(.quiet).foregroundStyle(ColorRole.ink3).lineLimit(1)
            }
        }
        .buttonStyle(PushButtonStyle(.quiet, size: .small))
        .focusEffectDisabled()
        .help(note.footnote)
        .accessibilityLabel("\(note.title). \(note.footnote)")
        .accessibilityAddTraits(isOpen ? .isSelected : [])
        .popover(isPresented: Binding(get: { isOpen }, set: { if !$0 && isOpen { toggle() } }), arrowEdge: .bottom) {
            PopoverPanel(label: note.sessions.isEmpty ? "Why these files are locked" : "Sessions using these files", close: toggle) {
                ForEach(note.sessions) { session in
                    HStack(spacing: SpaceRole.step8) {
                        CLILogo(CLIIdentity(id: session.cli, name: world.cliName(session.cli)), size: SizeRole.logo16)
                        MiddleTruncatedText(session.title)
                            .typeRole(.bodyText)
                            .foregroundStyle(ColorRole.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(verbatim: "pid \(session.pid)")
                            .typeRole(.mono)
                            .foregroundStyle(ColorRole.ink3)
                            .lineLimit(1)
                            .fixedSize()
                    }
                }
                Text(note.footnote)
                    .typeRole(.axisCaption)
                    .foregroundStyle(ColorRole.ink3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
