import SwiftUI

/// The page's one answer (DS-R10 "Hero"; RD-R2, RD10; the mock's `.hero`): the figure at `hero` 40/44 in SF Pro Rounded and
/// `ink` (big figures are never tinted), an optional unit beside it at `pageTitle` in `ink3`, and the quiet label under it.
/// It is the largest and brightest text on the page (FE-T3). One line each, never wrapping, so the layout never shifts.
struct PageHero: View {
    enum Figure: Hashable, Sendable {
        /// A number already worded by `NumberWording`, with its unit ("780" "MB", "38" "% left").
        case value(String, unit: String?)
        /// Nothing left to do: the ok check at 40 and the page's word for it ("Clear", "Tidy").
        case clear(String)
        /// The first scan is still running: an ellipsis, never a made-up zero.
        case scanning
        /// The page cannot know its figure: `?`, with the label saying Unmeasurable.
        case unmeasurable
    }

    let figure: Figure
    let label: String

    init(_ figure: Figure, label: String) {
        self.figure = figure
        self.label = label
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SpaceRole.step2) {
            figureLine
                .lineLimit(1)
                .fixedSize(horizontal: false, vertical: true)
            Text(label)
                .typeRole(.quiet)
                .foregroundStyle(ColorRole.ink3)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.spoken(figure, label: label))
        .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private var figureLine: some View {
        switch figure {
        case .value(let value, let unit):
            HStack(alignment: .firstTextBaseline, spacing: SpaceRole.step6) {
                Text(verbatim: value).typeRole(.hero).foregroundStyle(ColorRole.ink)
                if let unit {
                    // The mock sets the unit at 15/20 400; TypeRole has 15 only at 500 (`pageTitle`), so it takes that (reported).
                    Text(verbatim: unit).typeRole(.pageTitle).foregroundStyle(ColorRole.ink3)
                }
            }
        case .clear(let word):
            HStack(spacing: SpaceRole.step12) {
                FrameGlyph(.checkCircleFill, side: SizeRole.icon40, ink: ColorRole.stateOk)
                Text(word).typeRole(.hero).foregroundStyle(ColorRole.ink)
            }
        case .scanning:
            Text(verbatim: "…").typeRole(.hero).foregroundStyle(ColorRole.ink)
        case .unmeasurable:
            Text(verbatim: "?").typeRole(.hero).foregroundStyle(ColorRole.ink)
        }
    }

    /// One sentence for VoiceOver: "780 MB, can be cleaned"; "Clear, nothing needs you"; "Scanning, never ran".
    static func spoken(_ figure: Figure, label: String) -> String {
        switch figure {
        case .value(let value, let unit): "\(value)\(unit.map { " \($0)" } ?? ""), \(label)"
        case .clear(let word): "\(word), \(label)"
        case .scanning: "Scanning, \(label)"
        case .unmeasurable: "Unmeasurable, \(label)"
        }
    }
}
