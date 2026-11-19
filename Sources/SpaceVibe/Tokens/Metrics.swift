import SwiftUI

/// Sizes, radii and spacing. One place so a number is never typed twice. Spec: `docs/specs/2026-11-03-reins-design-language.md`
/// (Spacing, sizes, radii, colour). Text roles live in `SpaceVibeType`. A width measured for text grows with the Font size
/// setting (`TypeScale.width(_:at:)`, the size it was measured at) and never shrinks below the measured value.
enum Metrics {
    /// A segment inside the segmented control's 28 pt frame.
    static let segmentHeight: CGFloat = 24

    /// Icon sizes (`IconSize`): the verdict box's 20, controls and rows 16, beside 12 pt text 14, an empty state's mark and
    /// a rail tab 24.
    static let iconRow: CGFloat = 20
    static let iconControl: CGFloat = 16
    static let iconInline: CGFloat = 14
    /// Chevrons, checks and the filter-chip close (V5-R16); the smallest an icon is ever drawn.
    static let iconSmall: CGFloat = 12
    static let iconLarge: CGFloat = 24

    /// Limits: the CLI mark (40, 28 in the page's list and detail title, 24 in a sidebar tile).
    static let cliMarkSize: CGFloat = 40
    static let cliMarkMediumSize: CGFloat = 28
    static let cliMarkSmallSize: CGFloat = 24
    /// The glyph's share of its mark square.
    static let cliMarkGlyphFraction: CGFloat = 0.6

    /// Settings: the window buttons at the top left (hidden title bar) and the gap after them, where the back button starts;
    /// the centred column of cards; one rail tab (icon over name); a Theme tile's picture, width over height.
    static let trafficLightsWidth: CGFloat = 92
    static let settingsColumnWidth: CGFloat = 720
    static let railTabWidth: CGFloat = 96
    static let railTabHeight: CGFloat = 60
    static let themeThumbnailAspect: CGFloat = 1.6
    /// The on/off switch: its capsule and the knob inside it, 2 pt from the edge.
    static let switchWidth: CGFloat = 32
    static let switchHeight: CGFloat = 20
    static let switchKnob: CGFloat = 16
    /// The SpaceVibe mark on the Update card, and its corner as a share of its side (`Resources/AppIcon.svg`: 57.5 of 256).
    static let spaceVibeMarkSize: CGFloat = 56
    static let spaceVibeMarkRadiusFraction: CGFloat = 57.5 / 256

    /// Toast stays about this long unless the pointer rests on it (5 s, the kit's duration; app-wide, spec C10).
    static let toastDuration: Duration = .seconds(5)
}

/// The v5 sizes (spec, "Rhythm and sizes (D66)"), one group per block. Spacing between blocks is in `Rhythm` (`edge`,
/// `card`, `group`, `side`).
extension Metrics {
    /// The verdict glyphs' drawing (the kit's `v2-*` symbols): a hexagon in a 16 box, stroked 1.5 with round caps and joins.
    enum Verdict {
        static let box: CGFloat = 16
        static let stroke: CGFloat = 1.5
        /// `nm`'s dashed outline: dash and gap, in the 16 box.
        static let dash: [CGFloat] = [1.8, 2.4]
        /// `nm`'s centre dot.
        static let dotRadius: CGFloat = 1.1
    }

    enum Radius {
        /// Key cap, checkbox, a skeleton bar and a bar cell's ends.
        static let small: CGFloat = 4
        /// Controls, tab chips, sidebar items, a logo toggle, the warning slot, menu items.
        static let control: CGFloat = 6
        /// The content panel, cards, rows, bands, menus, popovers, the toast, dialogs.
        static let block: CGFloat = 8
        static let window: CGFloat = 12
        /// The kit's corners are CSS arcs, so v5 shapes are circular, not the old screens' continuous corners.
        static let cornerStyle = RoundedCornerStyle.circular
        /// A block's edge and its top-edge highlight: 1 pt.
        static let edge: CGFloat = 1
    }

