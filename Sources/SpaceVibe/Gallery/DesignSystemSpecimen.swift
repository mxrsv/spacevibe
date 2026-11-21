import SwiftUI

/// The redesign's "Tokens + base" specimen (RD-A3, DS-R12), tokens only: colour roles, data steps, the type ramp, space,
/// radii, sizes, meters, the focus bar and opacity, dark beside light, with a switch for the Increase Contrast values. Every
/// colour is drawn from `ColorRoleValues` at a fixed variant, so both themes and both contrasts show at once whatever the
/// window's appearance. The blocks join it in RB-S4. Compare with the mock's page:
/// `~/scratch/spacevibe-reins/2026-11-20-redesign-v2/mock.html?page=tokens`.
struct DesignSystemSpecimen: View {
    @State private var increased: Bool

    init(increased: Bool = false) {
        _increased = State(initialValue: increased)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SpaceRole.step16) {
            Toggle("Increase Contrast", isOn: $increased)
                .toggleStyle(.checkbox)
                .typeRole(.quiet)
            HStack(alignment: .top, spacing: SpaceRole.step16) {
                SpecimenColumn(variant: ColorRoleVariant(dark: true, increased: increased))
                    .environment(\.colorScheme, .dark)
                SpecimenColumn(variant: ColorRoleVariant(dark: false, increased: increased))
                    .environment(\.colorScheme, .light)
            }
        }
    }
}

/// One theme of the specimen.
private struct SpecimenColumn: View {
    let variant: ColorRoleVariant

    private typealias V = ColorRoleValues

    private func c(_ value: ColorRoleValue) -> Color { value.color(variant) }

    var body: some View {
        VStack(alignment: .leading, spacing: SpaceRole.step24) {
            Text("\(variant.isDark ? "Dark" : "Light")\(variant.isIncreased ? " · Increase Contrast" : "")")
                .typeRole(.windowFigure.figures)
                .foregroundStyle(c(V.ink))
            section("Colour", note: "Surfaces graphite; colour on state, data and one tone per category. Ratio on group.") { colours }
            section("Data", note: "Neutral steps on bars and tiles; Increase Contrast lifts every step to 3:1.") { data }
            section("Type", note: "SF Pro text, SF Pro Rounded figures, SF Mono paths. 400 and 500; 600 for sidebar labels.") { type }
            section("Space", note: "Nine steps. Toolbar clearance 68 Glass / 64 Solid, title 36, empty state 72.") { space }
            section("Radius", note: "Glass 26 / 18 / 14 / capsule, Solid 12 / 0 / 10 / 6 (window, sidebar, group, control).") { radius }
            section("Sizes", note: "Controls 32 / 26 / 20, hit cell 28, rows 48 table / 44 list, icons 12 to 40.") { sizes }
            section("Meters and focus", note: "Meters 4 / 6 / 3 with the 2 pt pace tick; focus is a 3 pt ink bar, never a ring.") {
                meters
            }
            section("Opacity", note: "Disabled .42, dim .55 (an off logo), ghost .35 (Not supported).") { opacity }
        }
        .padding(SpaceRole.step24)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(c(V.canvasSurface))
    }

