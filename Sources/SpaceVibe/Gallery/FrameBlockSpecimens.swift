import SwiftUI

/// The redesign's in-page blocks (RB-S4, DS-R10) in every state, dark beside light: buttons, checkbox, rows, group heads,
/// hero, meters, logo toggles and the CLI tile grid, with the break-ui extremes. The overlays are in `FrameOverlaySpecimens`.
/// Compare with the mock's `?page=tokens` Components half.
struct FrameBlockSpecimens: View {
    /// The rows specimen takes ↑↓ and j/k in the gallery window (`listKeyboardSelection`); it starts in the drawn states.
    @State private var selected: String? = "review-pr"
    @State private var keyboardRow: String? = "lint-fixer"

    var body: some View {
        FrameSpecimenColumns {
            buttons
            checkboxes
            rows
            groupHeads
            heroes
            meters
            toggles
            tiles
        }
    }

    // MARK: Buttons and checkbox

    private var buttons: some View {
        FrameSpecimenGroup(title: "Buttons: primary, control, icon, small, quiet, link, destructive · normal, hover, pressed, disabled, loading") {
            line {
                Button {} label: { PushButtonLabel("Add Rule…", icon: .plus) }.buttonStyle(PushButtonStyle(.primary))
                Button {} label: { Text("Hover") }.buttonStyle(PushButtonStyle(.primary)).specimen(.hover)
                Button {} label: { Text("Pressed") }.buttonStyle(PushButtonStyle(.primary)).specimen(.press)
                Button {} label: { Text("Disabled") }.buttonStyle(PushButtonStyle(.primary)).disabled(true)
                Button {} label: { Text("Saving") }.buttonStyle(PushButtonStyle(.primary, isLoading: true))
            }
            line {
                Button {} label: { PushButtonLabel("Remove 3 selected", icon: .trash) }.buttonStyle(PushButtonStyle(.destructive))
                Button {} label: { PushButtonLabel("Select rows to remove", icon: .trash) }.buttonStyle(PushButtonStyle(.destructive)).disabled(true)
                Button {} label: { PushButtonLabel("Scan Again", icon: .arrowClockwise) }.buttonStyle(PushButtonStyle(.control))
                Button {} label: { FrameGlyph(.magnifyingGlass) }.buttonStyle(PushButtonStyle(.icon)).accessibilityLabel("Search")
                Button {} label: { Text("Focus") }.buttonStyle(PushButtonStyle(.control)).specimen(.focus)
            }
            line {
                Button {} label: { Text("Keep") }.buttonStyle(PushButtonStyle(.control, size: .small))
                Button {} label: { PushButtonLabel("Show in Finder", icon: .folderOpen, size: .small) }.buttonStyle(PushButtonStyle(.control, size: .small))
                Button {} label: { Text("Remove from Claude Code") }.buttonStyle(PushButtonStyle(.destructive, size: .small))
                SelectSuggestedButton(count: 6) {}
                Button {} label: { Text("Dismiss") }.buttonStyle(PushButtonStyle(.quiet, size: .small))
                Button {} label: { Text("Loading") }.buttonStyle(PushButtonStyle(.control, size: .small, isLoading: true))
            }
        }
    }

    private var checkboxes: some View {
        FrameSpecimenGroup(title: "Checkbox in its 28 pt cell: on, off, mixed, hover, focus, disabled") {
            line {
                CheckboxCell(.on, label: "On") {}
                CheckboxCell(.off, label: "Off") {}
                CheckboxCell(.mixed, label: "Mixed") {}
                CheckboxCell(.off, label: "Hover") {}.specimen(.hover)
                CheckboxCell(.on, label: "Focus") {}.specimen(.focus)
                CheckboxCell(.off, label: "Disabled") {}.disabled(true)
                CheckboxCell(.on, label: "Disabled on") {}.disabled(true)
            }
        }
    }

    // MARK: Rows and group heads

    private var rows: some View {
        FrameSpecimenGroup(title: "Rows: plain, hover, selected (actions on the selected row), keyboard focus, disabled, long and right-to-left names") {
            VStack(spacing: 0) {
                row("pdf-extract", sub: "Pull text and tables out of PDF files", check: .off)
                row("commit-helper", sub: "Hover", check: .off).specimen(.hover)
                ItemRow(label: "review-pr", isSelected: selected == "review-pr", check: .init(value: .on, label: "Select review-pr") {}, select: { selected = "review-pr" }) {
                    ItemRowTitle(name: "review-pr", sub: "Selected · 24 sessions", icon: .skills, iconInk: ColorRole.toneSkills)
                } actions: {
                    Button {} label: { Text("Keep") }.buttonStyle(PushButtonStyle(.control, size: .small))
                    Button {} label: { Text("Remove…") }.buttonStyle(PushButtonStyle(.destructive, size: .small))
                }
                ItemRow(label: "lint-fixer", isSelected: selected == "lint-fixer", isKeyboardFocused: keyboardRow == "lint-fixer",
                        select: { selected = "lint-fixer" }) {
                    ItemRowTitle(name: "lint-fixer", sub: "Keyboard focus · 3 pt bar", icon: .skills, iconInk: ColorRole.toneSkills)
                }
                row("brand-voice", sub: "Disabled", check: .off).disabled(true)
                row(FrameSpecimenData.longName, sub: FrameSpecimenData.longPath, check: .off)
                row(FrameSpecimenData.arabicName, sub: "Right to left", check: nil, height: .list)
            }
            .listKeyboardSelection(ids: ["review-pr", "lint-fixer"], selection: $selected, keyboardRow: $keyboardRow)
        }
    }

