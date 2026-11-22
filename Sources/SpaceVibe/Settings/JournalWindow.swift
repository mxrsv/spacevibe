import Foundation
import SwiftUI

/// What the Journal window shows ("Inferred, not decided": Journal window; the mock's "not shown"): `journal.history` newest
/// first, at most 200, each row with its label, its time and Undo; an undone row reads "Undone" and takes no click. Empty
/// reads "No changes yet"; a journal that could not be read shows the error, never an empty list. Pure, so tests pin it.
struct JournalList: Equatable {
    static let cap = 200
    static let emptyTitle = "No changes yet"
    static let emptyText = "Every change SpaceVibe makes is listed here, with Undo."
    static let failureTitle = "The Journal could not be read"
    static let undone = "Undone"

    struct Row: Identifiable, Equatable {
        let entry: CoreJournalEntry
        /// "Removed ponytail"; a change the core named nothing reads "Change".
        let label: String
        /// "2:02 PM", "Fri 4:00 PM", "Nov 10" (the redesign's time wording, `LimitsClockWording`).
        let time: String

        var id: String { entry.id }
        var isUndone: Bool { entry.undone }
        /// The write control of this row's Undo: pending at the row's button (AR4).
        var control: String { FrameWrite.journalUndoControl(entry.id) }
    }

    enum Content: Equatable {
        /// Not answered yet: skeleton rows.
        case pending
        case empty
        case rows([Row])
        /// Could not be read and nothing was read before: only the error.
        case unreadable
    }

    let content: Content
    /// The core's sentence when the last read failed; shown over the rows, or alone.
    let failure: String?

    init(history: CoreJournalHistory?, state: FrameSourceState?, now: Date, calendar: Calendar = .current) {
        if case .failed(let message) = state { failure = message } else { failure = nil }
        guard let history else {
            content = failure == nil ? .pending : .unreadable
            return
        }
        let entries = history.entries.sorted { Self.date($0.at) ?? .distantPast > Self.date($1.at) ?? .distantPast }.prefix(Self.cap)
        content = entries.isEmpty ? .empty : .rows(entries.map { entry in
            Row(entry: entry, label: entry.label.isEmpty ? "Change" : entry.label,
                time: Self.date(entry.at).map { LimitsClockWording.clock($0, now: now, calendar: calendar) } ?? NumberWording.missing)
        })
    }

    /// The entry's `at` (ISO 8601 UTC with milliseconds; without them too).
    static func date(_ at: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return withFraction.date(from: at) ?? ISO8601DateFormatter().date(from: at)
    }
}

extension FrameWrite {
    static func journalUndoControl(_ id: String) -> String { "journalUndo:\(id)" }

    /// Undo of one Journal entry from the Journal window (`journal.undo`). Not journaled again, so the toast has no Undo; a
    /// refusal (409: the file changed since, or the path exists again) shows the core's sentence and writes nothing. An
    /// entry may have touched any source, so `touches` names every one the store holds.
    static func journalUndo(_ entry: CoreJournalEntry, label: String, touches: Set<FrameSource>) -> FrameWrite {
        FrameWrite(control: journalUndoControl(entry.id), label: "Undid \(label)", touches: touches) { core in
            _ = try await core.journalUndo(id: entry.id)
            return .done
        }
    }

    /// Every source an undone entry may have changed: the item lists, the Keep list, every rules file the store reads, and
    /// Clean's scan once Clean has read one (an undone Clean move brings logs and caches back; never a first scan here).
    @MainActor
    static func journalSources(_ store: FrameStore) -> Set<FrameSource> {
        var sources = Set([.inventory, .loadout, .kept, .rules(.global)]).union(store.snapshot.rules.keys.map(FrameSource.rules))
        if store.snapshot.clean != nil { sources.insert(.clean) }
        return sources
    }
}

extension FrameWrites {
    /// The Journal window's Undo of one entry, through this window's write path; once the core accepted it, the entry's
    /// Undo leaves `main`'s session stack (the main window's toast, ⌘Z and Z), which would otherwise run it again and be
    /// refused.
    @discardableResult
    func undoFromJournal(_ entry: CoreJournalEntry, label: String, store: FrameStore, main: FrameWrites?) async -> Bool {
        let undone = await perform(.journalUndo(entry, label: label, touches: FrameWrite.journalSources(store)))
        if undone { main?.forgetUndo(journalEntry: entry.id) }
        return undone
    }
}

