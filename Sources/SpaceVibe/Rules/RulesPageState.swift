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
}

/// The Rules page's own state while the frame shows it (AR3): the CLI page, the ticks, the open menus, the capability
/// preview and the Add Rule sheet. The list, the toolbar and the inspector are separate views the frame places, so they
/// share this one object, one per `FrameModel` (as `HooksPageState`). Every write goes through `FrameWrites` (AR4); the
/// file is the route's scope (AR5).
@MainActor
@Observable
final class RulesPageState {
    var view = RulesViewState()
    var isCLIMenuOpen = false
    var isProjectMenuOpen = false
    private(set) var preview: RulesPreviewRequest?
    var addDraft: RulesAddDraft?

    @ObservationIgnored private weak var model: FrameModel?
    /// The project the Project scope opens on: the one shown last.
    @ObservationIgnored private var lastProject: String?
    /// Bumped by every preview request and file switch, so a preview that answers late is dropped.
    @ObservationIgnored private var previewEpoch = 0

    init(model: FrameModel? = nil) {
        self.model = model
    }

    // MARK: One per frame

    private struct Entry {
        weak var model: FrameModel?
        let state: RulesPageState
    }

    private static var entries: [ObjectIdentifier: Entry] = [:]

    static func of(_ model: FrameModel) -> RulesPageState {
        entries = entries.filter { $0.value.model != nil }
        let key = ObjectIdentifier(model)
        if let entry = entries[key], entry.model === model { return entry.state }
        let state = RulesPageState(model: model)
        entries[key] = Entry(model: model, state: state)
        return state
    }

    var file: FrameScope { model?.router.route.scope ?? .global }

    func list(now: Date = Date()) -> RulesListModel? {
        guard let model else { return nil }
        return RulesListModel.from(model.store, view: view, file: file, now: now)
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
        guard let model, row.isEditable else { return }
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
        run(.setCapability(request.capability, to: request.verdict, in: request.file, label: text.doneLabel), model: model)
    }

    // MARK: Rule writes

    /// The inspector's dial and `Change to Ask` on a whole-tool allow: `rules.changeVerdict`, one Undo.
    func change(_ rule: CoreRule, to verdict: CoreVerdict, fileName: String) {
        guard let model, rule.verdict != verdict else { return }
        run(.changeVerdict(rule.rule, from: rule.verdict, to: verdict, in: file, label: RulesWriteWording.changed(rule, to: verdict, in: fileName)),
            model: model)
    }

    /// `Remove Rule` on the selected row: `rules.removeMany` with one id, one Undo.
    func remove(_ rule: CoreRule, fileName: String) {
        removeSelected([rule], fileName: fileName)
    }

    /// `Remove N selected`: the ticked rules shown, all of the one file shown, as one `rules.removeMany` and one Undo.
    func removeSelected(_ rules: [CoreRule], fileName: String) {
        guard let model, !rules.isEmpty else { return }
        let ids = Set(rules.map(\.id))
        let write = FrameWrite.removeRules(rules, in: file, label: RulesWriteWording.removed(rules, from: fileName))
        Task { @MainActor in
            guard await model.writes.perform(write) else { return }
            view.ticked.subtract(ids)
            if let selected = model.router.route.selection, ids.contains(selected) { model.router.select(nil) }
        }
    }

    static func removeControl(_ file: FrameScope) -> String { "removeRules:\(file.scope.rawValue):\(file.dir ?? "")" }

    func isPending(_ control: String) -> Bool { model?.writes.isPending(control) ?? false }

    private func run(_ write: FrameWrite, model: FrameModel) {
        Task { @MainActor in await model.writes.perform(write) }
    }

    // MARK: Add Rule

    func openAdd() {
        addDraft = RulesAddDraft(file: file)
    }

    func closeAdd() {
        guard addDraft?.isChecking != true else { return }
        addDraft = nil
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
