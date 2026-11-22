import SwiftUI
import Testing
@testable import SpaceVibe

/// The pure rules under the redesign's in-page blocks (RB-S4): the tile grid's shape and heat (RD-R12), the logo toggle's
/// states (RD-R11, RD-R16), the row strip, arrow-key selection (RD39) and the pick menus (RD-R10).
@Suite("Frame blocks: grid, heat, toggles, selection, menus")
struct FrameBlockLogicTests {
    // MARK: Tile grid

    @Test("the tile grid has max(3, ceil(N/3)) columns and never more than 3 rows", arguments: 1 ... 12)
    func gridShape(count: Int) {
        let columns = CLITileGridLayout.columns(count)
        #expect(columns == max(3, Int((Double(count) / 3).rounded(.up))))
        #expect(CLITileGridLayout.rows(count) <= 3)
        #expect(CLITileGridLayout.rows(count) == Int((Double(count) / Double(columns)).rounded(.up)))
        let lines = CLITileGridLayout.lines(count)
        #expect(lines.count == CLITileGridLayout.rows(count))
        #expect(lines.flatMap { $0 } == Array(0 ..< count), "every CLI once, in the fixed order")
        #expect(lines.allSatisfy { $0.count <= columns })
    }

    @Test("the mock's grids: 2 CLIs one row, 6 CLIs 3 × 2, 10 CLIs 4 × 3 at 306 pt")
    func gridExamples() {
        #expect(CLITileGridLayout.rows(2) == 1 && CLITileGridLayout.columns(2) == 3)
        #expect(CLITileGridLayout.rows(6) == 2 && CLITileGridLayout.columns(6) == 3)
        #expect(CLITileGridLayout.rows(10) == 3 && CLITileGridLayout.columns(10) == 4)
        #expect(CLITileGridLayout.width(10) == 306, "the mock's `.tiles` at --cols 4")
        #expect(CLITileGridLayout.rows(0) == 0 && CLITileGridLayout.lines(0).isEmpty)
    }

    // MARK: Heat

    @Test("heat steps are relative to the item's top CLI: 0, up to 25%, up to 60%, above")
    func heatSteps() {
        #expect(HeatStep.step(sessions: 0, top: 40) == .none)
        #expect(HeatStep.step(sessions: 10, top: 40) == .low)
        #expect(HeatStep.step(sessions: 11, top: 40) == .middle)
        #expect(HeatStep.step(sessions: 24, top: 40) == .middle)
        #expect(HeatStep.step(sessions: 25, top: 40) == .high)
        #expect(HeatStep.step(sessions: 40, top: 40) == .high)
        #expect(HeatStep.step(sessions: 3, top: 0) == .high, "a lone count is its own top")
        #expect(HeatStep.step(sessions: -2, top: 40) == .none)
    }

    @Test("only measured sessions of a lit logo count; Never ran, Unmeasurable, off and Not supported sit on step 0")
    func heatFromStates() {
        let states = [
            CLIToggleState(cli: .claude, presence: .on(.sessions(40))),
            CLIToggleState(cli: .codex, presence: .on(.sessions(14))),
            CLIToggleState(cli: id("a"), presence: .on(.unmeasurable)),
            CLIToggleState(cli: id("b"), presence: .on(.neverRan)),
            CLIToggleState(cli: id("c"), presence: .off),
            CLIToggleState(cli: id("d"), presence: .notSupported(noun: "Skills")),
            CLIToggleState(cli: id("e"), presence: .on(.sessions(4_830_112)), hold: .via(["Claude Code"])),
        ]
        let steps = HeatStep.steps(states)
        #expect(steps == [.low, .low, .none, .none, .none, .none, .high], "the huge via count is the top")
        #expect(HeatStep.steps([]).isEmpty)
    }

    // MARK: Buttons on the frame's material (AR8)

