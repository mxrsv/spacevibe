import SwiftUI

/// The selected rule (the mock's `ruleInspector`): the Rules tone icon and "Rule", the rule whole in mono, its capability,
/// scope and file, the warning on a whole-tool allow, the Permission dial, and the actions. Nothing selected: the empty
/// state.
struct RulesInspector: View {
    let model: FrameModel
    let state: RulesPageState

    var body: some View {
        let list = RulesListModel.from(model.store, view: state.view, file: model.router.route.scope, query: model.search.query)
        if let row = list.row(model.router.route.selection) {
            let actions = RulesFrame.actions(for: row, list: list, state: state)
            VStack(alignment: .leading, spacing: SpaceRole.step16) {
                InspectorTitle("Rule") { FrameGlyph(.rules, side: SizeRole.icon20, ink: ColorRole.toneRules) }
                CommandBlock(row.rule.rule)
                KeyValueList(facts: Self.facts(row, list: list))
                if row.isWideAllow {
                    HStack(alignment: .firstTextBaseline, spacing: SpaceRole.step6) {
                        FrameGlyph(.warningFill, side: SizeRole.icon14, ink: ColorRole.stateAttention, label: "Needs attention")
                        Text(RulesWriteWording.wholeToolWarning)
                            .typeRole(.quiet)
                            .foregroundStyle(ColorRole.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                }
                InspectorSection("Permission") {
                    PermissionDial(selection: row.rule.verdict, label: "Permission") { verdict in
                        state.change(row.rule, to: verdict, fileName: list.fileName)
                    }
                    .disabled(!list.isWritable)
                }
                if !actions.isEmpty {
                    InspectorActions(actions: actions.map { action in
                        InspectorAction(id: action.id, title: action.title, icon: action.id == "remove" ? .trash : .question,
                                        isEnabled: action.isEnabled, perform: action.perform)
                    })
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        } else {
            PageEmptyState(icon: .sidebarSimple, text: "Select a rule to see its details.")
        }
    }

    /// Capability (by the engine's grid), Scope and File.
    static func facts(_ row: RulesRuleRow, list: RulesListModel) -> [InspectorFact] {
        [
            InspectorFact(key: "Capability", value: list.capability(of: row.rule)?.label ?? "No capability"),
            InspectorFact(key: "Scope", value: list.scopeTitle),
            InspectorFact(key: "File", value: list.fileName, isMono: true),
        ]
    }
}

/// `Add Rule…` (the mock's "not shown"): type `Tool` or `Tool(pattern)`, pick Allow, Ask or Deny, read the line it writes,
/// then write, with Undo after. A shape the engine refuses, or a rule already in the file, is said under the field and
/// nothing is written. The primary button is the sheet's one primary (RD11).
struct RulesAddSheet: View {
    let state: RulesPageState
    let draft: RulesAddDraft
    let fileName: String

    var body: some View {
        let text = Binding(get: { state.addDraft?.text ?? "" }, set: { value in
            state.addDraft?.text = value
            state.addDraft?.refusal = nil
        })
        let isEmpty = draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        DialogSheet(title: "Add Rule", note: RulesWriteWording.addPreview(draft.text, as: draft.verdict, to: fileName),
                    isWorking: draft.isChecking, cancel: { state.closeAdd() }) {
            VStack(alignment: .leading, spacing: SpaceRole.step12) {
                TextInputField(placeholder: "Bash(git log:*)", text: text, label: "Rule", isMono: true, message: draft.refusal) {
                    state.submitAdd(fileName: fileName)
                }
                PermissionDial(selection: draft.verdict, label: "Permission") { state.addDraft?.verdict = $0 }
            }
            .padding(.top, SpaceRole.step8)
        } confirm: {
            Button { state.submitAdd(fileName: fileName) } label: { Text("Add Rule").frame(maxWidth: .infinity) }
                .buttonStyle(PushButtonStyle(.primary, isLoading: draft.isChecking))
                .focusEffectDisabled()
                .disabled(isEmpty)
        }
    }
}

/// Another CLI's Rules page, read only in its own terms (the mock's `rc !== 'claude'` branch): the hero, the band when the
/// settings could not be read, `<CLI> permissions` with its settings as it names them, and where they were read from.
struct RulesReadOnlyList: View {
    let model: FrameModel
    let state: RulesPageState

    var body: some View {
        let list = RulesListModel.from(model.store, view: state.view, file: model.router.route.scope, query: model.search.query)
        SpaceVibeScrollView {
            VStack(alignment: .leading, spacing: SpaceRole.step12) {
                if let page = list.readOnly {
                    PageHero(page.hero, label: page.heroLabel)
                        .fixedSize()
                        .padding(.top, SpaceRole.step4)
                        .padding(.horizontal, SpaceRole.step8)
                        .padding(.bottom, SpaceRole.step8)
                    if let banner = page.banner {
                        StatusBanner(.problem(.attention), title: banner.title, detail: banner.detail) { RulesTryAgain(model: model) }
                    }
                    if !page.facts.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            GroupHead("\(page.cli.name) permissions")
                            KeyValueList(facts: page.facts, keyColumn: KeyValueList.wideKeyWidth)
                                .padding(SpaceRole.step16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .groupSurface()
                        }
                    }
                    VStack(alignment: .leading, spacing: SpaceRole.step6) {
                        ForEach(page.notes, id: \.self) { note in InspectorNote(note, icon: .infoFill) }
                        if let source = page.source { InspectorNote(source, icon: .infoFill) }
                    }
                    .padding(.vertical, SpaceRole.step12)
                    .padding(.horizontal, SpaceRole.step8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }
}
