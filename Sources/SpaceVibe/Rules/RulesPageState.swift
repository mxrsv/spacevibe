import AppKit
import Foundation
import Observation

/// The Add Rule sheet's draft (the mock's "not shown": type Tool or Tool(pattern), pick Allow, Ask or Deny, see the line
/// it writes, then write; Undo after).
struct RulesAddDraft: Equatable, Sendable {
    /// The file the sheet was opened for: the write goes there even if the page moved.
    let file: FrameScope
    var text = ""
    var verdict = CoreVerdict.ask
    /// The core's refusal (an invalid shape, a rule already in the file), shown under the field.
    var refusal: String?
    var isChecking = false
    /// `FrameRouter.revision` when it opened: another page or an outside route since closes it, so it never comes back.
    var routeRevision = 0
}

/// The Rules page's own state while the frame shows it (AR3): the CLI page, the ticks, the open menus, the capability
/// preview and the Add Rule sheet. The list, the toolbar and the inspector are separate views the frame places, so they
/// share this one object, one per `FrameModel` (`FrameModel.pageState`). Every write goes through `FrameWrites` (AR4); the
/// file is the route's scope (AR5).
@MainActor
@Observable
final class RulesPageState {
    var view = RulesViewState()
    var isCLIMenuOpen = false
    var isProjectMenuOpen = false
    private(set) var preview: RulesPreviewRequest?
    var addDraft: RulesAddDraft?
    /// Verdict changes under way, by their write control: what each is writing.
    private(set) var changing: [String: CoreVerdict] = [:]
    /// Capability changes under way, by file and capability (`capabilityKey`): the verdict each is writing, for the dial's
    /// pending step (FE-L2).
    private(set) var capabilityChanging: [String: CoreVerdict] = [:]

    @ObservationIgnored private weak var model: FrameModel?
    /// The project the Project scope opens on: the one shown last.
    @ObservationIgnored private var lastProject: String?
    /// Bumped by every preview request and file switch, so a preview that answers late is dropped.
    @ObservationIgnored private var previewEpoch = 0

    init(model: FrameModel? = nil) {
        self.model = model
    }

    static func of(_ model: FrameModel) -> RulesPageState {
        model.pageState(RulesPageState.self) { RulesPageState(model: model) }
    }

    var file: FrameScope { model?.router.route.scope ?? .global }

    func list(now: Date = Date()) -> RulesListModel? {
        guard let model else { return nil }
        return RulesListModel.from(model.store, view: view, file: file, query: model.search.query, now: now)
    }

    // MARK: View state

    func pick(cli id: String) {
        isCLIMenuOpen = false
        guard id != view.cli else { return }
        view.cli = id
        view.ticked = []
        closePreview()
    }

    /// Global or Project (the toolbar's segmented control). Project opens on the last project shown, else the first known;
    /// with none known the page says so and the route keeps the global file.
    func pick(scopeIsProject: Bool, projects: [RulesProject]) {
        guard let model else { return }
        if !scopeIsProject {
            view.wantsProjects = false
            show(.global, model: model)
            return
        }
        guard let dir = projects.first(where: { $0.dir == lastProject })?.dir ?? projects.first?.dir else {
            view.wantsProjects = true
            show(.global, model: model)
            return
        }
        view.wantsProjects = false
        show(.shared(dir), model: model)
    }

    /// A project from the project menu, keeping the Shared or Local file shown.
    func pick(project dir: String) {
        isProjectMenuOpen = false
        guard let model else { return }
        show(file.scope == .local ? .local(dir) : .shared(dir), model: model)
    }

    /// Shared (`settings.json`) or Local (`settings.local.json`) of the project shown.
    func pick(local: Bool) {
        guard let model, let dir = file.dir else { return }
        show(local ? .local(dir) : .shared(dir), model: model)
    }

    private func show(_ next: FrameScope, model: FrameModel) {
        guard next != file else { return }
        if let dir = next.dir { lastProject = dir }
        view.ticked = []
        closePreview()
        model.router.setScope(next)
    }

    func toggle(_ id: String) {
        if view.ticked.contains(id) { view.ticked.remove(id) } else { view.ticked.insert(id) }
    }

    /// The header box: every row shown when not all are ticked, none when all are.
    func toggleAll(_ ids: [String]) {
        view.ticked = ids.allSatisfy(view.ticked.contains) ? [] : Set(ids)
    }

