import SwiftUI

/// The new frame's one-line text input (DS-R10 "Field"), beside v5's fields: a regular 32 field on the control fill with a
/// hairline edge, the text in `bodyText` or `mono`, the placeholder in `ink3`. Keyboard focus is the RD29 bar on text
/// inputs too, never a ring (RD-R9, D57). A refused value turns the edge to the critical ink and puts the sentence under
/// the field (`message`), where the user typed, and VoiceOver reads it as the field's hint.
struct TextInputField: View {
    let placeholder: String
    @Binding var text: String
    /// What the field is for, for VoiceOver ("Rule").
    let label: String
    var isMono = false
    /// The refusal under the field; nil when the value is fine so far.
    var message: String?
    var submit: () -> Void = {}

    @FocusState private var focused: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: RadiusRole.step6, style: .continuous)
        VStack(alignment: .leading, spacing: SpaceRole.step6) {
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .typeRole(isMono ? .mono : .bodyText)
                .foregroundStyle(ColorRole.ink)
                .focused($focused)
                .focusEffectDisabled()
                .onSubmit(submit)
                .padding(.horizontal, SpaceRole.step10)
                .frame(height: SizeRole.controlRegular)
                .background(shape.fill(ColorRole.controlFill))
                .overlay(shape.strokeBorder(message == nil ? ColorRole.hairline : ColorRole.criticalInk, lineWidth: 1))
                .focusBar(FocusBarRule.isShown(ownFocus: focused), edge: .radius(RadiusRole.step6))
                .accessibilityLabel(label)
                .accessibilityHint(Self.hint(message))
            if let message {
                HStack(alignment: .firstTextBaseline, spacing: SpaceRole.step6) {
                    FrameGlyph(.xCircleFill, side: SizeRole.icon12, ink: ColorRole.stateCritical, label: "Refused")
                    Text(message)
                        .typeRole(.quiet)
                        .foregroundStyle(ColorRole.criticalInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    /// The refusal when there is one, so VoiceOver reads why the value was not taken; empty otherwise.
    static func hint(_ message: String?) -> String { message.map { "Not taken: \($0)" } ?? "" }
}