    private func section<Content: View>(_ title: String, note: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: SpaceRole.step12) {
            Text(title).typeRole(.pageTitle).foregroundStyle(c(V.ink))
            Text(note).typeRole(.quiet).foregroundStyle(c(V.ink3)).fixedSize(horizontal: false, vertical: true)
            content()
        }
    }

    private func label(_ text: String, _ role: TypeRole = .axisCaption, ink: ColorRoleValue = ColorRoleValues.ink3) -> some View {
        Text(text).typeRole(role).foregroundStyle(c(ink)).lineLimit(1)
    }

    // MARK: Colour

    /// Three to a line; a plain stack, because `ImageRenderer` (the headless shots) does not draw lazy grids reliably.
    private var colours: some View {
        let roles = ColorRoleValues.all
        let lines = stride(from: 0, to: roles.count, by: Layout.swatchesPerLine).map {
            Array(roles[$0 ..< min($0 + Layout.swatchesPerLine, roles.count)])
        }
        return VStack(alignment: .leading, spacing: SpaceRole.step10) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                HStack(alignment: .top, spacing: SpaceRole.step10) {
                    ForEach(line, id: \.name) { role in
                        VStack(alignment: .leading, spacing: SpaceRole.step4) {
                            RoundedRectangle(cornerRadius: RadiusRole.step8)
                                .fill(c(V.groupSurface))
                                .overlay(RoundedRectangle(cornerRadius: RadiusRole.step8).fill(c(role.value)))
                                .overlay(RoundedRectangle(cornerRadius: RadiusRole.step8).strokeBorder(c(V.hairline)))
                                .frame(height: SizeRole.controlSmall)
                            label(role.name, .quiet, ink: V.ink2)
                            label(swatchText(role.value.swatch(variant), spec: role.specName), .mono)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    ForEach(0 ..< Layout.swatchesPerLine - line.count, id: \.self) { _ in Color.clear.frame(maxWidth: .infinity) }
                }
            }
        }
    }

    private func swatchText(_ swatch: ColorRoleValue.Swatch, spec: String) -> String {
        let hex = String(format: "#%06X", swatch.hex)
        guard swatch.alpha == 1 else { return "\(spec) · \(hex) \(Int((swatch.alpha * 100).rounded()))%" }
        let ratio = SpecimenContrast.ratio(swatch.hex, V.groupSurface.swatch(variant).hex)
        return "\(spec) · \(hex) · \(String(format: "%.2f", ratio))"
    }

    // MARK: Data

    private var data: some View {
        VStack(alignment: .leading, spacing: SpaceRole.step12) {
            HStack(spacing: SpaceRole.step8) {
                ForEach([("1", V.data1, V.dataInk1), ("2", V.data2, V.dataInk2), ("3", V.data3, V.dataInk3), ("4", V.data4, V.dataInk4),
                         ("bar", V.dataBar, V.canvasSurface), ("track", V.faint, V.ink)], id: \.0) { name, value, ink in
                    RoundedRectangle(cornerRadius: RadiusRole.step8)
                        .fill(c(value))
                        .frame(width: Layout.dataStep.width, height: Layout.dataStep.height)
                        .overlay(label(name, .quietMedium.figures, ink: ink))
                }
            }
            meter(height: SizeRole.meterHero, fill: 0.62, tick: 0.48, ink: V.dataBar)
        }
        .padding(SpaceRole.step16)
        .background(RoundedRectangle(cornerRadius: RadiusRole.step14).fill(c(V.groupSurface)))
    }

    // MARK: Type

    private var type: some View {
        VStack(alignment: .leading, spacing: SpaceRole.step8) {
            ForEach(TypeRole.all, id: \.name) { name, specName, role in
                HStack(alignment: .firstTextBaseline, spacing: SpaceRole.step16) {
                    label("\(name) · \(specName) · \(Int(role.size))/\(Int(role.lineHeight))", .mono)
                        .frame(width: Layout.typeLabel, alignment: .leading)
                    Text(sample(for: role)).typeRole(role).foregroundStyle(c(V.ink)).lineLimit(1)
                }
            }
            HStack(spacing: SpaceRole.step16) {
                label("quietMedium.figures · .rc b", .mono).frame(width: Layout.typeLabel, alignment: .leading)
                Text("1,204").typeRole(TypeRole.quietMedium.figures).foregroundStyle(c(V.ink))
            }
        }
    }

    private func sample(for role: TypeRole) -> String {
        switch role.face {
        case .figures: role.size > TypeRole.pageTitle.size ? "3.42 GB" : "38% left"
        case .mono: "~/.claude/hooks/lint-staged.sh"
        case .text: role == .sidebarLabel ? "Skills" : (role == .quietMedium ? "Show in Finder" : "commit-helper · added 41 days ago")
        }
    }

    // MARK: Space, radius, sizes

    private var space: some View {
        HStack(alignment: .bottom, spacing: SpaceRole.step16) {
            ForEach(SpaceRole.steps, id: \.self) { step in
                VStack(spacing: SpaceRole.step6) {
                    Rectangle().fill(c(V.ink3)).frame(width: step, height: step)
                    label("\(Int(step))")
                }
            }
        }
    }

    private var radius: some View {
        HStack(alignment: .bottom, spacing: SpaceRole.step16) {
            ForEach(Array(RadiusRole.steps.enumerated()), id: \.offset) { _, corner in
                VStack(spacing: SpaceRole.step6) {
                    CornerShape(corner: corner)
                        .fill(c(V.controlFill))
                        .overlay(CornerShape(corner: corner).strokeBorder(c(V.hairline)))
                        .frame(width: Layout.radiusTile.width, height: Layout.radiusTile.height)
                    label(corner.specimenName)
                }
            }
        }
    }

    private var sizes: some View {
        HStack(alignment: .bottom, spacing: SpaceRole.step16) {
            ForEach([("regular", SizeRole.controlRegular), ("small", SizeRole.controlSmall), ("mini", SizeRole.controlMini),
                     ("hit cell", SizeRole.hitCell), ("list row", SizeRole.listRow), ("table row", SizeRole.tableRow)], id: \.0) { name, height in
                VStack(spacing: SpaceRole.step6) {
                    RoundedRectangle(cornerRadius: RadiusRole.step6).fill(c(V.controlFill))
                        .frame(width: Layout.dataStep.width, height: height)
                    label("\(name) \(Int(height))")
                }
            }
            ForEach(SizeRole.icons, id: \.self) { side in
                VStack(spacing: SpaceRole.step6) {
                    RoundedRectangle(cornerRadius: RadiusRole.step4).strokeBorder(c(V.ink3)).frame(width: side, height: side)
                    label("\(Int(side))")
                }
            }
        }
    }

    // MARK: Meters, focus, opacity

    private var meters: some View {
        VStack(alignment: .leading, spacing: SpaceRole.step12) {
            meter(height: SizeRole.meterRow, fill: 0.38, tick: 0.62, ink: V.dataBar)
            meter(height: SizeRole.meterHero, fill: 0.77, tick: 0.82, ink: V.attentionBar)
            meter(height: SizeRole.meterHero, fill: 0.04, tick: nil, ink: V.criticalBar)
            meter(height: SizeRole.meterProgress, fill: 0.35, tick: nil, ink: V.ink2)
            VStack(spacing: 0) {
                row("Selected row", fill: V.selectionFill, focus: false)
                row("Keyboard focus · 3 pt bar", fill: nil, focus: true)
                row("Hover", fill: V.hoverFill, focus: false)
                row("Plain row", fill: nil, focus: false)
            }
            .background(c(V.groupSurface))
            .clipShape(RoundedRectangle(cornerRadius: RadiusRole.step14))
        }
    }

    private func meter(height: CGFloat, fill: CGFloat, tick: CGFloat?, ink: ColorRoleValue) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(c(V.faint))
                Capsule().fill(c(ink)).frame(width: proxy.size.width * fill)
                if let tick {
                    Capsule().fill(c(V.ink))
                        .frame(width: SizeRole.paceTickWidth, height: height + 2 * SizeRole.paceTickOverhang)
                        .offset(x: proxy.size.width * tick)
                }
            }
        }
        .frame(height: height)
    }

    private func row(_ title: String, fill: ColorRoleValue?, focus: Bool) -> some View {
        HStack(spacing: 0) {
            Rectangle().fill(focus ? c(V.ink) : .clear).frame(width: SizeRole.focusBar)
            Text(title).typeRole(.bodyText).foregroundStyle(c(V.ink)).padding(.leading, SpaceRole.step12)
            Spacer(minLength: 0)
        }
        .frame(height: SizeRole.listRow)
        .background(fill.map { c($0) } ?? .clear)
    }

    private var opacity: some View {
        HStack(spacing: SpaceRole.step24) {
            ForEach([("rest", 1.0), ("disabled", OpacityRole.disabled), ("dim", OpacityRole.dim), ("ghost", OpacityRole.ghost)],
                    id: \.0) { name, value in
                VStack(spacing: SpaceRole.step6) {
                    Text("Aa").typeRole(TypeRole.pageTitle).foregroundStyle(c(V.ink)).opacity(value)
                    label(name)
                }
            }
            VStack(spacing: SpaceRole.step6) {
                RoundedRectangle(cornerRadius: RadiusRole.step10).fill(c(V.groupSurface))
                    .frame(width: Layout.floatTile.width, height: Layout.floatTile.height)
                    .shadow(color: c(V.floatShadow), radius: ShadowRole.floatRadius, y: ShadowRole.floatOffsetY)
                label("float")
            }
        }
    }
}