    enum AppSidebar {
        static let width: CGFloat = 220
        /// The window buttons' row at the top.
        static let windowButtonsHeight: CGFloat = 48
        /// The product row, the search row and each page item.
        static let itemHeight: CGFloat = 40
        static let itemPadding: CGFloat = 12
        static let itemSpacing: CGFloat = 4
        /// Inside a row: between the glyph and the label.
        static let itemGap: CGFloat = 8
        /// The product mark's tile, and a page item's glyph at rest (80%, 100% on hover and when current).
        static let markSize: CGFloat = 20
        static let restGlyphOpacity: Double = 0.8
        /// A CLI status row's dot and the gap after it.
        static let statusDot: CGFloat = 6
        static let statusDotGap: CGFloat = 6
        static let searchAbove: CGFloat = 8
        static let searchBelow: CGFloat = 20
        static let statusRowHeight: CGFloat = 32
        static let statusRowSpacing: CGFloat = 4
        static let statusAbove: CGFloat = 12
        static let statusBelow: CGFloat = 8
        /// `Settings` in the footer, and the square appearance toggle beside it.
        static let footerButtonHeight: CGFloat = 36
    }

    enum ContentPanel {
        /// The panel's margin from the window on top, right and bottom.
        static let inset: CGFloat = 12
        static let tabHeadHeight: CGFloat = 60
        /// The panel's content width in a 1440 pt window (the window less the sidebar, the right inset and the panel's two
        /// edges); the gallery draws its tab heads at it so crops line up with the mock's.
        static let widthAt1440: CGFloat = 1440 - AppSidebar.width - inset - 2 * Radius.edge
        static let statusBarHeight: CGFloat = 32
        static let statusBarPadding: CGFloat = 16
        static let statusBarSpacing: CGFloat = 16
    }

    enum TabChip {
        static let height: CGFloat = 36
        static let padding: CGFloat = 14
        /// Between two chips.
        static let spacing: CGFloat = 10
        /// Inside a chip: glyph, label and count.
        static let innerSpacing: CGFloat = 6
        /// The tab head: tabs from the content edge (`Rhythm.edge`) at the left, 8 before the actions; the actions 4 apart,
        /// ending at the content edge.
        static let tabsTrailing: CGFloat = 8
        static let actionSpacing: CGFloat = 4
        /// The count circle: at least this wide and high, 4 at the sides.
        static let countSize: CGFloat = 16
        static let countPadding: CGFloat = 4
    }

    enum ToolbarButton {
        static let height: CGFloat = 32
        static let padding: CGFloat = 12
        /// Between the glyph and the label.
        static let spacing: CGFloat = 4
    }

    enum FilterChipRow {
        static let verticalPadding: CGFloat = 8
        static let horizontalPadding: CGFloat = 12
        static let spacing: CGFloat = 8
        static let chipHeight: CGFloat = 24
        static let closeWidth: CGFloat = 24
        /// The field and the value inside a chip, and the `Clear` chip: 8 at each side.
        static let partPadding: CGFloat = 8
        /// Between a chip button's glyph and its text.
        static let glyphSpacing: CGFloat = 6
    }

    /// A row in a list or a card, and a band header.
    enum ListRow {
        static let height: CGFloat = 44
        /// Inside the row block: 10 before the lead slot, 8 after the last cell, 8 between cells.
        static let leading: CGFloat = 10
        static let trailing: CGFloat = 8
        static let spacing: CGFloat = 8
        /// The divider starts this far from the row block's leading edge (where a lead row's name starts) and ends this far
        /// from its trailing edge, on rows with and without a lead.
        static let dividerLeading: CGFloat = 34
        static let dividerTrailing: CGFloat = 8
        /// The current row's accent bar at the leading edge: its width, and its distance from the top and the bottom.
        static let currentBarWidth: CGFloat = 2
        static let currentBarInset: CGFloat = 8
        /// The checkbox that replaces the lead glyph, and its outline.
        static let checkbox: CGFloat = 16
        static let checkboxBorder: CGFloat = 1
        /// The share left in a row (20/28), right-aligned; fits "100%" at the default Font size.
        static var shareWidth: CGFloat { TypeScale.shared.width(64, at: 20) }
    }