    // MARK: Capability preview

    /// A press on a capability's dial. Nothing is written: `rules.preview` says what would change, the popover shows it.
    /// The same press again closes it. A same-value press still previews: it reads "Nothing to change" and writes nothing.
    func requestPreview(_ row: RulesCapabilityRow, to verdict: CoreVerdict) {
        guard let model, row.isEditable, pendingCapability(row.id) == nil else { return }
        if let preview, preview.capability == row.id, preview.verdict == verdict, preview.file == file {
            closePreview()
            return
        }
        let request = RulesPreviewRequest(file: file, capability: row.id, verdict: verdict)
        preview = request
        previewEpoch += 1
        let epoch = previewEpoch
        Task { @MainActor in
            let phase: RulesPreviewRequest.Phase
            do { phase = .ready(try await model.writes.preview(request.capability, to: verdict, in: request.file)) } catch {
                phase = .failed(AppEnvironment.message(error))
            }
            guard epoch == previewEpoch, preview?.file == request.file else { return }
            preview?.phase = phase
        }
    }

    func closePreview() {
        previewEpoch += 1
        preview = nil
    }

    /// `Change to …` in the popover: `rules.setCapability` on the file the preview was made for. A preview that says
    /// "Nothing to change" writes nothing.
    func confirmPreview(_ row: RulesCapabilityRow, fileName: String) {
        guard let model, let request = preview, case .ready(let answer) = request.phase else { return }
        let text = RulesPreviewText(row: row, preview: answer, fileName: fileName)
        closePreview()
        guard !text.isNothing, request.file == file else { return }
        // Pending before this returns (`FrameWrites.start`): the dial shows the step it is moving to and takes no press until
        // the write is done.
        let write = FrameWrite.setCapability(request.capability, to: request.verdict, in: request.file, label: text.doneLabel)
        guard let task = model.writes.start(write) else { return }
        let key = Self.capabilityKey(request.capability, in: request.file)
        capabilityChanging[key] = request.verdict
        Task { @MainActor in
            _ = await task.value
            capabilityChanging[key] = nil
        }
    }

    /// The verdict a pending change of `capability` in the file shown is writing; nil when none is pending.
    func pendingCapability(_ capability: CoreCapability) -> CoreVerdict? { capabilityChanging[Self.capabilityKey(capability, in: file)] }

    private static func capabilityKey(_ capability: CoreCapability, in file: FrameScope) -> String {
        "\(file.scope.rawValue):\(file.dir ?? ""):\(capability.rawValue)"
    }

    // MARK: Rule writes

    /// The inspector's dial and `Change to Ask` on a whole-tool allow: `rules.changeVerdict`, one Undo. While one change of a
    /// rule is pending its dial shows it (`pendingVerdict`) and a second press starts nothing: the control is claimed before
    /// this returns (`FrameWrites.start`). `from` is the verdict the file holds now (the store), never the one the pressed
    /// view drew. The row id carries no verdict (`RulesRuleRow.rowIDs`), so the changed rule stays selected, and so does it
    /// after its Undo.
    func change(_ rule: CoreRule, to verdict: CoreVerdict, fileName: String) {
        guard let model else { return }
        let file = file
        let current = Self.current(rule, in: model.store.snapshot.rules[file]) ?? rule
        guard current.verdict != verdict else { return }
        let write = FrameWrite.changeVerdict(current.rule, from: current.verdict, to: verdict, in: file,
                                             label: RulesWriteWording.changed(current, to: verdict, in: fileName))
        guard let task = model.writes.start(write) else { return }
        changing[write.control] = verdict
        Task { @MainActor in
            _ = await task.value
            changing[write.control] = nil
        }
    }

    /// The verdict a pending change of `rule` is writing, for its dial's pending step; nil when none is pending.
    func pendingVerdict(_ rule: CoreRule) -> CoreVerdict? { changing[FrameWrite.verdictControl(rule.rule, in: file)] }

    /// The rule as the store holds it now: the verdict a change starts from. The same verdict and text first (the core's
    /// id), so a hand-edited file that holds one text under two verdicts changes the entry the selected row shows; by text
    /// only when that one is gone (the file changed under the page).
    static func current(_ rule: CoreRule, in snapshot: CoreRulesSnapshot?) -> CoreRule? {
        snapshot?.rules.first { $0.id == rule.id } ?? snapshot?.rules.first { $0.rule == rule.rule }
    }

