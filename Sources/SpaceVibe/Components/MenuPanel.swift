import SwiftUI

/// One line of a new-frame menu (the mock's `.cpi`): a check when chosen, an optional lead (a CLI logo or an icon), the
/// title cut in the middle, and a quiet trailing note ("6", "Read only", "Not supported", a path in mono). A disabled line is
/// shown dimmed and cannot be picked.
struct MenuPanelEntry: Hashable, Identifiable, Sendable {
    enum Lead: Hashable, Sendable {
        case none
        case cli(CLIIdentity)
        case icon(FrameIcon)
    }

    let id: String
    let title: String
    var lead: Lead = .none
    var note: String?
    var noteIsPath = false
    var isChosen = false
    var isEnabled = true

    /// What VoiceOver reads after the title.
    var spokenValue: String {
        [isChosen ? "selected" : nil, note].compactMap { $0 }.joined(separator: ", ")
    }
}

/// The keyboard of a menu: ↑ and ↓ move over enabled lines, wrapping; nothing highlighted starts at the chosen line, else the
/// first. Pure (`FrameBlocksTests`).
enum MenuPanelKeys {
    static func start(_ entries: [MenuPanelEntry]) -> String? {
        (entries.first { $0.isChosen && $0.isEnabled } ?? entries.first(where: \.isEnabled))?.id
    }

    static func step(from id: String?, by delta: Int, in entries: [MenuPanelEntry]) -> String? {
        let enabled = entries.filter(\.isEnabled)
        guard !enabled.isEmpty else { return nil }
        guard let id, let index = enabled.firstIndex(where: { $0.id == id }) else { return start(entries) }
        return enabled[(index + delta % enabled.count + enabled.count) % enabled.count].id
    }
}

/// A menu's surface and lines (DS-R10 "Menu"; RD-R10; the mock's `.cpop`), beside v5's `MenuSurface`: 252 wide, an optional
/// heading, the lines 28 high, an optional footnote. The pointer and ↑↓ move one highlight; Return or a click picks;
/// Esc closes (`close`), and the caller closes it on an outside click (`anchoredOverlay(… onOutsideTap:)`) and gives the
/// focus back to its button.
struct MenuPanel: View {
    var heading: String?
    let entries: [MenuPanelEntry]
    var footnote: String?
    var width: CGFloat = BlockRole.menuWidth
    let pick: (String) -> Void
    let close: () -> Void

    @State private var highlighted: String?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: SpaceRole.step2) {
            if let heading {
                Text(heading)
                    .typeRole(.quiet)
                    .foregroundStyle(ColorRole.ink3)
                    .padding(.horizontal, SpaceRole.step8)
                    .padding(.vertical, SpaceRole.step4)
                    .accessibilityAddTraits(.isHeader)
            }
            ForEach(entries) { entry in
                MenuPanelLine(entry: entry, isHighlighted: highlighted == entry.id, hover: { if $0, entry.isEnabled { highlighted = entry.id } }) {
                    if entry.isEnabled { pick(entry.id) }
                }
            }
            if let footnote {
                HStack(alignment: .top, spacing: SpaceRole.step6) {
                    FrameGlyph(.infoFill, side: SizeRole.icon12, ink: ColorRole.ink3)
                    Text(footnote).fixedSize(horizontal: false, vertical: true)
                }
                .typeRole(.axisCaption)
                .foregroundStyle(ColorRole.ink3)
                .padding(.horizontal, SpaceRole.step8)
                .padding(.top, SpaceRole.step8)
                .padding(.bottom, SpaceRole.step4)
            }
        }
        .padding(SpaceRole.step6)
        .frame(width: width, alignment: .leading)
        .overlayPanelSurface()
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .onAppear {
            highlighted = MenuPanelKeys.start(entries)
            focused = true
        }
        .onKeyPress(.downArrow) { highlighted = MenuPanelKeys.step(from: highlighted, by: 1, in: entries); return .handled }
        .onKeyPress(.upArrow) { highlighted = MenuPanelKeys.step(from: highlighted, by: -1, in: entries); return .handled }
        .onKeyPress(.return) {
            guard let highlighted, entries.contains(where: { $0.id == highlighted && $0.isEnabled }) else { return .ignored }
            pick(highlighted)
            return .handled
        }
        .onExitCommand(perform: close)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }
}

private struct MenuPanelLine: View {
    let entry: MenuPanelEntry
    let isHighlighted: Bool
    let hover: (Bool) -> Void
    let pick: () -> Void

    @Environment(\.specimenInteraction) private var specimen

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: RadiusRole.step8, style: .continuous)
        let lit = entry.isEnabled && (isHighlighted || specimen.contains(.hover))
        Button(action: pick) {
            HStack(spacing: SpaceRole.step8) {
                Group {
                    if entry.isChosen { FrameGlyph(.check, side: SizeRole.icon12, ink: ColorRole.ink) } else { Color.clear }
                }
                .frame(width: SizeRole.icon16)
                switch entry.lead {
                case .none: EmptyView()
                case .cli(let cli): CLILogo(cli, size: SizeRole.logo16)
                case .icon(let icon): FrameGlyph(icon, side: SizeRole.icon16, ink: ColorRole.ink2)
                }
                MiddleTruncatedText(entry.title)
                    .typeRole(.bodyText)
                    .foregroundStyle(ColorRole.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let note = entry.note {
                    Group {
                        if entry.noteIsPath { MiddleTruncatedText(note).typeRole(.mono) } else { Text(note).typeRole(.quiet).lineLimit(1) }
                    }
                    .foregroundStyle(ColorRole.ink3)
                    .frame(maxWidth: BlockRole.menuDetailMaxWidth, alignment: .trailing)
                    .fixedSize(horizontal: !entry.noteIsPath, vertical: false)
                }
            }
            .padding(.horizontal, SpaceRole.step8)
            .frame(height: SizeRole.hitCell)
            .background(shape.fill(lit ? ColorRole.hoverFill : .clear))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .pointerCursor()
        .disabled(!entry.isEnabled)
        .opacity(entry.isEnabled ? 1 : OpacityRole.disabled)
        .onHover(perform: hover)
        .accessibilityLabel(entry.title)
        .accessibilityValue(entry.spokenValue)
        .accessibilityAddTraits(entry.isChosen ? [.isSelected] : [])
    }
}
