/// The Skills region of the redesign's frame (RB-R2): the shared Skills and Subagents implementation (`EquipFrame`) with the
/// Skills words.
enum SkillsFrame {
    @MainActor
    static func content(model: FrameModel) -> FramePageContent { EquipFrame.content(.skills, model: model) }
}

extension EquipKind {
    static let skills = EquipKind(page: .skills, kind: .skill, noun: "Skill", folderWord: "skills")
}