    /// `Remove Rule` on the selected row: `rules.removeMany` with one id, one Undo.
    func remove(_ rule: CoreRule, fileName: String) {
        removeSelected([rule], fileName: fileName)
    }

    /// `Remove N selected`: the ticked rules shown, all of the one file shown, as one `rules.removeMany` and one Undo.
    func removeSelected(_ rules: [CoreRule], fileName: String) {
        guard let model, !rules.isEmpty else { return }
        // The rows of these rules, by their row ids (the ticks and the selection), not the core's rule ids.
        let ids = Set((list()?.rows ?? []).filter { row in rules.contains(row.rule) }.map(\.id))
        let write = FrameWrite.removeRules(rules, in: file, label: RulesWriteWording.removed(rules, from: fileName))
        Task { @MainActor in
            guard await model.writes.perform(write) else { return }
            view.ticked.subtract(ids)
            if let selected = model.router.route.selection, ids.contains(selected) { model.router.select(nil) }
        }
    }

    static func removeControl(_ file: FrameScope) -> String { "removeRules:\(file.scope.rawValue):\(file.dir ?? "")" }

    func isPending(_ control: String) -> Bool { model?.writes.isPending(control) ?? false }

    // MARK: Add Rule

    func openAdd() {
        addDraft = RulesAddDraft(file: file, routeRevision: model?.router.revision ?? 0)
    }

    /// The sheet as the frame shows it: none once the route moved to another page or came from outside since it opened.
    var shownAddDraft: RulesAddDraft? {
        addDraft.flatMap { $0.routeRevision == (model?.router.revision ?? 0) ? $0 : nil }
    }

    /// The page left the screen: the capability preview, the menus and a sheet the route already hid close, so none comes
    /// back on the next visit. A sheet whose check or write runs stays until it answers (`closeAdd`).
    func pageLeft() {
        closePreview()
        isCLIMenuOpen = false
        isProjectMenuOpen = false
        if shownAddDraft == nil { closeAdd() }
    }

    func closeAdd() {
        guard addDraft?.isChecking != true else { return }
        addDraft = nil
    }

    /// The sheet's field. Ignored while the check or the write runs: the write sends the rule and verdict it was started
    /// with, so the sheet never shows one thing while another is written (CLICK-PATH Q-003); the field and the dial are
    /// disabled then too.
    func setAddText(_ text: String) {
        guard addDraft?.isChecking == false else { return }
        addDraft?.text = text
        addDraft?.refusal = nil
    }

    /// The sheet's dial; ignored while the check or the write runs, as `setAddText`.
    func setAddVerdict(_ verdict: CoreVerdict) {
        guard addDraft?.isChecking == false else { return }
        addDraft?.verdict = verdict
    }

    /// The sheet's `Add Rule`: `rules.check` first, then `rules.add` to the file the sheet was opened for. A refusal of
    /// either stays in the sheet, next to the field, and is announced; nothing is written.
    func submitAdd(fileName: String) {
        guard let model, var draft = addDraft, !draft.isChecking else { return }
        let rule = draft.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rule.isEmpty else { return }
        draft.isChecking = true
        draft.refusal = nil
        addDraft = draft
        Task { @MainActor in
            var refusal: String?
            do {
                let check = try await model.writes.check(rule: rule)
                if !check.valid { refusal = check.message ?? RulesWriteWording.invalidRule }
            } catch {
                refusal = AppEnvironment.message(error)
            }
            if refusal == nil {
                let write = FrameWrite.addRule(rule, verdict: draft.verdict, in: draft.file, label: RulesWriteWording.added(rule, as: draft.verdict, in: fileName))
                let accepted = await model.writes.perform(write) { refusal = $0 }
                if accepted {
                    addDraft = nil
                    return
                }
            }
            addDraft?.isChecking = false
            addDraft?.refusal = refusal
            if let refusal { Self.announce(refusal) }
        }
    }

    /// A refusal shown in the sheet instead of a toast is still read out, at high priority (RD-R16 Announcements).
    private static func announce(_ text: String) {
        guard let window = NSApp?.keyWindow ?? NSApp?.mainWindow else { return }
        NSAccessibility.post(element: window, notification: .announcementRequested,
                             userInfo: [.announcement: text, .priority: NSAccessibilityPriorityLevel.high.rawValue])
    }
}
