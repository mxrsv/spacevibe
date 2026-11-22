import SwiftUI

/// The new frame's on/off switch (DS-R10 "Switch": on, off, disabled; the mock's `.swt`), beside v5's `SpaceVibeSwitch`:
/// a 34 x 20 track with a 16 pt knob. On is the primary fill with a white knob (RD-R9: switch on-states use the primary);
/// off is the `faint` track with an `ink` knob in dark and a white one in light (design-system "Inferred": the light Off
/// knob is white). Disabled keeps its state at the disabled opacity and takes no click. The knob slides in
/// `MotionRole.switchKnobDuration`, at once under Reduce Motion (DS-R9). The light Off knob carries the mock's small shadow, so
/// a disabled Off switch still shows its knob. Keyboard focus is the RD29 bar at the switch's own edge, for its own focus
/// only (`FocusBarRule`), never a ring (D57); the button takes focus as every macOS button does, under keyboard navigation.
///
/// The whole switch is the hit area; the row beside it carries the visible name, and `label` is what VoiceOver reads with
/// the switch's state.
struct FrameSwitch: View {
    static let trackWidth: CGFloat = 34
    static let trackHeight: CGFloat = 20
    static let knob: CGFloat = 16

    let label: String
    let isOn: Bool
    let toggle: () -> Void

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isFocused: Bool

    init(_ label: String, isOn: Bool, toggle: @escaping () -> Void) {
        self.label = label
        self.isOn = isOn
        self.toggle = toggle
    }

    var body: some View {
        Button(action: toggle) {
            Capsule()
                .fill(isOn ? ColorRole.primaryAction : ColorRole.faint)
                .frame(width: Self.trackWidth, height: Self.trackHeight)
                .overlay(alignment: isOn ? .trailing : .leading) {
                    Circle()
                        .fill(Self.knobInk(isOn: isOn, dark: colorScheme == .dark))
                        .frame(width: Self.knob, height: Self.knob)
                        .shadow(color: Self.knobHasShadow(isOn: isOn, dark: colorScheme == .dark) ? ColorRole.switchKnobShadow : .clear,
                                radius: ShadowRole.switchKnobRadius, y: ShadowRole.switchKnobOffsetY)
                        .padding(SpaceRole.step2)
                }
                .animation(reduceMotion ? nil : .easeOut(duration: MotionRole.switchKnobDuration), value: isOn)
                .contentShape(Capsule())
                .opacity(isEnabled ? 1 : OpacityRole.disabled)
        }
        .buttonStyle(.plain)
        .focused($isFocused)
        .focusEffectDisabled()
        .focusBar(FocusBarRule.isShown(ownFocus: isFocused), edge: .capsule)
        .pointerCursor()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(.isToggle)
    }

    /// White on the primary; off, `ink` in dark and white in light.
    static func knobInk(isOn: Bool, dark: Bool) -> Color {
        if isOn { return ColorRole.onPrimaryAction }
        return dark ? ColorRole.ink : ColorRole.onPrimaryAction
    }

    /// Only the white Off knob in light needs the shadow to stand off the `faint` track.
    static func knobHasShadow(isOn: Bool, dark: Bool) -> Bool { !isOn && !dark }
}