    private func row(_ name: String, sub: String, check: CheckboxValue?, height: ItemRowHeight = .table) -> some View {
        ItemRow(label: name, height: height, check: check.map { .init(value: $0, label: "Select \(name)") {} }, select: {}) {
            ItemRowTitle(name: name, sub: sub, icon: .skills, iconInk: ColorRole.toneSkills)
        }
    }

    private var groupHeads: some View {
        FrameSpecimenGroup(title: "Group heads: critical with Select N Suggested, attention, none, a huge count") {
            VStack(alignment: .leading, spacing: 0) {
                GroupHead("Clean up", count: 6, severity: .critical) { SelectSuggestedButton(count: 6) {} }
                GroupHead("Control", count: 3, severity: .attention)
                GroupHead("Balance", count: 1)
                GroupHead("Watch", count: 1_204_331, severity: .attention) { SelectSuggestedButton(count: 1_204_331) {} }
            }
        }
    }

    // MARK: Hero and meters

    private var heroes: some View {
        FrameSpecimenGroup(title: "Hero: value with unit, plain count, clear, scanning, unmeasurable, huge") {
            line {
                PageHero(.value("780", unit: "MB"), label: "can be cleaned")
                PageHero(.value("3", unit: nil), label: "never ran")
                PageHero(.clear("Clear"), label: "Nothing needs you")
            }
            line {
                PageHero(.scanning, label: "measuring")
                PageHero(.unmeasurable, label: "Unmeasurable")
                PageHero(.value(NumberWording.bytes(Int64(1_502_000_000_000_000)), unit: nil), label: "can be cleaned · 12 Hooks to remove")
            }
        }
    }

    private var meters: some View {
        FrameSpecimenGroup(title: "Meters 4 / 6 / 3 with the pace tick: plain, data, attention, critical, Unmeasurable, progress") {
            VStack(alignment: .leading, spacing: SpaceRole.step12) {
                FrameSpecimenCaption("hero 6 · 38% left, time tick at 62%")
                ShareMeter(share: 0.38, height: .hero, paceTick: 0.62)
                FrameSpecimenCaption("hero 6 · attention, behind pace")
                ShareMeter(share: 0.77, height: .hero, tone: .attention, paceTick: 0.82)
                FrameSpecimenCaption("hero 6 · critical, 4% left")
                ShareMeter(share: 0.04, height: .hero, tone: .critical, paceTick: 0.5)
                FrameSpecimenCaption("row 4 · data and plain")
                ShareMeter(share: 0.62, tone: .data)
                ShareMeter(share: 0.2)
                FrameSpecimenCaption("row 4 · Unmeasurable (never 0)")
                ShareMeter(share: nil)
                FrameSpecimenCaption("progress 3 · 35%")
                ShareMeter(share: 0.35, height: .progress, label: "Reading session logs")
            }
        }
    }

    // MARK: Toggles and tiles

    private var toggles: some View {
        FrameSpecimenGroup(title: "CLI logo toggles: every state, then hover, press, focus, and a row of 10 CLIs wrapping at 5") {
            HStack(alignment: .top, spacing: SpaceRole.step8) {
                ForEach(Array(FrameSpecimenData.everyToggleState.enumerated()), id: \.offset) { _, item in
                    VStack(spacing: SpaceRole.step4) {
                        CLILogoToggle(item.1) {}
                        FrameSpecimenCaption(item.0)
                    }
                    .frame(width: SizeRole.hitCell * 2)
                }
            }
            line {
                CLILogoToggle(CLIToggleState(cli: .claude, presence: .on(.sessions(3)))) {}.specimen(.hover)
                CLILogoToggle(CLIToggleState(cli: .codex, presence: .off)) {}.specimen(.hover)
                CLILogoToggle(CLIToggleState(cli: .claude, presence: .on(.sessions(3)))) {}.specimen(.press)
                CLILogoToggle(CLIToggleState(cli: .codex, presence: .on(.sessions(3)))) {}.specimen(.focus)
            }
            line {
                CLIToggleStrip(states: FrameSpecimenData.row(2)) { _ in }
                CLIToggleStrip(states: FrameSpecimenData.row(6)) { _ in }
                CLIToggleStrip(states: FrameSpecimenData.row(10)) { _ in }
            }
        }
    }

    private var tiles: some View {
        FrameSpecimenGroup(title: "CLI tiles: 2, 6 and 10 CLIs (never above 3 rows), heat relative to the top CLI, every state") {
            VStack(alignment: .leading, spacing: SpaceRole.step16) {
                CLITileGrid(states: FrameSpecimenData.row(2)) { _ in }
                CLITileGrid(states: FrameSpecimenData.row(6)) { _ in }
                CLITileGrid(states: FrameSpecimenData.row(10)) { _ in }
                CLITileGrid(states: FrameSpecimenData.everyToggleState.map(\.1)) { _ in }
                line {
                    CLITile(state: CLIToggleState(cli: .claude, presence: .on(.sessions(40))), step: .high) {}.specimen(.hover)
                    CLITile(state: CLIToggleState(cli: .codex, presence: .off), step: .none) {}.specimen(.hover)
                    CLITile(state: CLIToggleState(cli: .claude, presence: .on(.sessions(12))), step: .middle) {}.specimen(.focus)
                }
            }
        }
    }

    private func line<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: SpaceRole.step8) { content() }
    }
}