    @Test("in Glass the 32 controls and the icon buttons sit on glass with no resting fill or edge; Solid keeps the fill")
    func buttonsOnGlass() {
        let icon = PushButtonStyle(.icon), closeIcon = PushButtonStyle(.icon, size: .small)
        let control = PushButtonStyle(.control), rowButton = PushButtonStyle(.control, size: .small)
        #expect(icon.isOnGlass(.glass) && closeIcon.isOnGlass(.glass) && control.isOnGlass(.glass))
        #expect(!rowButton.isOnGlass(.glass), "a row button (`.rb`) keeps its fill")
        #expect(!PushButtonStyle(.primary).isOnGlass(.glass) && !PushButtonStyle(.destructive).isOnGlass(.glass))
        #expect([icon, closeIcon, control, rowButton].allSatisfy { !$0.isOnGlass(.solid) })
        #expect(icon.fill(hovered: false, pressed: false, enabled: true, onGlass: true) == nil)
        #expect(icon.fill(hovered: true, pressed: false, enabled: true, onGlass: true) == ColorRole.controlHoverFill)
        #expect(icon.fill(hovered: true, pressed: true, enabled: true, onGlass: true) == ColorRole.controlPressedFill)
        #expect(icon.fill(hovered: true, pressed: false, enabled: false, onGlass: true) == nil)
        #expect(icon.fill(hovered: false, pressed: false, enabled: true) == ColorRole.controlFill)
        // On glass the only edge is the Increase Contrast one (DS-R1: control fills take a `hair` outline under IC).
        #expect(icon.edge(enabled: true, onGlass: true) == ColorRole.controlEdge && icon.edge(enabled: true) == ColorRole.hairline)
        #expect(ColorRoleValues.controlEdge.dark.alpha == 0 && ColorRoleValues.controlEdge.light.alpha == 0)
        #expect(ColorRoleValues.controlEdge.darkIncreased == ColorRoleValues.hairline.darkIncreased)
        // A disabled destructive's label is the quiet control ink, which keeps its ratio on the fill under IC.
        #expect(PushButtonStyle(.destructive).ink(hovered: false, enabled: false) == ColorRole.controlQuietInk)
    }

    @Test("one segmented control: the small size is the mock's `.age`/`.dial` in both looks, never on glass (DS-R8, RB-F3)")
    func smallSegmentedControl() {
        typealias S = FrameSegmentedControl.Size
        for look in [MaterialLook.glass, .solid] {
            #expect(S.small.trackCorner(look) == .radius(8) && S.small.segmentCorner(look) == .radius(6), "\(look)")
            #expect(!S.small.isOnGlass(look), "\(look)")
        }
        #expect(S.regular.isOnGlass(.glass) && !S.regular.isOnGlass(.solid))
        #expect(S.regular.trackCorner(.glass) == .capsule && S.regular.segmentCorner(.solid) == .radius(4))
        #expect(S.small.typeRole(chosen: false) == .quiet && S.small.typeRole(chosen: true) == .quietMedium)
        #expect(S.regular.typeRole(chosen: false) == .bodyMedium && S.regular.typeRole(chosen: true) == .bodyMedium)
        #expect(FrameSegmentedControl.edge(size: .regular, look: .solid) == ColorRole.hairline)
        #expect(FrameSegmentedControl.edge(size: .small, look: .solid) == ColorRole.controlEdge)
        #expect(FrameSegmentedControl.edge(size: .regular, look: .glass) == ColorRole.controlEdge)
        #expect(!FrameSegmentedControl.takesPress(pending: "ask") && FrameSegmentedControl.takesPress(pending: nil))
        // The permission dial is that control: the same three steps, the pending rule shared.
        #expect(PermissionDial.segments.map(\.id) == ["allow", "ask", "deny"])
        #expect(!PermissionDial.takesPress(pending: .ask) && PermissionDial.takesPress(pending: nil))
    }

    @Test("RD49: one opacity per job; an Off logo fades the same on a row's toggle and on a tile")
    func fadeRoles() {
        typealias F = CLIToggleState.Fade
        #expect(F.dim.opacity(hovered: false) == OpacityRole.dim && F.dim.opacity(hovered: true) == 1)
        #expect(F.disabled.opacity(hovered: true) == OpacityRole.disabled && F.ghost.opacity(hovered: true) == OpacityRole.ghost)
        #expect(CLIToggleState(cli: .codex, presence: .unreadable).fade == .disabled)
        #expect(CLIToggleState(cli: .codex, presence: .off, hold: .noCopyTarget(folder: "skills")).fade == .disabled)
    }

