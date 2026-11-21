import SwiftUI

/// The parts an inspector is built from in the new frame (DS-R10 "Inspector"; the mock's `.in h2`, `.in .q`, `.kv`, `.sec h5`,
/// `.cmd`, `.in .bt`), so every page's inspector reads the same: a title with its lead, the facts as a key-value list,
/// sections with a quiet head, commands in mono, and the actions as one column of full-width buttons.

/// The inspector's title (`.in h2`): a lead (a CLI logo, a kind icon) beside the name at `pageTitle`, wrapping rather than
/// cutting, and an optional quiet line under it.
struct InspectorTitle<Lead: View>: View {
    let title: String
    var sub: String?
    var isMono = false
    @ViewBuilder var lead: Lead

    init(_ title: String, sub: String? = nil, isMono: Bool = false, @ViewBuilder lead: () -> Lead) {
        self.title = title
        self.sub = sub
        self.isMono = isMono
        self.lead = lead()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SpaceRole.step4) {
            HStack(alignment: .center, spacing: SpaceRole.step8) {
                lead
                Text(verbatim: title)
                    .typeRole(isMono ? .mono : .pageTitle)
                    .foregroundStyle(ColorRole.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
            if let sub {
                InspectorNote(sub)
            }
        }
    }
}

/// A quiet line in an inspector (`.in .q`): `quiet` `ink3`, wrapping, with an optional leading icon.
struct InspectorNote: View {
    let text: String
    var icon: FrameIcon?
    /// A state glyph keeps its state colour (FE-C3, RD-R16): `stateAttention` for a warning note.
    var iconInk: Color = ColorRole.ink3

    init(_ text: String, icon: FrameIcon? = nil, iconInk: Color = ColorRole.ink3) {
        self.text = text
        self.icon = icon
        self.iconInk = iconInk
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: SpaceRole.step6) {
            if let icon { FrameGlyph(icon, side: SizeRole.icon12, ink: iconInk) }
            Text(text)
                .typeRole(.quiet)
                .foregroundStyle(ColorRole.ink3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

/// One fact of an inspector's key-value list.
struct InspectorFact: Hashable, Identifiable, Sendable {
    let key: String
    let value: String

    var id: String { key }
}

/// The facts (`.kv`): keys in an 84 column in `ink3`, values in `ink` that wrap anywhere, both `quiet`. VoiceOver reads each
/// pair as one line ("Project, payments-web").
struct KeyValueList: View {
    let facts: [InspectorFact]

    /// The key column (`grid-template-columns: 84px …`).
    static let keyWidth: CGFloat = 84

    var body: some View {
        VStack(alignment: .leading, spacing: SpaceRole.step6) {
            ForEach(facts) { fact in
                HStack(alignment: .firstTextBaseline, spacing: SpaceRole.step8) {
                    Text(fact.key)
                        .foregroundStyle(ColorRole.ink3)
                        .frame(width: Self.keyWidth, alignment: .leading)
                    Text(verbatim: fact.value)
                        .foregroundStyle(ColorRole.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .typeRole(.quiet)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(fact.key), \(fact.value)")
            }
        }
    }
}

/// A section of an inspector (`.sec`): a `quietMedium` `ink3` head, then its content.
struct InspectorSection<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SpaceRole.step8) {
            Text(title)
                .typeRole(.quietMedium)
                .foregroundStyle(ColorRole.ink3)
                .accessibilityAddTraits(.isHeader)
            content
        }
    }
}

/// A command or a path shown whole (`.cmd`): mono on the zebra step with a hairline edge, wrapping anywhere and keeping its
/// own line breaks, selectable so it can be copied by hand.
struct CommandBlock: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: RadiusRole.step8, style: .continuous)
        Text(verbatim: text)
            .typeRole(.mono)
            .foregroundStyle(ColorRole.ink)
            .fixedSize(horizontal: false, vertical: true)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, SpaceRole.step8)
            .padding(.horizontal, SpaceRole.step10)
            .background(shape.fill(ColorRole.zebraFill))
            .overlay(shape.strokeBorder(ColorRole.hairline, lineWidth: 1))
    }
}

/// One button of an inspector's action column.
struct InspectorAction: Identifiable {
    let id: String
    let title: String
    var icon: FrameIcon?
    var isEnabled = true
    /// The quiet variant (Dismiss): no ground until hovered.
    var isQuiet = false
    var isLoading = false
    /// The red tint for an undoable removal (Remove…), never a solid fill (RD-R9).
    var isDestructive = false
    let perform: @MainActor () -> Void

    var kind: PushButtonStyle.Kind { isDestructive ? .destructive : isQuiet ? .quiet : .control }
}

/// The inspector's actions (`.in .bt`): one column of full-width small-height buttons, label leading, in the order given.
/// A disabled one keeps its place and says why in its title ("Terminal app not found").
struct InspectorActions: View {
    let actions: [InspectorAction]

    var body: some View {
        VStack(alignment: .leading, spacing: SpaceRole.step6) {
            ForEach(actions) { action in
                Button { action.perform() } label: {
                    PushButtonLabel(action.title, icon: action.icon, size: .small)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(PushButtonStyle(action.kind, size: .small, isLoading: action.isLoading))
                .focusEffectDisabled()
                .disabled(!action.isEnabled)
                .help(action.title)
            }
        }
    }
}
