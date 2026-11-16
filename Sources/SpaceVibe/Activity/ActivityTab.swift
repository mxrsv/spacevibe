import SwiftUI

/// Registers ActivityCanvas with the shell, its commands, status bar and Stop confirmation.
@MainActor
final class ActivityTab: SpaceVibeTab {
    static let tabID = "activity"

    let id = ActivityTab.tabID
    let title = "Activity"
    let model: ActivityModel

    init(env: AppEnvironment? = nil) { model = ActivityModel(env: env ?? .shared) }

    init(model: ActivityModel) { self.model = model }

    var glyph: any GlyphSource { ContentGlyph.pulse }

    var badge: TabBadge? { nil }

    var paletteActions: [PaletteEntry] {
        [PaletteEntry(id: "activity.refresh", title: "Refresh activity", glyph: ContentGlyph.enter, keywords: ["reload", "sessions", "failures"]) { [model] in
            model.refreshNow()
        }]
    }

    /// Only the keys `ActivityCanvas.keys` wires (V5-R36), per tab.
    var hints: [KeyHint] { ActivityStatusBar.hints(for: model.pane) }
    var source: String? { ActivityStatusBar.source }

    var isMenuOpen: Bool { model.isMenuOpen }

    var content: AnyView { AnyView(ActivityCanvas(model: model)) }

    /// The Stop confirmation over the whole window (V5-R59).
    var modal: AnyView? {
        guard let session = model.pendingStop else { return nil }
        return AnyView(StopSessionPanel(session: session, isStopping: model.isStopping, cancel: model.cancelStop, confirm: model.confirmStop))
    }
}

/// The key hints and the data source of the status bar on the Activity page (V5-R36, V5-R69).
enum ActivityStatusBar {
    static let source = "Read from local session logs"

    static func hints(for pane: ActivityPane) -> [KeyHint] {
        let move = KeyHint(keys: "J K", label: "move"), detail = KeyHint(keys: "\u{21B5}", label: "detail")
        let tabs = KeyHint(keys: "1 2", label: "tabs")
        switch pane {
        case .running: return [move, detail, KeyHint(keys: "S", label: "stop"), tabs]
        case .failed: return [move, detail, KeyHint(keys: "C", label: "copy"), tabs]
        }
    }
}
