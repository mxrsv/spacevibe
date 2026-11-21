import AppKit
import SwiftUI

/// The Limits region of the redesign's frame (plan RB-R6; `FramePageContent.region`): the page's parts for the frame. Limits
/// has no inspector (`FramePage.hasInspector`), no toolbar control and no primary action (D69: no Refresh; RD21: no Gemini
/// card). It reads the store's data through `LimitsCards` and writes nothing: Copy Install Command only copies (the mock's
/// `MOCK.na`: "Limits writes nothing").
enum LimitsRegion {
    @MainActor
    static func content(_ model: FrameModel) -> FramePageContent {
        FramePageContent(help: FramePage.limits.help, body: AnyView(LimitsRegionView(model: model)))
    }
}

/// The live page: the store's world every 60 s (and at once on a store change, which Observation reports), the route's
/// selection, the arrow keys, and the two actions.
struct LimitsRegionView: View {
    let model: FrameModel
    /// The page redraws this often: pace and "12 min ago" move with the clock; a counting row ticks on its own.
    static let redrawInterval: TimeInterval = 60

    @Environment(FrameChrome.self) private var chrome
    @Environment(ToastCenter.self) private var toasts
    @State private var isRetrying = false
    private let countdown = LimitsCountdownPreferences.shared

    var body: some View {
        TimelineView(.periodic(from: .now, by: Self.redrawInterval)) { context in
            let cards = LimitsCards(world: model.store.world(now: context.date), state: model.store.states[.limits], now: context.date,
                                    weeklyLead: countdown.weeklyLead)
            LimitsCardList(cards: cards, selection: model.router.route.selection, keyboardRow: chrome.keyboardRow,
                           isRetrying: isRetrying, select: select, copyInstallCommand: copyInstallCommand, tryAgain: tryAgain)
                .frameListKeys(rows: cards.rowIDs, router: model.router, chrome: chrome)
        }
    }

    private func select(_ id: String) {
        chrome.pointerSelected()
        model.router.select(id)
    }

    /// RD24: the app copies the status-line capture's install command; the owner pastes it into a terminal. Never run here
    /// (S-R4).
    private func copyInstallCommand() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(LimitsCards.installCommand(helper: CoreEnvironment.binaryURL()), forType: .string)
        toasts.show(LimitsCards.copiedMessage)
    }

    /// Reads `limits.read` again; the button shows its pending state until the read answers.
    private func tryAgain() {
        guard !isRetrying else { return }
        isRetrying = true
        Task {
            await model.store.reread([.limits])
            isRetrying = false
        }
    }
}
