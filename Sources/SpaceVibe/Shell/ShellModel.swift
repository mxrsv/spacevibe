import Observation
import SwiftUI

/// State of the window frame: which tab shows, whether the palette is open, and the footer status line.
/// Screens read it from the environment (`@Environment(ShellModel.self)`) to switch tabs or open the palette.
@MainActor
@Observable
final class ShellModel {
    let tabs: [any SpaceVibeTab]
    let appearance: AppearanceStore
    var activeID: String
    /// Settings covers the whole window (spec `docs/specs/2026-11-04-reins-settings.md`); the tab or Limits page under it
    /// stays as it was and shows again when Settings closes.
    var isSettingsOpen = false
    var settingsSection = SettingsSection.appearance
    var isPaletteOpen = false
    var paletteQuery = ""
    /// A short line at the bottom of the sidebar ("Counting usage 3/9"). Nil hides it.
    var statusMessage: String?

    init(tabs: [any SpaceVibeTab], appearance: AppearanceStore, activeID: String? = nil) {
        precondition(!tabs.isEmpty, "TabRegistry returned no tabs")
        self.tabs = tabs
        self.appearance = appearance
        self.activeID = activeID ?? tabs[0].id
    }

    var activeTab: any SpaceVibeTab { tabs.first { $0.id == activeID } ?? tabs[0] }

    /// The top bar's title: the active tab's, or the Limits page's while it shows.
    var title: String { activeTab.title }
    /// The hint bar's middle part, likewise.
    var hints: [KeyHint] { activeTab.hints }

    func select(_ id: String) {
        guard tabs.contains(where: { $0.id == id }) else { return }
        activeID = id
        isSettingsOpen = false
        isPaletteOpen = false
    }

    func openLimits() { select(TabRegistry.limitsID) }

    /// The glance widget's fallback (GW6): Activity's Running tab with that session current and its detail open. `itemID` is
    /// an `ActivitySessionItem.id` (`cli:sessionID`, the same as `GlanceEntry.id`).
    func openActivity(sessionItemID itemID: String) {
        select(TabRegistry.activityID)
        guard let activity = tabs.first(where: { $0.id == TabRegistry.activityID }) as? ActivityTab else { return }
        activity.model.select(.running)
        activity.model.open(itemID)
    }

    /// The glance widget's countdown (LC-R7): the Limits page with that window current. `windowID` is a Limits entry id
    /// (`cli:windowID`, the same as `GlanceCountdownWindow.id`); `limits` is the model the page reads, and `openState` the
    /// store it reads its cards and bands from. The Usage windows card and that CLI's band open, because the page makes
    /// current only a row it lists, and it lists no row of a closed card or band.
    func openLimits(windowID: String, in limits: LimitsModel, openState: OpenStateStore = .shared) {
        select(TabRegistry.limitsID)
        LimitsCanvas.reveal(windowID: windowID, in: openState)
        limits.selectedID = windowID
    }

    func openSettings() {
        isSettingsOpen = true
        isPaletteOpen = false
    }

    func closeSettings() { isSettingsOpen = false }

    /// `⌘1` is index 0.
    func select(index: Int) {
        guard tabs.indices.contains(index) else { return }
        select(tabs[index].id)
    }

    func openPalette(query: String = "") {
        paletteQuery = query
        isPaletteOpen = true
    }

    func closePalette() { isPaletteOpen = false }

    func togglePalette() {
        if isPaletteOpen { closePalette() } else { openPalette() }
    }
}
