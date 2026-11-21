/// The Subagents region of the redesign's frame (RB-R2): the shared Skills and Subagents implementation (`EquipFrame`, in
/// `Skills/`) with the Subagents words.
enum SubagentsFrame {
    @MainActor
    static func content(model: FrameModel) -> FramePageContent { EquipFrame.content(.subagents, model: model) }
}

extension EquipKind {
    static let subagents = EquipKind(page: .subagents, kind: .agent, noun: "Subagent", folderWord: "agents")
}
