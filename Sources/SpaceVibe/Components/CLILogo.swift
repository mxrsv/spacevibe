import SwiftUI

/// A CLI's logo in the new frame (DS-R6: 16 or 20), bare, never boxed. Claude Code and Codex draw their brand marks
/// (`Resources/Brand`, the same files as v5's `CLIMark`) as a mask in their `ColorRole` inks (`logoClaude`, `logoCodex`), so
/// each follows the theme and Increase Contrast; Gemini CLI's mark is drawn in `ink3` as the mock does. A CLI with no bundled
/// mark shows its initial in `ink2`: a stand-in, not a brand logo, until the registry ships marks (engine support beyond the two
/// CLIs is out of scope). Decorative: the name sits beside it or in the control's label.
struct CLILogo: View {
    let cli: CLIIdentity
    var size: CGFloat = SizeRole.logo20

    init(_ cli: CLIIdentity, size: CGFloat = SizeRole.logo20) {
        self.cli = cli
        self.size = size
    }

    var body: some View {
        Group {
            if let mark = Self.brandMark(cli.id), let image = BrandMark.image(mark) {
                Image(nsImage: image)
                    .resizable()
                    .renderingMode(.template)
                    .interpolation(.high)
                    .scaledToFit()
                    .foregroundStyle(Self.ink(cli.id))
            } else {
                Text(verbatim: Self.initial(cli.name))
                    .typeRole(size >= SizeRole.logo20 ? .bodyMedium : .quietMedium)
                    .foregroundStyle(ColorRole.ink2)
                    .lineLimit(1)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    /// The bundled mark for a registry id, if there is one.
    static func brandMark(_ id: String) -> CoreLimitsCLI? {
        switch id {
        case "claude": .claude
        case "codex": .codex
        case "gemini": .gemini
        default: nil
        }
    }

    static func ink(_ id: String) -> Color {
        switch id {
        case "claude": ColorRole.logoClaude
        case "codex": ColorRole.logoCodex
        default: ColorRole.ink3
        }
    }

    /// The first letter, upper-cased; "?" for an empty name.
    static func initial(_ name: String) -> String {
        name.first.map { String($0).uppercased() } ?? "?"
    }
}
