import SwiftUI

/// The three-step permission dial of a Rules capability row and a rule's inspector (the mock's `.dial`): Allow, Ask and
/// Deny on a small track, the chosen step on the neutral selection fill in `quietMedium` `ink` (never the primary, RD-R9),
/// the others `quiet` `ink3`. No step is chosen while nothing is set. A `locked` dial (a Mixed capability cell, which the
/// engine refuses to write) shows one chosen step with the lock and the word instead of buttons. It is a radio group for
/// VoiceOver: each step reads its title and whether it is chosen. Keyboard focus is the RD29 bar, not a ring (D57).
struct PermissionDial: View {
    /// The chosen step; nil when no rule sets one.
    let selection: CoreVerdict?
    /// What the dial chooses, for VoiceOver ("Run commands", "Permission").
    let label: String
    /// The word a locked dial shows ("Mixed"); nil for a dial that can be pressed.
    var lockedWord: String?
    let pick: (CoreVerdict) -> Void

    init(selection: CoreVerdict?, label: String, lockedWord: String? = nil, pick: @escaping (CoreVerdict) -> Void) {
        self.selection = selection
        self.label = label
        self.lockedWord = lockedWord
        self.pick = pick
    }

    var body: some View {
        let track = RoundedRectangle(cornerRadius: RadiusRole.step8, style: .continuous)
        HStack(spacing: 0) {
            if let lockedWord {
                HStack(spacing: SpaceRole.step4) {
                    FrameGlyph(.lockSimple, side: SizeRole.icon12, ink: ColorRole.ink)
                    Text(lockedWord).typeRole(.quietMedium)
                }
                .foregroundStyle(ColorRole.ink)
                .padding(.horizontal, SpaceRole.step8)
                .frame(height: SizeRole.segmentSmall)
                .background(RoundedRectangle(cornerRadius: RadiusRole.step6, style: .continuous).fill(ColorRole.selectionFill))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(label), \(lockedWord), read only")
            } else {
                ForEach(CoreVerdict.allCases, id: \.self) { verdict in
                    Button { pick(verdict) } label: { Text(Self.title(verdict)) }
                        .buttonStyle(PermissionStepStyle(isChosen: verdict == selection))
                        .focusEffectDisabled()
                        .accessibilityLabel(Self.title(verdict))
                        .accessibilityAddTraits(verdict == selection ? [.isButton, .isSelected] : .isButton)
                }
            }
        }
        .padding(SizeRole.segmentedInset)
        .frame(height: SizeRole.segmentedSmall)
        .background(track.fill(ColorRole.controlFill))
        .fixedSize()
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }

    /// "Allow", "Ask", "Deny".
    static func title(_ verdict: CoreVerdict) -> String {
        switch verdict {
        case .allow: "Allow"
        case .ask: "Ask"
        case .deny: "Deny"
        }
    }

    /// What VoiceOver reads for the whole dial: "Run commands, Ask"; "Network, not set".
    static func spoken(label: String, selection: CoreVerdict?) -> String {
        "\(label), \(selection.map(title) ?? "not set")"
    }
}

private struct PermissionStepStyle: ButtonStyle {
    let isChosen: Bool

    func makeBody(configuration: Configuration) -> some View {
        StepBody(configuration: configuration, isChosen: isChosen)
    }

    private struct StepBody: View {
        let configuration: ButtonStyle.Configuration
        let isChosen: Bool
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.isFocused) private var isFocused
        @Environment(\.specimenInteraction) private var specimen
        @State private var hovering = false

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: RadiusRole.step6, style: .continuous)
            let hovered = isEnabled && (hovering || specimen.contains(.hover))
            configuration.label
                .typeRole(isChosen ? .quietMedium : .quiet)
                .lineLimit(1)
                .foregroundStyle(isChosen ? ColorRole.ink : ColorRole.ink3)
                .padding(.horizontal, SpaceRole.step8)
                .frame(height: SizeRole.segmentSmall)
                .background {
                    if isChosen || configuration.isPressed {
                        shape.fill(ColorRole.selectionFill)
                    } else if hovered {
                        shape.fill(ColorRole.hoverFill)
                    }
                }
                .contentShape(shape)
                .opacity(isEnabled ? 1 : OpacityRole.disabled)
                .focusBar(isFocused || specimen.contains(.focus), inset: SpaceRole.step2)
                .pointerCursor()
                .onHover { hovering = $0 }
        }
    }
}

/// A short label on the control fill (the mock's `.chip`): an optional glyph in its own ink and a `quiet` `ink2` word, 20
/// high, never wrapping. Used where a row names a fact about itself ("Whole tool").
struct LabelChip: View {
    let text: String
    var icon: FrameIcon?
    var iconInk: Color = ColorRole.ink3

    init(_ text: String, icon: FrameIcon? = nil, iconInk: Color = ColorRole.ink3) {
        self.text = text
        self.icon = icon
        self.iconInk = iconInk
    }

    var body: some View {
        HStack(spacing: SpaceRole.step4) {
            if let icon { FrameGlyph(icon, side: SizeRole.icon12, ink: iconInk) }
            Text(text)
                .typeRole(.quiet)
                .foregroundStyle(ColorRole.ink2)
                .lineLimit(1)
        }
        .padding(.horizontal, SpaceRole.step6)
        .frame(height: SizeRole.controlMini)
        .background(RoundedRectangle(cornerRadius: RadiusRole.step6, style: .continuous).fill(ColorRole.controlFill))
        .fixedSize()
        .accessibilityElement(children: .combine)
    }
}
