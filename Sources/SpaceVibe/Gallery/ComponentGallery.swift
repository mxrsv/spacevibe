import SwiftUI

/// Development-only specimens, split to stay below ImageRenderer's maximum image height.
struct ComponentGalleryContent: View {
    enum Part { case all, first, second, third, fourth, fifth }
    var part: Part = .all

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if part == .all || part == .first {
                section("Colour tokens") { Swatches() }
                section("Text roles") { TypeRoles() }
                section("Settings controls") { SettingsSpecimens() }
            }
            if part == .all || part == .second {
                section("Category, content and verdict glyphs") { V5IconSpecimens() }
            }
            if part == .all || part == .third {
                section("Containers") { ContainerSpecimens() }
            }
            if part == .all || part == .fourth {
                section("Controls and overlays") { ControlSpecimens() }
                section("Sidebar and content panel") { ShellSpecimens() }
            }
            if part == .all || part == .fifth {
                section("Skills detail pane") { PaneSpecimens() }
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            GroupLabel(title)
            content()
        }
    }
}

/// Every text role with its size, line box and weight, set in itself.
private struct TypeRoles: View {
    private let roles: [(String, SpaceVibeType)] = [
        ("caption", .caption), ("captionStrong", .captionStrong), ("label", .label), ("count", .count),
        ("body", .body), ("bodyStrong", .bodyStrong), ("rowTitle", .rowTitle), ("number", .number),
        ("code", .code), ("codeTitle", .codeTitle), ("title", .title), ("figure", .figure), ("display", .display),
    ]

    var body: some View {
        GroupedList {
            ForEach(roles, id: \.0) { name, role in
                HStack(spacing: Metrics.rowSpacing) {
                    Text(name).spaceVibeText(.code, tone: .tertiary).frame(width: Metrics.usageCellWidth, alignment: .leading)
                    Text("\(Int(role.size)) / \(Int(role.lineBox))").spaceVibeText(.count, tone: .tertiary).frame(width: Metrics.costWidth, alignment: .leading)
                    Text(role.code ? "Bash(rm -rf:*) 0O lI1" : role.size > SpaceVibeType.figure.size ? "92%" : "ponytail \u{00B7} Add to Codex \u{00B7} 1,204")
                        .spaceVibeText(role, tone: .primary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, Metrics.rowHorizontalPadding)
                .frame(minHeight: Metrics.rowMinHeight)
            }
        }
    }
}

/// The gallery as a window: scrolls, offers the theme toggle, and fires real toasts.
struct ComponentGalleryWindow: View {
    @Environment(ToastCenter.self) private var toasts

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Text("Component gallery").spaceVibeText(.title).accessibilityAddTraits(.isHeader)
                    Spacer(minLength: 0)
                    Button("Toast with Undo") { toasts.show("Removed ponytail", undo: { toasts.show("Undone: removed ponytail") }) }
                        .buttonStyle(.spaceVibe(.normal))
                    Button("Error toast") { toasts.show("Could not write settings.json", tone: .danger) }
                        .buttonStyle(.spaceVibe(.normal))
                    ThemeToggle()
                }
                .padding(.leading, Metrics.pagePadding + 70)
                .padding(.trailing, Metrics.pagePadding)
                .padding(.top, 16)
                .padding(.bottom, 4)
                SpaceVibeScrollView { ComponentGalleryContent() }
            }
            ToastHost()
        }
        .overlayHost()
        .background(Palette.well)
        .ignoresSafeArea()
    }
}

private struct Swatches: View {
    private let tokens: [(String, Color)] = [
        ("background", Palette.background), ("well", Palette.well), ("surface", Palette.surface),
        ("surfaceRaised", Palette.surfaceRaised), ("border", Palette.border), ("divider", Palette.divider),
        ("selection", Palette.selection), ("hover", Palette.hover), ("accent", Palette.accent),
        ("accentSolid", Palette.accentSolid), ("text", Palette.text), ("textSecondary", Palette.textSecondary),
        ("textTertiary", Palette.textTertiary), ("claude", Palette.claude), ("codex", Palette.codex),
        ("success", Palette.success), ("warn", Palette.warn), ("danger", Palette.danger),
    ]