/// The specimen's own sample sizes, as the mock's Tokens page draws them (`.dstep` 56 x 36, the radius tile 40 x 28, the float
/// tile 72 x 40).
private enum Layout {
    static let swatchesPerLine = 3
    static let typeLabel: CGFloat = 230
    static let dataStep = CGSize(width: 56, height: 36)
    static let radiusTile = CGSize(width: 40, height: 28)
    static let floatTile = CGSize(width: 72, height: 40)
}

/// A `CornerRole` as a shape.
private struct CornerShape: InsettableShape {
    let corner: CornerRole
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let box = rect.insetBy(dx: inset, dy: inset)
        switch corner {
        case .capsule: return Capsule().path(in: box)
        case .radius(let radius): return RoundedRectangle(cornerRadius: max(0, radius - inset)).path(in: box)
        }
    }

    func inset(by amount: CGFloat) -> CornerShape { CornerShape(corner: corner, inset: inset + amount) }
}

private extension CornerRole {
    var specimenName: String {
        switch self {
        case .capsule: "capsule"
        case .radius(let radius): "\(Int(radius))"
        }
    }
}

/// WCAG 2 contrast for the specimen's captions (the tests compute their own in `ColorMath`).
private enum SpecimenContrast {
    static func ratio(_ x: UInt32, _ y: UInt32) -> Double {
        let (a, b) = (luminance(x), luminance(y))
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    private static func luminance(_ hex: UInt32) -> Double {
        func linear(_ shift: UInt32) -> Double {
            let c = Double((hex >> shift) & 0xFF) / 255
            return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(16) + 0.7152 * linear(8) + 0.0722 * linear(0)
    }
}
