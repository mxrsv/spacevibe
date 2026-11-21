import SwiftUI

/// The inspector's "CLIs" grid for a Skill or Subagent (DS-R10 "CLI tile"; RD15, RD-R12; the mock's `.tiles`): one 72 × 60
/// tile per CLI in the fixed order, at most 3 rows (`CLITileGridLayout`). The box around the logo is the information here
/// (its heat step), which the owner chose over FE-K4 for this block only (design notes §18).
///
/// A tile is the same toggle as the row's logo and takes the same `CLIToggleState`, so the two never disagree. On: the heat
/// fill, the logo, the short name, the session count and the green check on a group-coloured disc (RD15). Never ran adds the
/// amber dot at the top left on the owning CLI. Off: a dashed edge and "Add". Not supported: a flat zebra tile with a dash, no
/// button. A plugin's item: a lock instead of the check. Text takes the heat inks, so it reads 4.5:1 on every step, Increase
/// Contrast included (DS2). Hover lifts the tile 1 pt and pressing scales it; Reduce Motion drops both (DS-R9).
struct CLITileGrid: View {
    let states: [CLIToggleState]
    let toggle: (CLIToggleState) -> Void

    var body: some View {
        let steps = HeatStep.steps(states)
        VStack(alignment: .leading, spacing: SpaceRole.step8) {
            VStack(alignment: .leading, spacing: BlockRole.tileGap) {
                ForEach(Array(CLITileGridLayout.lines(states.count).enumerated()), id: \.offset) { _, line in
                    HStack(spacing: BlockRole.tileGap) {
                        ForEach(line, id: \.self) { index in
                            CLITile(state: states[index], step: steps[index]) { toggle(states[index]) }
                        }
                    }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("CLIs")
            CLITileLegend()
        }
    }
}

/// One tile.
struct CLITile: View {
    let state: CLIToggleState
    let step: HeatStep
    let toggle: () -> Void

    var body: some View {
        if state.isToggle {
            Button(action: toggle) { EmptyView() }
                .buttonStyle(CLITileStyle(state: state, step: step))
                .focusEffectDisabled()
                .help(state.tooltip)
                .accessibilityLabel(state.cli.name)
                .accessibilityValue(state.spokenState)
                .accessibilityAddTraits(.isToggle)
        } else {
            CLITileFace(state: state, step: step, hovered: false)
                .help(state.tooltip)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(state.cli.name)
                .accessibilityValue(state.spokenState)
                .accessibilityAddTraits(.isImage)
        }
    }
}

private struct CLITileStyle: ButtonStyle {
    let state: CLIToggleState
    let step: HeatStep

    func makeBody(configuration: Configuration) -> some View { Styled(configuration: configuration, state: state, step: step) }

    private struct Styled: View {
        let configuration: ButtonStyle.Configuration
        let state: CLIToggleState
        let step: HeatStep
        @Environment(\.isFocused) private var isFocused
        @Environment(\.specimenInteraction) private var specimen
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var hovering = false

        var body: some View {
            let hovered = hovering || specimen.contains(.hover)
            let pressed = configuration.isPressed || specimen.contains(.press)
            CLITileFace(state: state, step: step, hovered: hovered)
                .offset(y: hovered && !pressed ? -MotionRole.lift(reduceMotion: reduceMotion) : 0)
                .scaleEffect(MotionRole.scale(pressed: pressed, reduceMotion: reduceMotion))
                .animation(reduceMotion ? nil : .easeOut(duration: MotionRole.tileDuration), value: hovered)
                .focusBar(isFocused || specimen.contains(.focus), inset: SpaceRole.step4)
                .contentShape(RoundedRectangle(cornerRadius: RadiusRole.step10, style: .continuous))
                .pointerCursor()
                .onHover { hovering = $0 }
        }
    }
}

/// The tile without its button.
private struct CLITileFace: View {
    let state: CLIToggleState
    let step: HeatStep
    let hovered: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: RadiusRole.step10, style: .continuous)
        VStack(spacing: SpaceRole.step2) {
            CLILogo(state.cli, size: SizeRole.logo20)
                .opacity(state.isOn ? 1 : OpacityRole.ghost)
                .frame(height: SizeRole.logo20)
            Text(state.cli.shortName)
                .typeRole(.axisCaption)
                .foregroundStyle(nameInk)
                .lineLimit(1)
                .truncationMode(.tail)
            Text(verbatim: state.tileFigure)
                .typeRole(figureRole)
                .foregroundStyle(figureInk)
                .lineLimit(1)
        }
        .padding(.horizontal, SpaceRole.step2)
        .frame(width: BlockRole.tileWidth, height: BlockRole.tileHeight)
        .background { ground(shape) }
        .overlay {
            if hovered && state.isToggle { shape.fill(ColorRole.hoverFill) }
        }
        .overlay(alignment: .topLeading) {
            if state.showsNeverRanDot {
                Circle().fill(ColorRole.attentionBar)
                    .frame(width: BlockRole.neverRanDot, height: BlockRole.neverRanDot)
                    .padding(SpaceRole.step6)
            }
        }
        .overlay(alignment: .topTrailing) { corner }
        .overlay(alignment: .bottom) {
            if state.showsLastCopyBar {
                Capsule().fill(ColorRole.ink3)
                    .frame(height: BlockRole.lastCopyBar)
                    .padding(.horizontal, SpaceRole.step24)
                    .padding(.bottom, SpaceRole.step4)
            }
        }
    }

