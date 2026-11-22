import SwiftUI

/// A Hook's Runs cell (DS-R10 "Runs"; the mock's `.rc`): a thin 4 pt bar scaled to the page's busiest Hook and the count after
/// it in `quietMedium` figures. Dead and Never ran read `0` at 400 in `ink3` on an empty track; a CLI that logs no Hook runs
/// reads `Unmeasurable` in words, never 0 (RD-R10); a cell still being counted reads `…`. The count cell keeps one width, so
/// `4.8M` and `0` end on the same line.
struct RunsCell: View {
    enum Value: Hashable, Sendable {
        /// `share` of the page's busiest Hook, 0 to 1.
        case count(Int, share: Double)
        /// Counted and zero: dead, or never ran.
        case zero
        case unmeasurable
        case pending
    }

    let value: Value

    init(_ value: Value) { self.value = value }

    var body: some View {
        HStack(spacing: SpaceRole.step6) {
            switch value {
            case .count(let runs, let share):
                ShareMeter(share: share, tone: .data)
                figure(NumberWording.compactCount(runs), role: .quietMedium, ink: ColorRole.ink)
                    .help(NumberWording.plural(runs, "run"))
            case .zero:
                ShareMeter(share: 0)
                figure(NumberWording.count(0), role: .quiet, ink: ColorRole.ink3)
            case .unmeasurable:
                Text("Unmeasurable")
                    .typeRole(.quiet)
                    .foregroundStyle(ColorRole.ink3)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            case .pending:
                ShareMeter(share: nil)
                figure("\u{2026}", role: .quiet, ink: ColorRole.ink3)
            }
        }
        .frame(width: TableColumnWidth.runs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Runs")
        .accessibilityValue(Self.spoken(value))
    }

    private func figure(_ text: String, role: TypeRole, ink: Color) -> some View {
        FigureText(text, role: role)
            .foregroundStyle(ink)
            .lineLimit(1)
            .frame(width: TableColumnWidth.runsFigure, alignment: .trailing)
    }

    /// "1,204 runs", "0 runs", "Unmeasurable", "Counting".
    static func spoken(_ value: Value) -> String {
        switch value {
        case .count(let runs, _): NumberWording.plural(runs, "run")
        case .zero: NumberWording.plural(0, "run")
        case .unmeasurable: "Unmeasurable"
        case .pending: "Counting"
        }
    }
}
