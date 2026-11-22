import SwiftUI

/// How bad the worst row of a group is. Shown once, at the group head, as a glyph and its colour, never as a dot alone
/// (RD10, RD-R16): `x-circle-fill` in the critical ink, `warning-fill` in the attention ink, nothing for none.
enum GroupSeverity: Hashable, Sendable {
    case critical, attention, none

    var icon: FrameIcon? {
        switch self {
        case .critical: .xCircleFill
        case .attention: .warningFill
        case .none: nil
        }
    }

    /// The glyph's accessible name, read before the group's title.
    var spoken: String? {
        switch self {
        case .critical: "Critical"
        case .attention: "Needs attention"
        case .none: nil
        }
    }

    var ink: Color {
        switch self {
        case .critical: ColorRole.stateCritical
        case .attention: ColorRole.stateAttention
        case .none: ColorRole.ink3
        }
    }
}

/// The head of a group of rows (DS-R10 "Group head"; the mock's `.gh`): the severity glyph once, the title in `bodyMedium`
/// `ink2`, the count in `ink3`, and one small action at the trailing end, usually `Select N Suggested` as a link-coloured
/// quiet button (RD41: nothing is pre-selected; the head offers the pick). The head is a heading for VoiceOver ("Critical,
/// Clean up, 6").
struct GroupHead<Action: View>: View {
    let title: String
    var count: Int?
    var severity: GroupSeverity = .none
    /// A group of one CLI's rows (Activity, RD-R10) leads with that CLI's logo.
    var cli: CLIIdentity?
    @ViewBuilder var action: Action

    init(_ title: String, count: Int? = nil, severity: GroupSeverity = .none, cli: CLIIdentity? = nil,
         @ViewBuilder action: () -> Action) {
        self.title = title
        self.count = count
        self.severity = severity
        self.cli = cli
        self.action = action()
    }

    var body: some View {
        HStack(spacing: SpaceRole.step8) {
            HStack(spacing: SpaceRole.step8) {
                if let icon = severity.icon {
                    FrameGlyph(icon, side: SizeRole.icon14, ink: severity.ink)
                }
                if let cli { CLILogo(cli, size: SizeRole.logo16) }
                Text(title)
                    .typeRole(.bodyMedium)
                    .foregroundStyle(ColorRole.ink2)
                    .lineLimit(1)
                if let count {
                    Text(verbatim: NumberWording.count(count))
                        .typeRole(.bodyText.figures)
                        .foregroundStyle(ColorRole.ink3)
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Self.spoken(title: title, count: count, severity: severity))
            .accessibilityAddTraits(.isHeader)
            Spacer(minLength: SpaceRole.step8)
            action
        }
        .padding(.top, SpaceRole.step16)
        .padding(.horizontal, SpaceRole.step8)
        .padding(.bottom, SpaceRole.step8)
    }

    static func spoken(title: String, count: Int?, severity: GroupSeverity) -> String {
        [severity.spoken, title, count.map(NumberWording.count)].compactMap { $0 }.joined(separator: ", ")
    }
}

extension GroupHead where Action == EmptyView {
    init(_ title: String, count: Int? = nil, severity: GroupSeverity = .none, cli: CLIIdentity? = nil) {
        self.init(title, count: count, severity: severity, cli: cli) { EmptyView() }
    }
}

/// The group head's pick (RD41): `Select N Suggested`, ticking the suggested rows only when pressed. A neutral small control
/// button (the mock's `.rb`), never a link.
struct SelectSuggestedButton: View {
    let count: Int
    let select: () -> Void

    var body: some View {
        Button(action: select) { Text(Self.title(count)) }
            .buttonStyle(PushButtonStyle(Self.kind, size: .small))
            .focusEffectDisabled()
            .disabled(count == 0)
    }

    static func title(_ count: Int) -> String { "Select \(NumberWording.count(count)) Suggested" }

    /// The mock's `.rb`: both picks of a group head take it.
    static let kind = PushButtonStyle.Kind.control
}

/// The same place once every suggested row is ticked: `Clear Selection`, the same neutral small button (the mock's `.rb`).
struct ClearSelectionButton: View {
    let clear: () -> Void

    var body: some View {
        Button(action: clear) { Text(Self.title) }
            .buttonStyle(PushButtonStyle(SelectSuggestedButton.kind, size: .small))
            .focusEffectDisabled()
    }

    static let title = "Clear Selection"
}