    @ViewBuilder
    private func ground(_ shape: RoundedRectangle) -> some View {
        switch state.presence {
        case .on: shape.fill(Self.heatFill(step))
        case .off:
            shape.strokeBorder(ColorRole.ink3.opacity(OpacityRole.dim), style: StrokeStyle(lineWidth: 1, dash: [SpaceRole.step4, SpaceRole.step2]))
        case .notSupported, .unreadable: shape.fill(ColorRole.zebraFill)
        }
    }

    @ViewBuilder
    private var corner: some View {
        if state.badge == .lock || state.badge == .link {
            FrameGlyph(state.badge == .lock ? .lockSimple : .link, side: SizeRole.icon12, ink: ColorRole.ink3)
                .padding(SpaceRole.step4)
        } else if state.showsCheck {
            FrameGlyph(.checkCircleFill, side: SizeRole.icon12, ink: ColorRole.stateOk, label: "Enabled")
                .frame(width: BlockRole.tileCheckDisc, height: BlockRole.tileCheckDisc)
                .background(Circle().fill(ColorRole.groupSurface))
                .padding(SpaceRole.step2)
        }
    }

    static func heatFill(_ step: HeatStep) -> Color {
        switch step {
        case .none: ColorRole.data1
        case .low: ColorRole.data2
        case .middle: ColorRole.data3
        case .high: ColorRole.data4
        }
    }

    private var isZero: Bool { state.presence == .on(.neverRan) || state.presence == .on(.sessions(0)) }

    private var figureRole: TypeRole {
        if case .on(.sessions(let n)) = state.presence, n > 0 { return .bodyMedium.figures }
        return state.presence == .off || isZero ? .axisCaption.figures : .bodyText.figures
    }

    private var nameInk: Color {
        guard state.isOn else { return ColorRole.ink3 }
        switch step {
        case .none: return ColorRole.dataSecondaryInk1
        case .low: return ColorRole.dataSecondaryInk2
        case .middle: return ColorRole.dataSecondaryInk3
        case .high: return ColorRole.dataSecondaryInk4
        }
    }

    private var figureInk: Color {
        guard state.isOn else { return ColorRole.ink3 }
        if isZero { return ColorRole.dataZeroInk }
        switch step {
        case .none: return ColorRole.dataInk1
        case .low: return ColorRole.dataInk2
        case .middle: return ColorRole.dataInk3
        case .high: return ColorRole.dataInk4
        }
    }
}

/// The line under the grid (the mock's `.tleg`): "Less", the four steps, "More".
struct CLITileLegend: View {
    var body: some View {
        HStack(spacing: SpaceRole.step4) {
            Text("Less")
            ForEach(HeatStep.allCases, id: \.self) { step in
                RoundedRectangle(cornerRadius: RadiusRole.step4, style: .continuous)
                    .fill(CLITileFace.heatFill(step))
                    .frame(width: BlockRole.legendSwatch, height: BlockRole.legendSwatch)
            }
            Text("More")
        }
        .typeRole(.axisCaption)
        .foregroundStyle(ColorRole.ink3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Fill shows sessions, from less to more")
    }
}