    var body: some View {
        let rows = stride(from: 0, to: tokens.count, by: 10).map { Array(tokens[$0..<min($0 + 10, tokens.count)]) }
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .top, spacing: 10) {
                    ForEach(row, id: \.0) { token in
                        VStack(alignment: .leading, spacing: 4) {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(token.1)
                                .frame(height: 28)
                                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Palette.border, lineWidth: 1))
                            Text(token.0).spaceVibeText(.caption, tone: .tertiary).lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// Every generated glyph at the four sizes, in the secondary tone and in a tag's warn ink, then the chevrons.
private struct SettingsSpecimens: View {
    @State private var section = SettingsSection.appearance
    @State private var theme = ThemeSetting.dark
    @State private var on = true
    @State private var off = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s16) {
            HStack(spacing: Space.s4) {
                ForEach(SettingsSection.allCases) { item in
                    RailTab(title: item.title, icon: item.icon, isActive: item == section) { section = item }
                }
            }
            GroupedList {
                HStack(spacing: Rhythm.tiles) {
                    ForEach(ThemeSetting.allCases, id: \.self) { item in
                        ThemeTile(title: item.title, icon: item.icon, appearance: item.fixed?.colorScheme, isSelected: item == theme) { theme = item }
                    }
                }
                .frame(width: Metrics.settingsColumnWidth)
                .padding(.horizontal, Metrics.rowInset)
                .padding(.top, Space.s8)
                .groupedListPart(.plain)
                HStack(spacing: Space.s16) {
                    SpaceVibeSwitch(label: "On", isOn: $on)
                    SpaceVibeSwitch(label: "Off", isOn: $off)
                    SpaceVibeSwitch(label: "Disabled", isOn: .constant(false)).disabled(true)
                    SpaceVibeMark()
                    RaisedBlock { Text("A raised block inside a card").spaceVibeText(.body, tone: .secondary) }
                        .frame(width: Metrics.usageCellWidth * 2)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, Metrics.rowHorizontalPadding)
                .padding(.top, Space.s8)
                .groupedListPart(.plain)
            }
        }
    }
}

/// Every v5 glyph at 12, 14, 16 and 24 in the secondary tone, and at 16 in the tertiary tone (a lead icon) and in a warn ink,
/// two to a line: the category set, the content set, then the five verdict glyphs.
private struct V5IconSpecimens: View {
    private let sizes: [IconSize] = [.small, .inline, .control, .large]
    private let columns = 2

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s12) {
            GroupedList {
                specimenGrid(CategoryGlyph.allCases.map { glyph in
                    (glyph.iconName, { size, ink in SpaceVibeIcon(category: glyph, size: size, ink: ink) })
                })
            }
            GroupedList {
                specimenGrid(ContentGlyph.allCases.map { glyph in
                    (glyph.iconName, { size, ink in SpaceVibeIcon(content: glyph, size: size, ink: ink) })
                })
            }
            GroupedList {
                specimenGrid(VerdictGlyph.Kind.allCases.map { kind in
                    ("verdict \(kind)", { size, _ in VerdictGlyph(kind, size: size) })
                })
            }
        }
    }

    private func specimenGrid(_ items: [(String, (IconSize, Color?) -> some View)]) -> some View {
        let rows = stride(from: 0, to: items.count, by: columns).map { Array(items[$0 ..< min($0 + columns, items.count)]) }
        return VStack(alignment: .leading, spacing: Space.s8) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(alignment: .center, spacing: Space.s16) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, item in
                        HStack(spacing: Space.s8) {
                            Text(item.0).spaceVibeText(.code, tone: .tertiary).frame(width: Metrics.usageCellWidth * 1.4, alignment: .leading)
                            ForEach(Array(sizes.enumerated()), id: \.offset) { _, size in
                                item.1(size, nil).frame(width: Metrics.iconLarge)
                            }
                            item.1(.control, Palette.warnInk)
                            item.1(.control, Palette.textTertiary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    ForEach(0 ..< columns - row.count, id: \.self) { _ in Color.clear.frame(maxWidth: .infinity) }
                }
            }
        }
        .foregroundStyle(Palette.textSecondary)
        .padding(.horizontal, Metrics.rowHorizontalPadding)
    }
}