    // MARK: Logo toggle states

    @Test("which states are toggles: on and off write; via, last copy, plugin, Not supported, unreadable and pending do not")
    func toggleEnabled() {
        func state(_ presence: CLIToggleState.Presence, _ hold: CLIToggleState.Hold = .none) -> CLIToggleState {
            CLIToggleState(cli: .codex, presence: presence, hold: hold)
        }
        #expect(state(.on(.sessions(3))).isToggle)
        #expect(state(.on(.neverRan)).isToggle)
        #expect(state(.on(.unmeasurable)).isToggle)
        #expect(state(.off).isToggle)
        #expect(!state(.off, .readOnly(owner: "plugin")).isToggle, "a plugin's item cannot be added either")
        #expect(!state(.off, .noCopyTarget(folder: "skills")).isToggle, "no folder to copy into: Add would be refused")
        #expect(!state(.on(.sessions(3)), .via(["Claude Code"])).isToggle, "RD31")
        #expect(!state(.on(.sessions(3)), .lastCopy).isToggle, "D53")
        #expect(!state(.on(.sessions(3)), .readOnly(owner: "plugin")).isToggle)
        #expect(!state(.notSupported(noun: "Skills")).isToggle)
        #expect(!state(.unreadable).isToggle)
        #expect(!state(.on(.pending)).isToggle)
    }