    /// A bar cell: 8 high with round ends on the `track`; an unknown share is a 1 pt dashed line.
    enum Bar {
        static let height: CGFloat = 8
        static let unknownDash: [CGFloat] = [3, 3]
        /// Codex's identity fill (foreground) is a little quieter than Claude's clay (the kit's `.meter.x .mbar i`).
        static let codexOpacity: Double = 0.85
    }

    /// A card (the Tile, D56).
    enum Tile {
        static let headerHeight: CGFloat = 52
        static let headerLeading: CGFloat = 16
        static let headerTrailing: CGFloat = 12
        /// Between the title, count, state glyph and actions; between two header actions.
        static let headerSpacing: CGFloat = 8
        static let actionSpacing: CGFloat = 4
        /// The collapse button and a header action: 28 high.
        static let headerControl: CGFloat = 28
        /// An empty state inside a card: 24 on top, 12 at the sides, 28 below.
        static let emptyInsets = EdgeInsets(top: 24, leading: 12, bottom: 28, trailing: 12)
        /// Rows inside: 0 on top, 12 at the sides, 16 below.
        static let rowsSide: CGFloat = 12
        static let rowsBottom: CGFloat = 16
        /// Free content (and the Answer card): 4 on top, 20 at the sides, 24 below, 20 between parts.
        static let contentTop: CGFloat = 4
        static let contentSide: CGFloat = 20
        static let contentBottom: CGFloat = 24
        static let contentSpacing: CGFloat = 20
        /// Maximum heights by page layout.
        static let limitsSmallMaxHeight: CGFloat = 380
        static let spineMaxHeight: CGFloat = 680
        static let rulesSmallMaxHeight: CGFloat = 304
        /// Hooks' `Missing in Codex`: the kit sets no cap either.
        static let hooksSmallMaxHeight: CGFloat = 680
    }

    enum Band {
        static let headerHeight: CGFloat = 44
        /// Inside the header: 10 before the chevron, 12 after the extras, 8 between parts, 12 before the state glyph.
        static let leading: CGFloat = 10
        static let trailing: CGFloat = 12
        static let spacing: CGFloat = 8
        static let stateSpacing: CGFloat = 12
        /// Between collapsed bands that follow each other; on Hooks they form a two-column grid, 8 apart.
        static let collapsedSpacing: CGFloat = 10
        static let gridSpacing: CGFloat = 8
        static let gridColumns = 2
    }

    /// The loading skeleton of a card: three bars on the `track`, the second and third shorter, pulsing 0.5 to 1.
    enum Skeleton {
        static let insets = EdgeInsets(top: 4, leading: 12, bottom: 16, trailing: 12)
        static let spacing: CGFloat = 12
        static let barHeight: CGFloat = 12
        /// The bars' widths as shares of the card's.
        static let widths: [CGFloat] = [1, 0.72, 0.48]
        static let pulseLow: Double = 0.5
        static let pulse: TimeInterval = 1.2
    }

    /// An empty state outside a card (the Skills list): 48 on top and below, 24 at the sides.
    enum EmptyState {
        static let listInsets = EdgeInsets(top: 48, leading: 24, bottom: 48, trailing: 24)
        static let titleSpacing: CGFloat = 4
        static let actionAbove: CGFloat = 16
    }

    /// The verdict box: neutral glyph (20), then a sentence with its bold title and a quieter line under it.
    enum VerdictBox {
        static let padding: CGFloat = 12
        static let spacing: CGFloat = 12
        static let smallAbove: CGFloat = 4
    }

    /// `Stats`: 2 to 4 figures, each column at least 88 wide, 12 apart.
    enum Stats {
        static let columnMinWidth: CGFloat = 88
        static let spacing: CGFloat = 12
    }

    enum SkillsList {
        /// The list's share of the panel width; the pane takes the rest.
        static let widthFraction: CGFloat = 0.46
        static let orderLineHeight: CGFloat = 32
        static let orderLineInsets = EdgeInsets(top: 4, leading: 16, bottom: 0, trailing: 20)
        static let listInsets = EdgeInsets(top: 0, leading: 8, bottom: 16, trailing: 8)
    }