/// The Journal window (Settings › Data › Show Journal): its own `Window` scene beside Settings, declared by
/// `SpaceVibeFrameApp` only. It reads the app's frame model (the one the main window shows) and undoes through the write
/// path (AR4) with its own toast host, so a refusal shows here and nowhere else.
struct JournalWindow: View {
    static let windowID = "journal"

    /// A screenshot's facts; nil reads the model's store.
    private let preview: SettingsFacts?
    /// The app's frame model; nil in a screenshot.
    private let model: FrameModel?
    @State private var toasts = ToastCenter()
    @State private var writes: FrameWrites?

    init(model: FrameModel? = nil, preview: SettingsFacts? = nil) {
        self.model = model
        self.preview = preview
    }

    var body: some View {
        let store = model?.store
        let facts = preview ?? SettingsFacts(store: store)
        let list = JournalList(history: facts.journal, state: facts.journalState, now: Date())
        ZStack(alignment: .top) {
            FrameWindowSurface(hasSidebar: false)
            VStack(alignment: .leading, spacing: SpaceRole.step16) {
                Text("Journal")
                    .typeRole(.pageTitle)
                    .foregroundStyle(ColorRole.ink)
                    .accessibilityAddTraits(.isHeader)
                if let failure = list.failure {
                    StatusBanner(.problem(.critical), title: JournalList.failureTitle, detail: failure) {
                        if let store {
                            Button { Task { await store.reread([.journal]) } } label: { PushButtonLabel("Try Again", size: .small) }
                                .buttonStyle(PushButtonStyle(.control, size: .small))
                                .focusEffectDisabled()
                        }
                    }
                }
                content(list, store: store)
            }
            .padding(.top, SpaceRole.titleBarClearance)
            .padding(.horizontal, SpaceRole.step24)
            .padding(.bottom, SpaceRole.step24)
            FrameToastHost()
        }
        .frame(width: FrameRole.settingsWindowWidth)
        .frame(minHeight: FrameRole.settingsBodyMinHeight)
        .environment(toasts)
        .ignoresSafeArea()
        .navigationTitle("Journal")
        .onExitCommand { toasts.dismiss() }
        .task { await model?.store.start() }
    }

    @ViewBuilder
    private func content(_ list: JournalList, store: FrameStore?) -> some View {
        switch list.content {
        case .pending:
            RowGroup { SkeletonRows(count: 4) }
        case .unreadable:
            EmptyView()
        case .empty:
            PageEmptyState(icon: .clockCounterClockwise, title: JournalList.emptyTitle, text: JournalList.emptyText) { EmptyView() }
        case .rows(let rows):
            // The screens' scroll view, so a headless shot draws the rows (a bare `ScrollView` renders blank there).
            SpaceVibeScrollView {
                RowGroup {
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        SettingsRow(row.label, detail: row.time, index: index) { trailing(row, store: store) }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func trailing(_ row: JournalList.Row, store: FrameStore?) -> some View {
        if row.isUndone {
            Text(JournalList.undone).typeRole(.quiet).foregroundStyle(ColorRole.ink3)
        } else {
            let isPending = writes?.isPending(row.control) ?? false
            Button { undo(row, store: store) } label: { PushButtonLabel(ToastText.undoTitle, icon: .arrowCounterClockwise, size: .small) }
                .buttonStyle(PushButtonStyle(.control, size: .small, isLoading: isPending))
                .focusEffectDisabled()
                .disabled(isPending)
                .accessibilityLabel("Undo \(row.label)")
        }
    }

    private func undo(_ row: JournalList.Row, store: FrameStore?) {
        guard let store else { return }
        let writes = writes ?? store.makeWrites(toasts: toasts)
        self.writes = writes
        let main = model?.writes
        Task { await writes.undoFromJournal(row.entry, label: row.label, store: store, main: main) }
    }
}
