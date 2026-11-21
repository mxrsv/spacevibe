import SwiftUI

/// One CLI's logo in a Skill or Subagent row (DS-R10 "CLI logo toggle"; RD-R11; the mock's `.tgl`), beside v5's `LogoToggle`:
/// the 20 pt logo in a 28 pt cell, every state of `CLIToggleState` drawn. A lit logo is the full logo (RD22: no badge on
/// it); Never ran adds the amber dot on the owning CLI only; off is dim; Not supported is a dash with no button; a plugin's
/// item carries a lock, a "via" logo a link, an unreadable CLI a `?`; the last copy has a bar under it and is not a toggle
/// (D53). Only a toggle takes hover, press, the pointing hand and the keyboard; the rest are images with their state read out.
struct CLILogoToggle: View {
    let state: CLIToggleState
    let toggle: () -> Void

    init(_ state: CLIToggleState, toggle: @escaping () -> Void) {
        self.state = state
        self.toggle = toggle
    }

    var body: some View {
        if state.isToggle {
            Button(action: toggle) { CLIToggleFace(state: state, hovered: false) }
                .buttonStyle(CLIToggleStyle(state: state))
                .focusEffectDisabled()
                .help(state.tooltip)
                .accessibilityLabel(state.cli.name)
                .accessibilityValue(state.spokenState)
                .accessibilityAddTraits(.isToggle)
        } else {
            CLIToggleFace(state: state, hovered: false)
                .frame(width: SizeRole.hitCell, height: SizeRole.hitCell)
                .help(state.tooltip)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(state.cli.name)
                .accessibilityValue(state.spokenState)
                .accessibilityAddTraits(.isImage)
        }
    }
}

private struct CLIToggleStyle: ButtonStyle {
    let state: CLIToggleState

    func makeBody(configuration: Configuration) -> some View { StyledFace(configuration: configuration, state: state) }

    private struct StyledFace: View {
        let configuration: ButtonStyle.Configuration
        let state: CLIToggleState
        @Environment(\.isFocused) private var isFocused
        @Environment(\.specimenInteraction) private var specimen
        @State private var hovering = false

        var body: some View {
            let hovered = hovering || specimen.contains(.hover)
            let pressed = configuration.isPressed || specimen.contains(.press)
            let shape = RoundedRectangle(cornerRadius: RadiusRole.step8, style: .continuous)
            CLIToggleFace(state: state, hovered: hovered)
                .frame(width: SizeRole.hitCell, height: SizeRole.hitCell)
                .background(shape.fill(pressed ? ColorRole.selectionFill : hovered ? ColorRole.hoverFill : .clear))
                .contentShape(shape)
                .focusBar(isFocused || specimen.contains(.focus), inset: SpaceRole.step2)
                .pointerCursor()
                .onHover { hovering = $0 }
        }
    }
}

/// The logo and its marks, without the cell's ground.
private struct CLIToggleFace: View {
    let state: CLIToggleState
    let hovered: Bool

    var body: some View {
        ZStack {
            if state.drawsLogo {
                CLILogo(state.cli, size: SizeRole.logo20)
                    .opacity(Self.opacity(state.fade, hovered: hovered))
            } else {
                // The mock's `.dash`: a short `faint` line at the disabled opacity, so the column stays aligned.
                Capsule()
                    .fill(ColorRole.faint)
                    .frame(width: SpaceRole.step8, height: BlockRole.lastCopyBar)
                    .opacity(OpacityRole.disabled)
            }
        }
        .frame(width: SizeRole.hitCell, height: SizeRole.hitCell)
        .overlay(alignment: .topTrailing) {
            if state.showsNeverRanDot {
                Circle().fill(ColorRole.attentionBar)
                    .frame(width: BlockRole.neverRanDot, height: BlockRole.neverRanDot)
                    .padding(SpaceRole.step2)
            }
        }
        .overlay(alignment: .bottomTrailing) { badge }
        .overlay(alignment: .bottom) {
            if state.showsLastCopyBar {
                Capsule().fill(ColorRole.ink3)
                    .frame(height: BlockRole.lastCopyBar)
                    .padding(.horizontal, SpaceRole.step8)
            }
        }
    }

    @ViewBuilder
    private var badge: some View {
        switch state.badge {
        case .lock: FrameGlyph(.lockSimple, side: BlockRole.toggleBadgeGlyph, ink: ColorRole.ink3)
        case .link: FrameGlyph(.link, side: BlockRole.toggleBadgeGlyph, ink: ColorRole.ink3)
        case .unknown:
            FrameGlyph(.question, side: BlockRole.toggleBadgeGlyph, ink: ColorRole.ink2)
                .frame(width: BlockRole.unknownDisc, height: BlockRole.unknownDisc)
                .background(Circle().fill(ColorRole.groupSurface))
        case nil: EmptyView()
        }
    }

    /// Off brightens to full on hover, as the press would make it.
    static func opacity(_ fade: CLIToggleState.Fade, hovered: Bool) -> Double {
        switch fade {
        case .none: 1
        case .dim: hovered ? 1 : OpacityRole.dim
        case .ghost: OpacityRole.ghost
        }
    }
}

/// A row's logo toggles (RD-R11): one 28 pt cell per CLI in the fixed CLI order, the same slot on every row, wrapping at 5 per
/// line (a second line from the 6th CLI; the row is then `tableWrapped`).
struct CLIToggleStrip: View {
    let states: [CLIToggleState]
    let toggle: (CLIToggleState) -> Void

    var body: some View {
        let lines = Self.lines(states.count)
        VStack(alignment: .leading, spacing: 0) {
            ForEach(0 ..< lines.count, id: \.self) { line in
                HStack(spacing: 0) {
                    ForEach(lines[line], id: \.self) { index in
                        CLILogoToggle(states[index]) { toggle(states[index]) }
                    }
                }
            }
        }
        .frame(width: SizeRole.hitCell * CGFloat(Self.columns(states.count)), alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("CLIs")
    }

    /// Cells per line: the CLI count up to 5.
    static func columns(_ count: Int) -> Int { max(1, min(count, BlockRole.togglesPerLine)) }

    /// The indexes on each line.
    static func lines(_ count: Int) -> [[Int]] {
        let perLine = columns(count)
        return stride(from: 0, to: count, by: perLine).map { Array($0 ..< min($0 + perLine, count)) }
    }

    /// The row height the strip needs: a table row, or the wrapped one from the 6th CLI.
    static func rowHeight(_ count: Int) -> ItemRowHeight { lines(count).count > 1 ? .tableWrapped : .table }
}
