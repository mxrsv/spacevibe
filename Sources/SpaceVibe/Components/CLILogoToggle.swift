import SwiftUI

/// One CLI's logo in a Skill or Subagent row (DS-R10 "CLI logo toggle"; RD-R11; the mock's `.tgl`), beside v5's `LogoToggle`:
/// the 20 pt logo in a 28 pt cell, every state of `CLIToggleState` drawn. A lit logo is the full logo (RD22: no badge on
/// it); Never ran adds the amber dot on the owning CLI only; off is dim; pending shows the pending ring in the logo's place; Not supported is a dash with no button; a plugin's
/// item carries a lock, a "via" logo a link, an unreadable CLI a `?`; the last copy is the plain lit logo and is not a toggle
/// (D53 decides only that; no mark under it). Only a toggle takes hover, press, the pointing hand and the keyboard; the rest are images with their state read out.
/// While its write runs (`isPending`) the logo dims under the pending mark and a second press does nothing (FE-P: pending at
/// the control that started it). A focused toggle also takes A (RD39, D69).
struct CLILogoToggle: View {
    let state: CLIToggleState
    var isPending = false
    let toggle: () -> Void
    /// The button's own keyboard focus (RD29, `FocusBarRule`).
    @FocusState private var focused: Bool

    init(_ state: CLIToggleState, isPending: Bool = false, toggle: @escaping () -> Void) {
        self.state = state
        self.isPending = isPending
        self.toggle = toggle
    }

    var body: some View {
        if state.isToggle {
            Button { press() } label: { CLIToggleFace(state: state, hovered: false) }
                .buttonStyle(CLIToggleStyle(state: state, isPending: isPending, isFocused: focused))
                .focused($focused)
                .focusEffectDisabled()
                .help(isPending ? CLIToggleState.pendingTooltip : state.tooltip)
                .accessibilityLabel(state.cli.name)
                .accessibilityValue(isPending ? CLIToggleState.pendingSpoken : state.spokenState)
                .accessibilityAddTraits(isPending ? [.isToggle, .updatesFrequently] : .isToggle)
                .onKeyPress(keys: [KeyEquivalent("a")]) { press in
                    guard press.modifiers.isDisjoint(with: [.command, .control, .option]) else { return .ignored }
                    self.press()
                    return .handled
                }
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

    /// A press while the write runs is ignored, visibly: the toggle stays pending and nothing is sent twice.
    private func press() {
        if CLIToggleState.acceptsPress(isPending: isPending) { toggle() }
    }
}

private struct CLIToggleStyle: ButtonStyle {
    let state: CLIToggleState
    let isPending: Bool
    let isFocused: Bool

    func makeBody(configuration: Configuration) -> some View {
        StyledFace(configuration: configuration, state: state, isPending: isPending, isFocused: isFocused)
    }

    private struct StyledFace: View {
        let configuration: ButtonStyle.Configuration
        let state: CLIToggleState
        let isPending: Bool
        let isFocused: Bool
        @Environment(\.specimenInteraction) private var specimen
        @State private var hovering = false

        var body: some View {
            let pending = isPending
            let hovered = !pending && (hovering || specimen.contains(.hover))
            let pressed = !pending && (configuration.isPressed || specimen.contains(.press))
            let shape = RoundedRectangle(cornerRadius: RadiusRole.step8, style: .continuous)
            // Pending has its own look (RD49): the logo gives way to the pending ring in its place, nothing fades.
            CLIToggleFace(state: state, hovered: hovered, isPending: pending)
                .frame(width: SizeRole.hitCell, height: SizeRole.hitCell)
                .background(shape.fill(pressed ? ColorRole.selectionFill : hovered ? ColorRole.hoverFill : .clear))
                .contentShape(shape)
                .focusBar(FocusBarRule.isShown(ownFocus: isFocused, specimen: specimen.contains(.focus)), edge: .radius(RadiusRole.step8))
                .pointerCursor()
                .onHover { hovering = $0 }
        }
    }
}

/// The logo and its marks, without the cell's ground.
private struct CLIToggleFace: View {
    let state: CLIToggleState
    let hovered: Bool
    var isPending = false

    var body: some View {
        ZStack {
            if isPending {
                PendingMark()
            } else if state.drawsLogo {
                CLILogo(state.cli, size: SizeRole.logo20)
                    .opacity(state.fade.opacity(hovered: hovered))
            } else {
                // The mock's `.dash`: a short `faint` line for Not supported, at the Not supported opacity (RD49), so the
                // column stays aligned.
                Capsule()
                    .fill(ColorRole.faint)
                    .frame(width: SpaceRole.step8, height: BlockRole.notSupportedDash)
                    .opacity(OpacityRole.ghost)
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
}

/// A row's logo toggles (RD-R11): one 28 pt cell per CLI in the fixed CLI order, the same slot on every row, wrapping at 5 per
/// line (a second line from the 6th CLI; the row is then `tableWrapped`).
struct CLIToggleStrip: View {
    let states: [CLIToggleState]
    /// The CLIs whose write runs now.
    var pending: Set<String> = []
    let toggle: (CLIToggleState) -> Void

    init(states: [CLIToggleState], pending: Set<String> = [], toggle: @escaping (CLIToggleState) -> Void) {
        self.states = states
        self.pending = pending
        self.toggle = toggle
    }

    var body: some View {
        let lines = Self.lines(states.count)
        VStack(alignment: .leading, spacing: 0) {
            ForEach(0 ..< lines.count, id: \.self) { line in
                HStack(spacing: 0) {
                    ForEach(lines[line], id: \.self) { index in
                        CLILogoToggle(states[index], isPending: pending.contains(states[index].cli.id)) { toggle(states[index]) }
                    }
                }
            }
        }
        .frame(width: Self.width(states.count), alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("CLIs")
    }

    /// Cells per line: the CLI count up to 5.
    static func columns(_ count: Int) -> Int { max(1, min(count, BlockRole.togglesPerLine)) }

    /// The strip's width for `count` CLIs: one hit cell per column, so a table head above it lines up.
    static func width(_ count: Int) -> CGFloat { SizeRole.hitCell * CGFloat(columns(count)) }

    /// The indexes on each line.
    static func lines(_ count: Int) -> [[Int]] {
        let perLine = columns(count)
        return stride(from: 0, to: count, by: perLine).map { Array($0 ..< min($0 + perLine, count)) }
    }

    /// The row height the strip needs: a table row, or the wrapped one from the 6th CLI.
    static func rowHeight(_ count: Int) -> ItemRowHeight { lines(count).count > 1 ? .tableWrapped : .table }
}