    enum LogoToggle {
        static let box: CGFloat = 24
        static let logo: CGFloat = 20
        static let badge: CGFloat = 10
        static let badgeGlyph: CGFloat = 6
        /// The ring in the ground colour around the badge.
        static let badgeRing: CGFloat = 1.5
        /// The badge's check: drawn in a 12 box, stroked 2.4 (the kit's `BADGE`).
        static let checkBox: CGFloat = 12
        static let checkStroke: CGFloat = 2.4
        /// Logos in a strip.
        static let spacing: CGFloat = 4
        /// A dim logo (not in that CLI), and a dim logo under the pointer (press to add).
        static let dimOpacity: Double = 0.35
        static let dimHoverOpacity: Double = 0.7
        /// The just-changed pop: the logo grows from this scale, the badge follows after `badgeDelay`.
        static let popFrom: CGFloat = 0.8
        static let badgeDelay: TimeInterval = 0.04
    }

    enum WarningSlot {
        static let size: CGFloat = 24
    }

    /// A stale reading's age at a band's right end: the clock 4 before the text.
    enum StaleNote {
        static let spacing: CGFloat = 4
    }

    /// The split canvas (V5-R52): below this width inside its 32 edge, the halves stack.
    enum SplitCanvas {
        static let stackBelow: CGFloat = 700
    }

    /// The Subagents spine row: the sessions text before the logos.
    enum Subagents {
        static let sessionsWidth: CGFloat = 96
    }

    /// The Activity page's row columns (`b-activity`): a session's project (112) and state (104), a failure's reason (up to 176)
    /// and its count and status.
    enum Activity {
        static let projectWidth: CGFloat = 112
        static let stateWidth: CGFloat = 104
        /// How far the two give way in a narrow window (V5-A22, 1062 wide): the session's title keeps the rest.
        static let projectMinWidth: CGFloat = 64
        static let stateMinWidth: CGFloat = 72
        static let reasonMaxWidth: CGFloat = 176
        static let timesWidth: CGFloat = 64
        static let statusWidth: CGFloat = 88
    }

    /// The Hooks spine row: the matcher before the logos (`b-hooks`: 96).
    enum Hooks {
        static let matcherWidth: CGFloat = 96
        /// The Answer's fix rows reach 4 past the card's padding, as the kit's `.fixes` does.
        static let fixesBleed: CGFloat = 4
        /// The footnote under the bands: 8 above it.
        static let noteTop: CGFloat = 8
    }

    /// The Rules page's columns (`b-rules`' page CSS).
    enum Rules {
        /// The two CLI columns: the column head, a band's extras and a rule row's verdict share this width (V5-R68).
        static let columnWidth: CGFloat = 168
        /// In a card too narrow for two 168 columns beside a readable rule name they give way down to this (narrow widths only), and
        /// `columnsReserved` is what the card keeps for the rule name, the row's padding, gaps and the card's edge.
        static let columnMinWidth: CGFloat = 72
        static let columnsReserved: CGFloat = 214
        /// A band's extras end where a row's last cell does: the header's trailing inset is wider than the row's by this much.
        static let extrasBleed: CGFloat = Band.trailing - ListRow.trailing
        /// The Answer's CLI rows reach 4 past the card's padding, as the kit's `.fixes` does.
        static let fixesBleed: CGFloat = Hooks.fixesBleed
        /// The Codex note under the bands: 12 above it.
        static let noteTop: CGFloat = 12
        /// The column head (the kit's `.ord`: 32 high with 4 above its content), and the gap between its logo and name.
        static let headHeight: CGFloat = 32
        static let headTop: CGFloat = 4
        static let headSpacing: CGFloat = 6
    }

    /// The Limits page's columns and gaps (`b-limits`' page CSS).
    enum Limits {
        /// A window row: the name column, and the least a bar keeps when the row is narrow.
        static let windowName: CGFloat = 128
        static let barMinWidth: CGFloat = 96
        /// A Next resets row: the time before the logo.
        static let resetTime: CGFloat = 72
        /// A Next resets row: the countdown slot before the time, held empty when nothing counts so no column moves (LC-R3).
        /// Fits "23:12:05".
        static let resetCountdown: CGFloat = 64
        /// The Source card: between its lines.
        static let sourceLineSpacing: CGFloat = 8
    }

