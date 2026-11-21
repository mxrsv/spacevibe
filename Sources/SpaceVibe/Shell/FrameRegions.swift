/// Which region draws each page of the frame. A region adds one `case` here when it is built; every other page keeps the
/// "Not built yet" state (plan FE-P9 shape). `AppFrame` asks this by default.
extension FramePageContent {
    @MainActor
    static func region(_ page: FramePage, model: FrameModel) -> FramePageContent {
        switch page {
        case .inbox: .inbox(model: model)
        case .hooks: HooksFrame.content(model: model)
        case .limits: LimitsRegion.content(model)
        case .activity: ActivityPage.content(model)
        default: .notBuilt(page)
        }
    }
}
