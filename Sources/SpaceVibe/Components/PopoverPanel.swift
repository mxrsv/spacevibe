import SwiftUI

/// The surface of an in-content popover (DS-R10 "popover"; the mock's `.tpop`, `.lgp`), beside v5's `PopoverSurface`: 300
/// wide unless the content asks less, padding 12, parts 10 apart, graphite with the float shadow in Solid (DS-R8). Esc closes
/// it (`close`); the caller anchors it with `anchoredOverlay(isPresented:id:placement: .popover, onOutsideTap:)` so an outside
/// click closes it too, and gives the focus back to the control that opened it.
struct PopoverPanel<Content: View>: View {
    var width: CGFloat? = BlockRole.popoverWidth
    var label: String
    var look: MaterialLook = .solid
    let close: () -> Void
    @ViewBuilder var content: Content

    init(label: String, width: CGFloat? = BlockRole.popoverWidth, look: MaterialLook = .solid, close: @escaping () -> Void,
         @ViewBuilder content: () -> Content) {
        self.label = label
        self.width = width
        self.look = look
        self.close = close
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SpaceRole.step10) { content }
            .padding(SpaceRole.step12)
            .frame(width: width, alignment: .leading)
            .fixedSize(horizontal: width == nil, vertical: true)
            .overlayPanelSurface(look: look)
            .onExitCommand(perform: close)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(label)
    }
}

/// The legend of the CLI logos (the mock's `tglHead`): the table head's "CLIs" button opens it on click, not only on hover. One
/// line per CLI (logo and name), then what the two marks mean.
struct CLILegend: View {
    let clis: [CLIIdentity]
    let close: () -> Void

    var body: some View {
        PopoverPanel(label: "Which logo is which", width: nil, close: close) {
            VStack(alignment: .leading, spacing: SpaceRole.step6) {
                ForEach(clis) { cli in
                    HStack(spacing: SpaceRole.step8) {
                        CLILogo(cli, size: SizeRole.logo16)
                        Text(cli.name).foregroundStyle(ColorRole.ink)
                    }
                }
                line(.link, "via another CLI’s folder")
                line(.question, "Unmeasurable")
            }
            .typeRole(.quiet)
        }
    }

    private func line(_ icon: FrameIcon, _ text: String) -> some View {
        HStack(spacing: SpaceRole.step8) {
            FrameGlyph(icon, side: SizeRole.icon12, ink: ColorRole.ink3).frame(width: SizeRole.logo16)
            Text(text).foregroundStyle(ColorRole.ink3)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The head of the CLIs column: "CLIs" and the info glyph, a button that opens `CLILegend`.
struct CLILegendButton: View {
    let isOpen: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: SpaceRole.step4) {
                Text("CLIs")
                FrameGlyph(.info, side: SizeRole.icon12)
            }
        }
        .buttonStyle(PushButtonStyle(.quiet, size: .small, isActive: isOpen))
        .focusEffectDisabled()
        .accessibilityLabel("CLIs")
        .accessibilityHint("Shows which logo is which")
    }
}