    enum Menu {
        static let width: CGFloat = 208
        static let submenuWidth: CGFloat = 232
        static let padding: CGFloat = 4
        static let itemHeight: CGFloat = 28
        /// Inside an item: 8 at the sides, 8 between the glyph, the label and the end mark.
        static let itemPadding: CGFloat = 8
        static let itemSpacing: CGFloat = 8
        /// A heading ("Group by"): 8 on top, 8 at the sides, 4 below.
        static let headingInsets = EdgeInsets(top: 8, leading: 8, bottom: 4, trailing: 8)
        /// A menu opens this far below its button; a submenu sits this far beside the menu, its top this far above the
        /// menu's (the kit's `top:-5px` inside the 1 pt edge).
        static let gap: CGFloat = 4
        static let submenuRise: CGFloat = 4
        /// A field's count of picks: at least 16 x 16, 4 at the sides.
        static let countSize: CGFloat = 16
        static let countPadding: CGFloat = 4
    }

    enum Popover {
        static let width: CGFloat = 272
        static let padding: CGFloat = 12
        static let spacing: CGFloat = 12
        /// Kept this far inside the window when it is clamped.
        static let windowMargin: CGFloat = 8
        /// Below its anchor by this much; above it instead when its bottom would come closer than `bottomMargin` to the
        /// window's bottom edge (the kit's `popover.place`).
        static let offset: CGFloat = 6
        static let bottomMargin: CGFloat = 40
        /// The pointer opens it after resting this long on the anchor and closes it this long after leaving both.
        static let openDelay: Duration = .milliseconds(150)
        static let closeDelay: Duration = .milliseconds(100)
        /// The 120 ms rise: it starts this far below its place.
        static let rise: CGFloat = 2
        /// The detail head: the logo or glyph (20) 12 before the name; the sub line's dot (6) 6 before its text.
        static let headSpacing: CGFloat = 12
        static let dotSize: CGFloat = 6
        static let dotSpacing: CGFloat = 6
        /// A file path sits this much closer to the sentence above it (8 rather than 12).
        static let pathRise: CGFloat = 4
        /// Between the actions, and between a note's glyph (14) and its text.
        static let actionSpacing: CGFloat = 8
        static let noteSpacing: CGFloat = 8
    }

    /// The Skills detail pane.
    enum DetailPane {
        static let insets = EdgeInsets(top: 32, leading: 40, bottom: 40, trailing: 40)
        static let maxWidth: CGFloat = 640
        static let spacing: CGFloat = 24
        static let headTile: CGFloat = 48
        static let fileRowHeight: CGFloat = 32
        static let meterPadding: CGFloat = 16
        static let meterBarHeight: CGFloat = 8
        /// The head: the tile 16 before the name; the name 8 before the plugin tag.
        static let headSpacing: CGFloat = 16
        static let nameSpacing: CGFloat = 8
        /// The plugin tag: 20 high, 6 at the sides, the lock 12, 4 apart.
        static let tagHeight: CGFloat = 20
        static let tagPadding: CGFloat = 6
        static let tagSpacing: CGFloat = 4
        /// A section's label sits 8 above its content.
        static let sectionLabelSpacing: CGFloat = 8
        /// A meter: its parts 12 apart, the head's parts 8 apart; the count's unit 4 after it; an absent column's dash line
        /// keeps 4 above and below.
        static let meterSpacing: CGFloat = 12
        static let meterHeadSpacing: CGFloat = 8
        static let meterUnitGap: CGFloat = 4
        static let meterDashInset: CGFloat = 4
        /// A file row: 12 at the sides, the logo (14) 8 before the path.
        static let filePadding: CGFloat = 12
        static let fileSpacing: CGFloat = 8
        /// The buttons under the files, 8 apart.
        static let actionSpacing: CGFloat = 8
        /// The note under the buttons sits 12 below them.
        static let noteAbove: CGFloat = 12
    }

