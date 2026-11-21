import SwiftUI

/// The band at the top of a page's content for a state that is not an empty list (DS-R10 "scanning, error"; RD-R13; the mock's
/// `.ban`), on the group surface at the group corner. Two kinds, one layout, so switching between them never moves the page
/// (FE-L1):
///
/// - `scanning`: the clockwise arrow, what is being read, and a 3 pt progress bar that carries its label and value for
///   VoiceOver (RD-R16). Pending sits at the control that started the work; this is the page-wide first scan.
/// - `problem`: the severity glyph in its colour (RD-R16: glyph and colour, never grey), a `bodyMedium` title ("Unmeasurable",
///   "Codex folder could not be read"), a quiet sentence that says what reads as Unmeasurable instead of zero, and one action
///   (`Try Again`).
struct StatusBanner<Action: View>: View {
    enum Kind: Hashable {
        /// `progress` 0 to 1, nil while the total is unknown (the bar then stays empty and says so).
        case scanning(progress: Double?)
        case problem(GroupSeverity)
    }

    let kind: Kind
    let title: String
    var detail: String?
    var look: MaterialLook = .solid
    @ViewBuilder var action: Action

    init(_ kind: Kind, title: String, detail: String? = nil, look: MaterialLook = .solid, @ViewBuilder action: () -> Action) {
        self.kind = kind
        self.title = title
        self.detail = detail
        self.look = look
        self.action = action()
    }

    var body: some View {
        HStack(spacing: SpaceRole.step12) {
            lead
            VStack(alignment: .leading, spacing: kind.isScanning ? SpaceRole.step6 : 0) {
                Text(title)
                    .typeRole(.bodyMedium)
                    .foregroundStyle(ColorRole.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail {
                    Text(detail)
                        .typeRole(.quiet)
                        .foregroundStyle(ColorRole.ink3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if case .scanning(let progress) = kind {
                    ShareMeter(share: progress ?? 0, height: .progress, label: title)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            action
        }
        .padding(.vertical, SpaceRole.step12)
        .padding(.horizontal, SpaceRole.step16)
        .background(PushButtonShape(corner: RadiusRole.groupCorner(look)).fill(ColorRole.groupSurface))
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var lead: some View {
        switch kind {
        case .scanning:
            FrameGlyph(.arrowClockwise, side: SizeRole.icon20, ink: ColorRole.ink3)
        case .problem(let severity):
            FrameGlyph(severity.icon ?? .infoFill, side: SizeRole.icon20, ink: severity.ink, label: severity.spoken)
        }
    }
}

extension StatusBanner.Kind {
    var isScanning: Bool { if case .scanning = self { true } else { false } }
}

extension StatusBanner where Action == EmptyView {
    init(_ kind: Kind, title: String, detail: String? = nil, look: MaterialLook = .solid) {
        self.init(kind, title: title, detail: detail, look: look) { EmptyView() }
    }
}
