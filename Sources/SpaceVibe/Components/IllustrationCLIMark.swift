import SwiftUI

/// The marks of the illustration CLIs (RD42, RD46: the mock's logos instead of letters), drawn as one even-odd path in the
/// 24 × 24 box. Source: the reference mock's `src/logos.js` (2026-11-20 redesign v2), where they are SpaceVibe's own simple
/// monochrome symbols, drawn for the mock and not any product's brand logo (design notes §15, §16); no third-party licence.
/// Only Claude Code, Codex and Gemini CLI have real brand marks (`Resources/Brand`, `BrandMark`). The engine reads two CLIs
/// today, so these show only in the 6 and 10 CLI shots and tests.
enum IllustrationCLIMark: String, CaseIterable, Sendable {
    case cursor, copilot, opencode, amp, antigravity, kiro, qwen, aider

    /// The mock's ink: `ink2` for the first four (`.cl.cursor, .cl.copilot, .cl.opencode, .cl.amp`), `ink` (the `.cl`
    /// default) for the rest.
    var ink: Color {
        switch self {
        case .cursor, .copilot, .opencode, .amp: ColorRole.ink2
        case .antigravity, .kiro, .qwen, .aider: ColorRole.ink
        }
    }

    /// The mark in the 24 × 24 box, filled even-odd.
    var path: Path {
        var p = Path()
        switch self {
        case .cursor:
            p.addLines(Self.points([12, 2.5, 20.5, 7.4, 20.5, 16.6, 12, 21.5, 3.5, 16.6, 3.5, 7.4])); p.closeSubpath()
            p.addLines(Self.points([12, 5.6, 6.2, 9, 6.2, 15, 12, 18.4, 17.8, 15, 17.8, 9])); p.closeSubpath()
        case .copilot:
            p.addEllipse(in: Self.circle(radius: 9))
            p.addEllipse(in: Self.circle(radius: 6))
            p.addEllipse(in: Self.circle(radius: 2.4))
        case .opencode:
            p.addRect(CGRect(x: 4, y: 3, width: 16, height: 18))
            p.addRect(CGRect(x: 7, y: 6, width: 10, height: 12))
            p.addRect(CGRect(x: 9.5, y: 9, width: 5, height: 6))
        case .amp:
            p.addLines(Self.points([12, 3, 22, 21, 2, 21])); p.closeSubpath()
            p.addLines(Self.points([12, 8.6, 6.9, 18, 17.1, 18])); p.closeSubpath()
        case .antigravity:
            p.addLines(Self.points([12, 2, 14.6, 9.4, 22, 12, 14.6, 14.6, 12, 22, 9.4, 14.6, 2, 12, 9.4, 9.4])); p.closeSubpath()
            p.addLines(Self.points([12, 7.5, 10.8, 10.8, 7.5, 12, 10.8, 13.2, 12, 16.5, 13.2, 13.2, 16.5, 12, 13.2, 10.8])); p.closeSubpath()
        case .kiro:
            p.addRoundedRect(in: CGRect(x: 3, y: 3, width: 18, height: 18), cornerSize: CGSize(width: 3, height: 3))
            p.addLines(Self.points([8.2, 7.2, 8.2, 16.8, 10.5, 16.8, 10.5, 13.1, 14.2, 16.8, 17, 16.8, 12.3, 12, 16.7, 7.2, 13.9, 7.2,
                                    10.2, 11.3, 10.2, 7.2]))
            p.closeSubpath()
        case .qwen:
            // A ring of radius 9 with a tail at its lower right (the mock's `a9 9 0 1 0 5.8 15.9 l2.7 2.1 -1.5-3.6 A9 9 …`).
            let center = CGPoint(x: 12, y: 12)
            p.move(to: CGPoint(x: 12, y: 3))
            p.addArc(center: center, radius: 9, startAngle: .degrees(-90), endAngle: Self.angle(to: CGPoint(x: 17.8, y: 18.9)), clockwise: true)
            p.addLine(to: CGPoint(x: 20.5, y: 21))
            p.addLine(to: CGPoint(x: 19, y: 17.4))
            p.addArc(center: center, radius: 9, startAngle: Self.angle(to: CGPoint(x: 19, y: 17.4)), endAngle: .degrees(-90), clockwise: true)
            p.closeSubpath()
            p.addEllipse(in: Self.circle(radius: 6))
        case .aider:
            p.addLines(Self.points([12, 3, 21, 21, 17.6, 21, 12, 9.6, 6.4, 21, 3, 21])); p.closeSubpath()
            p.addLines(Self.points([9.8, 15, 14.2, 15, 15.1, 17.4, 8.9, 17.4])); p.closeSubpath()
        }
        return p
    }

    private static func points(_ xy: [CGFloat]) -> [CGPoint] {
        stride(from: 0, to: xy.count - 1, by: 2).map { CGPoint(x: xy[$0], y: xy[$0 + 1]) }
    }

    private static func circle(radius: CGFloat) -> CGRect {
        CGRect(x: 12 - radius, y: 12 - radius, width: radius * 2, height: radius * 2)
    }

    private static func angle(to point: CGPoint) -> Angle {
        .radians(atan2(Double(point.y - 12), Double(point.x - 12)))
    }
}

/// An illustration CLI's mark scaled from its 24 pt box to the rect it is given (square, centred).
struct IllustrationCLIMarkShape: Shape {
    let mark: IllustrationCLIMark

    func path(in rect: CGRect) -> Path {
        mark.path.applying(GlyphBox.transform(into: rect))
    }
}
