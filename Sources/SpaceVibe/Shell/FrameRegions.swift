/// Which region draws each page of the frame. A region adds one `case` here when it is built; every other page keeps the
/// "Not built yet" state (plan FE-P9 shape). `AppFrame` asks this by default.
extension FramePageContent {
    @MainActor
    static func region(_ page: FramePage, model: FrameModel) -> FramePageContent {
        switch page {
        case .hooks: HooksFrame.content(model: model)
        default: .notBuilt(page)
        }
    }
}
