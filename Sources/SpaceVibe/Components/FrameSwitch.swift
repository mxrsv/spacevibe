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
    static let trackWidth = BlockRole.switchTrackWidth
    static let trackHeight = BlockRole.switchTrackHeight
    static let knob = BlockRole.switchKnob

    let label: String
    let isOn: Bool
    let toggle: () -> Void

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                        .fill(Self.knobInk(isOn: isOn))
                        .frame(width: Self.knob, height: Self.knob)
                        .shadow(color: Self.knobShadow(isOn: isOn), radius: ShadowRole.switchKnobRadius, y: ShadowRole.switchKnobOffsetY)
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

    /// The knob's role: white on the primary; off, `switchKnobOff` (`ink` in dark, white in light). The theme is the
    /// colour role's, never a branch here.
    static func knobInk(isOn: Bool) -> Color { isOn ? ColorRole.switchKnobOn : ColorRole.switchKnobOff }

    /// Only the Off knob has a shadow role, and it is clear in dark: the white light knob needs it to stand off the `faint`
    /// track.
    static func knobShadow(isOn: Bool) -> Color { isOn ? .clear : ColorRole.switchKnobOffShadow }
}
