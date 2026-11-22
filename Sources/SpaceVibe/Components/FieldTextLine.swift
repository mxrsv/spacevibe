import SwiftUI

/// The editable line inside `SearchField` and `TextInputField`: a plain `TextField` in the role, or, in a headless shot, the
/// same line drawn as text (the value in `ink`, the placeholder in `controlQuietInk`). `ImageRenderer` cannot draw an AppKit
/// text field and paints a placeholder sign instead, so without this the gallery would not show the fields at all.
struct FieldTextLine: View {
    let placeholder: String
    @Binding var text: String
    let role: TypeRole

    @Environment(\.isShotRendering) private var isShotRendering

    var body: some View {
        if isShotRendering {
            Text(text.isEmpty ? placeholder : text)
                .typeRole(role)
                .foregroundStyle(text.isEmpty ? ColorRole.controlQuietInk : ColorRole.ink)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .typeRole(role)
                .foregroundStyle(ColorRole.ink)
        }
    }
}
