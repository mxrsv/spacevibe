import SwiftUI

/// What a region hands the frame for its page: the list, the inspector, the toolbar's parts and the `?` text. The frame
/// owns where each goes (RD-R1, RD-R17 Layout); a region owns what is in it. A page without an inspector leaves it nil, and
/// the toolbar then has no inspector button.
struct FramePageContent {
    /// The quiet line beside the title.
    var subtitle: String?
    /// The `?` popover beside the title (RD32).
    var help: String
    /// The page's own toolbar controls (segmented filters, the CLI menu), between the title and the inspector button.
    var toolbarControls: AnyView?
    /// What the page's search finds, plural ("skills"): the frame draws the one search field after the page's controls, as
    /// the mock's `srch()`, and ⌘F focuses it; the page filters its list by `FrameModel.search`. Nil: no search on the page.
    var searchItems: String?
    /// The one primary or destructive button, drawn in the fixed-width slot at the toolbar's end.
    var primary: AnyView?
    var body: AnyView
    var inspector: AnyView?
    /// The selected row's actions, repeated at the overlay inspector's top below 1100 pt, where the overlay covers the row
    /// (DS-R10 Inspector).
    var overlayActions: AnyView?
    /// The sheet or confirmation open on the page, drawn by the frame over the whole window (RD-R16 Dialogs).
    var dialog: FrameDialog?

    /// A region that is not built yet (plan, FE-P9 shape): "Not built yet" on the list, and on a page that has an inspector
    /// the inspector's empty state.
    static func notBuilt(_ page: FramePage) -> FramePageContent {
        FramePageContent(
            help: page.help,
            body: AnyView(PageEmptyState(icon: page.icon, title: "Not built yet",
                                         text: "\(page.title) has no view in the redesign yet.")),
            inspector: page.hasInspector
                ? AnyView(PageEmptyState(icon: .sidebarSimple, text: "Select a row to see its details."))
                : nil)
    }
}

/// A sheet or a confirmation a page has open (RD-R16 Dialogs; the mock's `.scrim`): the frame draws it above the sidebar,
/// the toolbar, the list and the inspector, so its scrim covers the whole window, as the mock draws it. While it is open the
/// frame hides everything below it from VoiceOver and the keyboard, moves the focus into it and gives the focus back where it
/// was when it closes; Esc cancels it before any other overlay (`FrameEscape`), and the menu bar's page, inspector, refresh,
/// Undo and Item commands wait (`FrameCommandTarget.isModal`). The content is a `DialogSheet`, whose Cancel is the default
/// button (Return); `id` tells one dialog from the next, so the focus moves in again when another one replaces it.
struct FrameDialog {
    let id: String
    let content: AnyView
    /// Esc: the dialog's Cancel. The dialog itself ignores it while its write runs.
    let cancel: @MainActor () -> Void

    init<Content: View>(id: String, cancel: @escaping @MainActor () -> Void, @ViewBuilder content: () -> Content) {
        self.id = id
        self.cancel = cancel
        self.content = AnyView(content())
    }
}

/// What Esc closes in the frame, first match wins: the open dialog, then the overlay inspector and the page help. Pure.
enum FrameEscape: Equatable, Sendable {
    case dialog, overlays, nothing

    static func target(hasDialog: Bool, presentation: InspectorPresentation, isHelpOpen: Bool) -> FrameEscape {
        if hasDialog { return .dialog }
        return presentation == .overlay || isHelpOpen ? .overlays : .nothing
    }
}

/// The page's figure as its sidebar item shows it (the mock's `sideVals`): the same `PageFigure` the hero reads, so the two
/// cannot disagree (AR3). The value is neutral text (RD10); only Inbox carries a severity glyph.
struct FrameSidebarValue: Equatable, Sendable {
    var text: String?
    var mark: FrameSidebarItem.Mark?
    /// Inbox only: the findings that are critical, for "N need you, M critical" (RD-R16).
    var criticalCount = 0

    static let none = FrameSidebarValue()

    init(text: String? = nil, mark: FrameSidebarItem.Mark? = nil, criticalCount: Int = 0) {
        self.text = text
        self.mark = mark
        self.criticalCount = criticalCount
    }

    init(figure: PageFigure, page: FramePage, criticalCount: Int = 0) {
        let mark: (FindingSeverity?) -> FrameSidebarItem.Mark? = { tone in
            guard page == .inbox, let tone else { return nil }
            switch tone {
            case .critical: return .critical
            case .attention: return .attention
            case .info: return nil
            }
        }
        switch figure {
        case .pending: self.init(text: page == .clean ? "Measuring" : "\u{2026}")
        case .failed, .unmeasurable: self.init(text: "Unmeasurable")
        case .notMeasured: self.init()
        case .count(let n, let tone): self.init(text: NumberWording.count(n), mark: mark(tone), criticalCount: criticalCount)
        case .percentLeft(let left, _): self.init(text: "\(WindowPace.percentText(left)) left")
        case .bytes(let bytes): self.init(text: NumberWording.bytes(bytes))
        }
    }

    /// What VoiceOver reads for the item: "Inbox, 11 need you, 2 critical"; "Skills, 4" elsewhere; the title alone without a
    /// value.
    func spokenLabel(for page: FramePage) -> String {
        guard let text else { return page.title }
        guard page == .inbox, text != "\u{2026}", text != "Unmeasurable" else { return "\(page.title), \(text)" }
        let critical = criticalCount > 0 ? ", \(NumberWording.count(criticalCount)) critical" : ""
        return "\(page.title), \(text) need you\(critical)"
    }
}

/// Every page's sidebar value. `none` draws the items without values (a shot, a specimen).
struct FrameSidebarValues: Equatable, Sendable {
    var values: [FramePage: FrameSidebarValue] = [:]

    static let none = FrameSidebarValues()

    subscript(page: FramePage) -> FrameSidebarValue { values[page] ?? .none }

    /// From the store: `FrameWorld.figure(for:)` per page, with the store's loading and failed sources.
    @MainActor
    static func from(_ store: FrameStore, now: Date = Date()) -> FrameSidebarValues {
        let world = store.world(now: now)
        let loading = store.loading, failed = store.failedEmpty
        let critical = world.findings.filter { $0.severity == .critical }.count
        var values: [FramePage: FrameSidebarValue] = [:]
        for page in FramePage.allCases {
            let figure = world.figure(for: page, loading: loading, failed: failed)
            values[page] = FrameSidebarValue(figure: figure, page: page, criticalCount: page == .inbox ? critical : 0)
        }
        return FrameSidebarValues(values: values)
    }
}
