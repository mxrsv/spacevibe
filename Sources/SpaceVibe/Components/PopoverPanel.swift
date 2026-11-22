import SwiftUI

/// The surface of an in-content popover (DS-R10 "popover"; the mock's `.tpop`, `.lgp`), beside v5's `PopoverSurface`: 300
/// wide unless the content asks less, padding 12, parts 10 apart, graphite with the float shadow in Solid (DS-R8). Esc closes
/// it (`close`); the caller anchors it with `anchoredOverlay(isPresented:id:placement: .popover, onOutsideTap:)` so an outside
/// click closes it too, and gives the focus back to the control that opened it.
struct PopoverPanel<Content: View>: View {
    var width: CGFloat? = BlockRole.popoverWidth
    var label: String
    let close: () -> Void
    @ViewBuilder var content: Content

    init(label: String, width: CGFloat? = BlockRole.popoverWidth, close: @escaping () -> Void,
         @ViewBuilder content: () -> Content) {
        self.label = label
        self.width = width
        self.close = close
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SpaceRole.step10) { content }
            .padding(SpaceRole.step12)
            .frame(width: width, alignment: .leading)
            .fixedSize(horizontal: width == nil, vertical: true)
            .overlayPanelSurface()
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

/// The head of the CLIs column: "CLIs" and the info glyph, a button that opens `CLILegend` (the mock's `.lgb`): the head's
/// own text, no padding and no fill, never cut. It keeps its full width even in a one-CLI 28 pt column and runs on into the
/// column gap, as the mock's `white-space: nowrap` does, so the head never reads "C…".
struct CLILegendButton: View {
    let isOpen: Bool
    let toggle: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: SpaceRole.step4) {
                Text(Self.title)
                FrameGlyph(.info, side: SizeRole.icon12)
            }
        }
        .buttonStyle(CLILegendButtonStyle(isOpen: isOpen, isFocused: focused))
        .focused($focused)
        .focusEffectDisabled()
        .fixedSize()
        .accessibilityLabel(Self.title)
        .accessibilityHint("Shows which logo is which")
    }

    static let title = "CLIs"
}

private struct CLILegendButtonStyle: ButtonStyle {
    let isOpen: Bool
    let isFocused: Bool

    func makeBody(configuration: Configuration) -> some View { Face(configuration: configuration, isOpen: isOpen, isFocused: isFocused) }

    private struct Face: View {
        let configuration: ButtonStyle.Configuration
        let isOpen: Bool
        let isFocused: Bool
        @Environment(\.specimenInteraction) private var specimen
        @State private var hovering = false

        var body: some View {
            let lifted = isOpen || hovering || configuration.isPressed || specimen.contains(.hover)
            configuration.label
                .typeRole(.quiet)
                .lineLimit(1)
                .foregroundStyle(lifted ? ColorRole.ink : ColorRole.ink3)
                .frame(minHeight: SizeRole.minimumHitTarget)
                .contentShape(Rectangle())
                .focusBar(FocusBarRule.isShown(ownFocus: isFocused, specimen: specimen.contains(.focus)))
                .pointerCursor()
                .onHover { hovering = $0 }
        }
    }
}