    /// The list column of the Skills split: the hairline between it and the pane.
    enum SkillsSplit {
        /// Where the bar floats: 48 above the panel's bottom edge, 16 above the status bar's top.
        static var barBottom: CGFloat { BottomBar.bottomInset - ContentPanel.statusBarHeight }
    }

    enum BottomBar {
        static let height: CGFloat = 44
        static let bottomInset: CGFloat = 48
        static let leading: CGFloat = 16
        static let trailing: CGFloat = 8
        static let spacing: CGFloat = 8
        /// After the "3 selected" count and before the "Add to" label, on top of `spacing`.
        static let countTrailing: CGFloat = 4
        static let labelLeading: CGFloat = 4
        /// The line between the strip and the buttons: 1 x 20, 4 more on each side.
        static let separatorHeight: CGFloat = 20
        static let separatorInset: CGFloat = 4
    }

    enum Toast {
        static let height: CGFloat = 40
        static let trailingInset: CGFloat = 24
        static let bottomInset: CGFloat = 48
        /// Above the bottom bar while one is shown.
        static let bottomInsetOverBar: CGFloat = 104
        static let leading: CGFloat = 12
        static let trailing: CGFloat = 8
        static let spacing: CGFloat = 12
        /// The `Undo` button: 24 high, 8 at the sides, 6 before its key cap.
        static let actionHeight: CGFloat = 24
        static let actionPadding: CGFloat = 8
        static let actionSpacing: CGFloat = 6
    }

    /// Buttons: 32 in the pane and the Answer card, 28 in a popover, a card header, the bottom bar and a dialog.
    enum ActionButton {
        static let height: CGFloat = 32
        static let compactHeight: CGFloat = 28
        static let leading: CGFloat = 12
        static let trailing: CGFloat = 8
        /// A 28 button in a popover or a card header starts 10 from its edge (the bottom bar's keeps 12).
        static let compactLeading: CGFloat = 10
        /// Between the glyph, the label and the key cap; a popover's button adds 2 before the cap.
        static let spacing: CGFloat = 8
        static let popoverKeyExtra: CGFloat = 2
        /// An icon-only button: 28 square.
        static let iconSide: CGFloat = 28
        /// Pressed, the button moves down this much.
        static let pressOffset: CGFloat = 0.5
        /// Disabled.
        static let disabledOpacity: Double = 0.45
        /// A solid button hovered or focused: the kit mixes 12% white into the fill; `ContrastTests` checks white on it.
        static let solidHoverBrightness: Double = 0.08
    }

    enum Dialog {
        static let width: CGFloat = 400
        static let insets = EdgeInsets(top: 20, leading: 20, bottom: 16, trailing: 20)
        static let spacing: CGFloat = 8
        static let actionsAbove: CGFloat = 12
        static let actionSpacing: CGFloat = 8
    }

    enum KeyCap {
        static let height: CGFloat = 18
        static let minWidth: CGFloat = 18
        /// The thicker bottom edge.
        static let bottomEdge: CGFloat = 2
        static let padding: CGFloat = 5
        /// Between two caps of one hint ("J K"), and between the caps and their word.
        static let spacing: CGFloat = 6
    }

    enum CommandPalette {
        static let width: CGFloat = 560
        static let fieldHeight: CGFloat = 48
        static let rowHeight: CGFloat = 32
        static let footerHeight: CGFloat = 32
        static let topInset: CGFloat = 112
        static let maxHeight: CGFloat = 480
        /// What the list may take: the card less the field and the footer.
        static let listMaxHeight: CGFloat = maxHeight - fieldHeight - footerHeight
        /// The field: 16 at the sides, 12 after the search glyph.
        static let fieldPadding: CGFloat = 16
        static let fieldSpacing: CGFloat = 12
        /// The list inside the card, then a row: 12 at the sides, 12 after the glyph.
        static let listPadding: CGFloat = 4
        static let rowPadding: CGFloat = 12
        static let rowSpacing: CGFloat = 12
        /// A group title: 8 on top, 12 at the sides, 4 below.
        static let headingInsets = EdgeInsets(top: 8, leading: 12, bottom: 4, trailing: 12)
        /// "No command found": 48 on top and below, 24 at the sides.
        static let emptyInsets = EdgeInsets(top: 48, leading: 24, bottom: 48, trailing: 24)
        /// The footer: 12 at the sides, 16 between its hints.
        static let footerPadding: CGFloat = 12
        static let footerSpacing: CGFloat = 16
    }

