import SwiftUI

/// The confirmation before a removal from Inbox or Clean touches a shared file (DS-R10 "remove confirmation"; RD-R11 "every
/// other removal path names the readers too"; the mock's `rmConfirm`): "Remove N items?", one line per item naming every CLI
/// that loses it (or, for a Clean log or cache section, what moves where), at most 5 lines and "and N more items", the Undo promise, Cancel (the default) and the red-tinted `Remove N`.
struct RemoveConfirmation: View {
    struct Item: Identifiable, Hashable {
        let id: String
        let name: String
        /// The kind's icon (`.skills`, `.subagents`, `.hooks`).
        let icon: FrameIcon
        /// Every CLI that loses the item, hidden ones included (spec "Inferred": a hidden CLI is still named).
        let losers: [String]
        /// The line under the name when it is not "From <CLIs>": what the same press does to a log or cache section of Clean
        /// ("1,310 files older than 90 days, to the macOS Trash"), so the dialog names every target (FE-I).
        var detail: String?
    }

    let items: [Item]
    var isWorking = false
    let cancel: () -> Void
    let remove: () -> Void

    var body: some View {
        let capped = CappedList(items)
        DialogSheet(title: Self.title(items.count),
                    note: "Shared files are removed for every CLI that reads them. Undo puts everything back.",
                    isWorking: isWorking, cancel: cancel) {
            VStack(alignment: .leading, spacing: SpaceRole.step10) {
                ForEach(capped.shown) { item in
                    DialogListLine(name: item.name, detail: item.detail ?? Self.fromLine(item.losers)) {
                        FrameGlyph(item.icon, side: SizeRole.icon16, ink: ColorRole.ink3)
                    }
                }
                if let more = capped.moreLine(one: "item") { DialogMoreLine(text: more) }
            }
            .padding(.vertical, SpaceRole.step10)
        } confirm: {
            Button(action: remove) { Text(Self.confirmTitle(items.count)).frame(maxWidth: .infinity) }
                .buttonStyle(PushButtonStyle(.destructive, isLoading: isWorking))
                .focusEffectDisabled()
        }
    }

    static func title(_ count: Int) -> String { "Remove \(NumberWording.plural(count, "item"))?" }
    static func confirmTitle(_ count: Int) -> String { "Remove \(NumberWording.count(count))" }
    static func fromLine(_ losers: [String]) -> String { "From \(CLINames.sentence(losers))" }
}