    @Test("every state has a label for VoiceOver: on, off, via, only copy, Unmeasurable, Not supported (RD-R16)")
    func toggleLabels() {
        let claude = CLIIdentity.claude
        #expect(CLIToggleState(cli: claude, presence: .on(.sessions(31))).spokenState == "On, 31 sessions")
        #expect(CLIToggleState(cli: claude, presence: .on(.sessions(1))).spokenState == "On, 1 session")
        #expect(CLIToggleState(cli: claude, presence: .on(.sessions(2)), sharedWith: ["Cursor CLI", "Amp"]).spokenState
            == "On, 2 sessions, shared file with Cursor CLI and Amp")
        #expect(CLIToggleState(cli: claude, presence: .off).spokenState == "Off, click to add")
        #expect(CLIToggleState(cli: claude, presence: .on(.neverRan), hold: .via(["Codex"])).spokenState
            == "On, never ran here, via Codex’s folder; remove it with Remove…")
        #expect(CLIToggleState(cli: claude, presence: .on(.sessions(24)), hold: .lastCopy).spokenState
            == "On, 24 sessions, only copy; remove it with Remove…")
        #expect(CLIToggleState(cli: claude, presence: .on(.unmeasurable)).spokenState == "On, sessions Unmeasurable (no log)")
        #expect(CLIToggleState(cli: claude, presence: .unreadable).spokenState == "Unmeasurable, folder could not be read")
        let amp = CLIToggleState(cli: id("amp", "Amp"), presence: .notSupported(noun: "Subagents"))
        #expect(amp.spokenState == "Not supported")
        #expect(amp.tooltip == "Amp has no Subagents")
        #expect(CLIToggleState(cli: claude, presence: .on(.sessions(4)), hold: .readOnly(owner: "design-kit plugin")).tooltip
            == "Claude Code: On, 4 sessions, read-only (design-kit plugin)")
    }

    @Test("marks: the Never ran dot only on the owning CLI, lock, link, ?, the last-copy bar, the tile check")
    func toggleMarks() {
        #expect(CLIToggleState(cli: .codex, presence: .on(.neverRan)).showsNeverRanDot)
        #expect(!CLIToggleState(cli: .codex, presence: .on(.neverRan), ownsFile: false).showsNeverRanDot, "RD16")
        #expect(!CLIToggleState(cli: .codex, presence: .on(.sessions(2))).showsNeverRanDot)
        #expect(CLIToggleState(cli: .codex, presence: .on(.sessions(2)), hold: .readOnly(owner: "plugin")).badge == .lock)
        #expect(CLIToggleState(cli: .codex, presence: .off, hold: .readOnly(owner: "plugin")).badge == nil,
                "an off logo or tile of a plugin's item carries no lock (mock tglBtn, tileInspector)")
        #expect(!CLIToggleState(cli: .codex, presence: .off, hold: .readOnly(owner: "plugin")).isToggle)
        #expect(CLIToggleState(cli: .codex, presence: .on(.sessions(2)), hold: .via(["Claude Code"])).badge == .link)
        #expect(CLIToggleState(cli: .codex, presence: .unreadable).badge == .unknown)
        #expect(CLIToggleState(cli: .codex, presence: .on(.sessions(2))).badge == nil, "a lit logo is the full logo (RD22)")
        #expect(CLIToggleState(cli: .codex, presence: .on(.sessions(2)), hold: .lastCopy).showsLastCopyBar)
        #expect(CLIToggleState(cli: .codex, presence: .on(.sessions(2))).showsCheck)
        #expect(CLIToggleState(cli: .codex, presence: .on(.neverRan)).showsCheck, "Never ran is on: dot and check")
        #expect(!CLIToggleState(cli: .codex, presence: .on(.sessions(2)), hold: .readOnly(owner: "plugin")).showsCheck)
        #expect(!CLIToggleState(cli: .codex, presence: .off).showsCheck)
        #expect(CLIToggleState(cli: .codex, presence: .off).fade == .dim)
        #expect(CLIToggleState(cli: .codex, presence: .notSupported(noun: "Skills")).fade == .ghost)
        #expect(!CLIToggleState(cli: .codex, presence: .notSupported(noun: "Skills")).drawsLogo)
    }

    @Test("a tile's figure: compact counts, 0 for Never ran, ? for Unmeasurable, Add when off, a dash when Not supported")
    func tileFigures() {
        #expect(CLIToggleState(cli: .claude, presence: .on(.sessions(4_830_112))).tileFigure == "4.8M")
        #expect(CLIToggleState(cli: .claude, presence: .on(.sessions(1_204))).tileFigure == "1,204")
        #expect(CLIToggleState(cli: .claude, presence: .on(.neverRan)).tileFigure == "0")
        #expect(CLIToggleState(cli: .claude, presence: .on(.unmeasurable)).tileFigure == "?")
        #expect(CLIToggleState(cli: .claude, presence: .on(.pending)).tileFigure == "…")
        #expect(CLIToggleState(cli: .claude, presence: .off).tileFigure == "Add")
        #expect(CLIToggleState(cli: .claude, presence: .notSupported(noun: "Skills")).tileFigure == "—")
        // The `?` is the question glyph on an unreadable CLI's (dashed) tile and on a lit one that keeps no log.
        #expect(CLIToggleState(cli: .codex, presence: .unreadable).tileFigureIsUnknown)
        #expect(CLIToggleState(cli: .codex, presence: .on(.unmeasurable)).tileFigureIsUnknown)
        #expect(!CLIToggleState(cli: .codex, presence: .off).tileFigureIsUnknown)
        #expect(!CLIToggleState(cli: .codex, presence: .on(.sessions(3))).tileFigureIsUnknown)
    }

    @Test("a row's toggles wrap at 5 per line; the row is the wrapped height from the 6th CLI")
    func toggleStrip() {
        #expect(CLIToggleStrip.columns(2) == 2 && CLIToggleStrip.lines(2) == [[0, 1]])
        #expect(CLIToggleStrip.columns(10) == 5 && CLIToggleStrip.lines(10).count == 2)
        #expect(CLIToggleStrip.lines(6) == [[0, 1, 2, 3, 4], [5]])
        #expect(CLIToggleStrip.rowHeight(5) == .table && CLIToggleStrip.rowHeight(6) == .tableWrapped)
        #expect(ItemRowHeight.table.points == 48 && ItemRowHeight.tableWrapped.points == 60 && ItemRowHeight.list.points == 44)
        #expect(CLIToggleStrip.lines(0).isEmpty)
    }

    // MARK: Selection, checkbox, menus

    @Test("↑↓ and j/k move the selection, clamped at the ends; nothing or a vanished row starts at the first")
    func listSelection() {
        let ids = ["a", "b", "c"]
        #expect(ListSelection.moved(.next, from: "a", in: ids) == "b")
        #expect(ListSelection.moved(.next, from: "c", in: ids) == "c")
        #expect(ListSelection.moved(.previous, from: "a", in: ids) == "a")
        #expect(ListSelection.moved(.previous, from: "c", in: ids) == "b")
        #expect(ListSelection.moved(.next, from: nil, in: ids) == "a")
        #expect(ListSelection.moved(.previous, from: "gone", in: ids) == "a")
        #expect(ListSelection.moved(.next, from: "a", in: []) == nil)
        #expect(ListSelection.Move(key: .downArrow) == .next && ListSelection.Move(key: KeyEquivalent("j")) == .next)
        #expect(ListSelection.Move(key: .upArrow) == .previous && ListSelection.Move(key: KeyEquivalent("k")) == .previous)
        #expect(ListSelection.Move(key: .return) == nil, "Return opens the inspector; the list keys never do")
    }

    @Test("the header checkbox: off for none, mixed for some, on for all; a box reads its state")
    func checkbox() {
        #expect(CheckboxValue.header(ticked: 0, total: 4) == .off)
        #expect(CheckboxValue.header(ticked: 2, total: 4) == .mixed)
        #expect(CheckboxValue.header(ticked: 4, total: 4) == .on)
        #expect(CheckboxValue.header(ticked: 0, total: 0) == .off)
        #expect(CheckboxValue.mixed.next == .on && CheckboxValue.on.next == .off)
        #expect(CheckboxValue.mixed.spoken == "partly checked")
    }

    @Test("All CLIs lists every CLI after All, a CLI without the concept disabled as Not supported")
    func scopeMenu() {
        let options = [CLIMenuEntries.Option(cli: .claude), .init(cli: .codex), .init(cli: id("aider", "Aider"), isSupported: false)]
        let entries = CLIMenuEntries.scope(options, scope: nil)
        #expect(entries.map(\.id) == ["all", "claude", "codex", "aider"])
        #expect(entries[0].isChosen && entries[0].note == "3")
        #expect(!entries[3].isEnabled && entries[3].note == "Not supported")
        #expect(CLIMenuEntries.scope(options, scope: "codex").filter(\.isChosen).map(\.id) == ["codex"])
        #expect(CLIMenuEntries.scopeTitle(options, scope: nil) == "All CLIs")
        #expect(CLIMenuEntries.scopeTitle(options, scope: "codex") == "Codex")
        let picker = CLIMenuEntries.picker([.init(cli: .claude), .init(cli: .codex, isReadOnly: true)], chosen: "claude")
        #expect(picker.map(\.note) == [nil, "Read only"])
    }

    @Test("menu keys move over enabled lines only, wrapping, starting at the chosen line")
    func menuKeys() {
        let entries = [
            MenuPanelEntry(id: "all", title: "All CLIs"), MenuPanelEntry(id: "x", title: "X", isEnabled: false),
            MenuPanelEntry(id: "codex", title: "Codex", isChosen: true),
        ]
        #expect(MenuPanelKeys.start(entries) == "codex")
        #expect(MenuPanelKeys.step(from: "all", by: 1, in: entries) == "codex", "the disabled line is skipped")
        #expect(MenuPanelKeys.step(from: "codex", by: 1, in: entries) == "all", "wraps")
        #expect(MenuPanelKeys.step(from: "all", by: -1, in: entries) == "codex")
        #expect(MenuPanelKeys.step(from: nil, by: 1, in: entries) == "codex")
        #expect(MenuPanelKeys.step(from: "all", by: 1, in: [MenuPanelEntry(id: "x", title: "X", isEnabled: false)]) == nil)
    }

    @Test("names join for sentences; short names drop CLI and Code")
    func names() {
        #expect(CLINames.sentence(["Codex"]) == "Codex")
        #expect(CLINames.sentence(["Codex", "Amp"]) == "Codex and Amp")
        #expect(CLINames.sentence(["Codex", "Cursor CLI", "Amp"]) == "Codex, Cursor CLI and Amp")
        #expect(CLINames.sentence([String]()) == "")
        #expect(CLIIdentity.claude.shortName == "Claude")
        #expect(id("cursor", "Cursor CLI").shortName == "Cursor" && id("qwen", "Qwen Code").shortName == "Qwen")
        #expect(id("amp", "Amp").shortName == "Amp")
        #expect(CLILogo.initial("opencode") == "O" && CLILogo.initial("") == "?")
        #expect(CLILogo.brandMark("claude") == .claude && CLILogo.brandMark("cursor") == nil)
    }

    @Test("every illustration CLI draws the mock's mark inside its 24 pt box; the brand CLIs have no such mark (RD46)")
    func illustrationMarks() {
        let ids = ["cursor", "copilot", "opencode", "amp", "antigravity", "kiro", "qwen", "aider"]
        #expect(Set(IllustrationCLIMark.allCases.map(\.rawValue)) == Set(ids))
        let box = CGRect(x: 0, y: 0, width: GlyphBox.side, height: GlyphBox.side).insetBy(dx: -0.5, dy: -0.5)
        for mark in IllustrationCLIMark.allCases {
            let bounds = mark.path.boundingRect
            #expect(!mark.path.isEmpty && bounds.width > 10 && bounds.height > 10, "\(mark)")
            #expect(box.contains(bounds), "\(mark) leaves its box: \(bounds)")
        }
        // The outline marks have a hole the even-odd fill keeps open (the mock's `fill-rule="evenodd"`).
        for mark in [IllustrationCLIMark.cursor, .amp, .kiro, .qwen] {
            #expect(!mark.path.contains(CGPoint(x: 12, y: 12), eoFill: true), "\(mark)")
        }
        for id in ["claude", "codex", "gemini"] { #expect(IllustrationCLIMark(rawValue: id) == nil) }
    }

    @Test("an inspector's action column: 32 pt, body text at 400, 12 from the leading edge, whatever the kind")
    func inspectorColumn() {
        for kind in [PushButtonStyle.Kind.control, .destructive, .quiet] {
            let style = PushButtonStyle(kind, size: .column)
            #expect(style.size.height == SizeRole.controlRegular)
            #expect(style.typeRole == .bodyText, "\(kind)")
            #expect(style.sidePadding == SpaceRole.step12, "\(kind)")
        }
        #expect(PushButtonStyle(.control, size: .small).size.height == SizeRole.controlSmall)
        #expect(PushButtonStyle(.destructive, size: .small).typeRole == .quietMedium)
    }

    @Test("a group head reads severity, title and count; the hero reads its figure and label")
    func spokenHeads() {
        #expect(GroupHead<EmptyView>.spoken(title: "Clean up", count: 6, severity: .critical) == "Critical, Clean up, 6")
        #expect(GroupHead<EmptyView>.spoken(title: "Balance", count: nil, severity: .none) == "Balance")
        #expect(GroupSeverity.critical.icon == .xCircleFill && GroupSeverity.attention.icon == .warningFill && GroupSeverity.none.icon == nil)
        #expect(SelectSuggestedButton.title(1_204) == "Select 1,204 Suggested")
        #expect(PageHero.spoken(.value("780", unit: "MB"), label: "can be cleaned") == "780 MB, can be cleaned")
        #expect(PageHero.spoken(.clear("Clear"), label: "Nothing needs you") == "Clear, Nothing needs you")
        #expect(PageHero.spoken(.scanning, label: "never ran") == "Scanning, never ran")
    }

    @Test("a meter clamps its share and tick, and says Unmeasurable for an unknown share")
    func meter() {
        #expect(ShareMeter.clamped(1.4) == 1 && ShareMeter.clamped(-1) == 0 && ShareMeter.clamped(.nan) == 0)
        #expect(ShareMeter.spokenValue(0.384) == "38%" && ShareMeter.spokenValue(nil) == "Unmeasurable")
        #expect(ShareMeter.tickOffset(1, width: 100) == 98, "the tick stays inside the track")
        #expect(ShareMeter.tickOffset(0, width: 100) == 0)
        #expect(ShareMeter.tickOffset(0.5, width: 100) == 49)
    }

    // MARK: RB-F1 shared fixes

    @Test("the focus bar shows for the control's own focus only: a focused list, inspector or dialog around it lights nothing")
    func focusBarOwnFocus() {
        // The region around a button is focused, keyboard navigation off: `\.isFocused` reads true for every button inside,
        // and the old blocks drew the bar on all of them at once (the owner's 2026-11-22 shot).
        #expect(!FocusBarRule.buttonOwnsFocus(environmentFocus: true, keyboardNavigation: false))
        #expect(FocusBarRule.buttonOwnsFocus(environmentFocus: true, keyboardNavigation: true), "the button itself is focused")
        #expect(!FocusBarRule.buttonOwnsFocus(environmentFocus: false, keyboardNavigation: true))
        #expect(FocusBarRule.isShown(ownFocus: true) && !FocusBarRule.isShown(ownFocus: false))
        #expect(FocusBarRule.isShown(ownFocus: false, specimen: true), "the gallery's focus state")
        #expect(!FocusBarRule.isShown(ownFocus: true, isEnabled: false), "never on a disabled control")
    }

    @Test("the focus bar sits at the control's leading edge, 3 pt wide and full height, at every size and corner")
    func focusBarAtTheEdge() {
        // The old bar was inset by half the height on a capsule (16 pt on a 32 control), across the label.
        for size in [CGSize(width: 120, height: SizeRole.controlRegular), CGSize(width: 80, height: SizeRole.controlSmall),
                     CGSize(width: 28, height: SizeRole.hitCell)] {
            let bar = FocusBarRule.barRect(in: size)
            #expect(bar.minX == 0 && bar.width == SizeRole.focusBar && bar.height == size.height)
        }
    }

    @Test("a row inserts nothing on selection without actions; with actions its trailing cell has one width selected or not")
    func itemRowCellNeverMoves() {
        #expect(ItemRowLayout.actionsCellWidth(nil) == nil, "no actions: no cell, selected or not")
        #expect(ItemRowLayout.actionsCellWidth(TableColumnWidth.action) == TableColumnWidth.action)
        #expect(ItemRowLayout.fillsActions(isSelected: true) && !ItemRowLayout.fillsActions(isSelected: false))
        #expect(FindingRowLayout.actionsWidth == TableColumnWidth.action, "Inbox's action column is the tables' fixed one")
    }

    @Test("Select N Suggested and Clear Selection are the neutral small control button, never a link")
    func groupHeadPicks() {
        #expect(SelectSuggestedButton.kind == .control)
        #expect(ClearSelectionButton.title == "Clear Selection")
        #expect(PushButtonStyle(SelectSuggestedButton.kind, size: .small).typeRole == .quietMedium, "the mock's `.rb`: 12 pt at 500")
    }

    @Test("a table head is pinned over its rows, never in a headless shot and never on a list without a head")
    func stickyHead() {
        #expect(RowGroup<Text, EmptyView>.pinsHead(hasHead: true, isShotRendering: false))
        #expect(!RowGroup<Text, EmptyView>.pinsHead(hasHead: true, isShotRendering: true))
        #expect(!RowGroup<EmptyView, EmptyView>.pinsHead(hasHead: false, isShotRendering: false))
    }

    @Test("the segmented control comes in the two DS-R5 sizes, and ← → step without wrapping")
    func segmentedSizes() {
        typealias S = FrameSegmentedControl.Size
        #expect(S.regular.track == 32 && S.regular.segment == 28)
        #expect(S.small.track == 26 && S.small.segment == 22)
        let segments = [FrameSegment(id: "a", title: "A"), FrameSegment(id: "b", title: "B"), FrameSegment(id: "c", title: "C")]
        #expect(FrameSegmentedControl.step(from: "b", by: -1, in: segments) == "a")
        #expect(FrameSegmentedControl.step(from: "c", by: 1, in: segments) == "c")
    }

    @Test("the switch's light Off knob carries the shadow that keeps it visible, disabled too; nothing else does")
    func switchKnobShadow() {
        // The shadow is a colour role, clear in dark, so the switch never branches on the theme (RB-F3).
        #expect(FrameSwitch.knobShadow(isOn: false) == ColorRole.switchKnobOffShadow && FrameSwitch.knobShadow(isOn: true) == .clear)
        #expect(ColorRoleValues.switchKnobOffShadow.light.alpha > 0 && ColorRoleValues.switchKnobOffShadow.dark.alpha == 0)
    }

    private func id(_ value: String, _ name: String? = nil) -> CLIIdentity { CLIIdentity(id: value, name: name ?? value) }
}