    /// Animation durations in seconds; reduced motion drops them (V5-R42).
    enum Motion {
        /// Hover, press and the popover's rise.
        static let quick: TimeInterval = 0.12
        static let logoPop: TimeInterval = 0.18
        /// A toast slides in and out.
        static let toast: TimeInterval = 0.2
        static let barWidth: TimeInterval = 0.15
        /// How long a pressed logo counts as just changed.
        static let flash: Duration = .milliseconds(600)
    }

    /// Overlay shadows, with `Palette.shadowPop` and `Palette.shadowDialog`.
    enum Shadow {
        static let popRadius: CGFloat = 32
        static let popOffset: CGFloat = 8
        static let dialogRadius: CGFloat = 64
        static let dialogOffset: CGFloat = 24
    }
}

/// The spacing scale. 2 and 6 are used only inside one component; between components the steps are 4 to 32.
enum Space {
    static let s2: CGFloat = 2
    static let s4: CGFloat = 4
    static let s6: CGFloat = 6
    static let s8: CGFloat = 8
    static let s12: CGFloat = 12
    static let s16: CGFloat = 16
    static let s24: CGFloat = 24
    static let s32: CGFloat = 32
}

/// The session glance widget (spec `docs/specs/2026-11-19-session-glance-widget.md`), read from the mock the owner picked
/// (`session-glance-widget.html`, GW20). Its placement lives in `GlanceLayout`.
extension Metrics {
    enum Glance {
        /// The strip: a capsule 4 inside its edge, entries 3 apart.
        static let stripPadding: CGFloat = 4
        static let entrySpacing: CGFloat = 3
        /// One entry: 22 high (22 wide in a column), 4 at its ends, the state glyph 3 before the CLI logo.
        static let entrySide: CGFloat = 22
        static let entryPadding: CGFloat = 4
        static let entryInnerSpacing: CGFloat = 3
        /// The strip's corner: half its height, so a row or a column reads as a capsule.
        static let stripRadius: CGFloat = entrySide / 2 + stripPadding
        /// `+N` after the sixth entry: 5 at its sides.
        static let overflowPadding: CGFloat = 5
        /// The faint SpaceVibe mark of an empty strip, 4 inside the entry's 22.
        static let markSize: CGFloat = 14
        static let markPadding: CGFloat = 4
        static let markOpacity: Double = 0.35
        /// Idle: a small dot in `mute`. Unmeasurable: the dashed circle in `mute`, faded (GW9).
        static let idleDot: CGFloat = 6
        static let idleOpacity: Double = 0.45
        static let unmeasurableOpacity: Double = 0.55
        /// The working ring: one turn a second, redrawn at most 30 times a second.
        static let spinPeriod: TimeInterval = 1
        static let spinFrame: TimeInterval = 1.0 / 30
        /// The hover list: 300 wide, 5 inside its edge, scrolling past 296 high.
        static let listWidth: CGFloat = 300
        static let listPadding: CGFloat = 5
        static let listMaxHeight: CGFloat = 296
        /// A list row: 7 above and below, 8 at the sides; its columns 9 apart, its two lines 1 apart.
        static let rowPadding = EdgeInsets(top: 7, leading: 8, bottom: 7, trailing: 8)
        static let rowColumnSpacing: CGFloat = 9
        static let rowLineSpacing: CGFloat = 1
        /// The state glyph 5 before its label; the host hint's glyph 4 before the app name, the name at most 96 wide.
        static let stateSpacing: CGFloat = 5
        static let hintSpacing: CGFloat = 4
        static let hintMaxWidth: CGFloat = 96
        /// "No session running" in the list.
        static let noteInsets = EdgeInsets(top: 12, leading: 10, bottom: 12, trailing: 10)
    }
}
