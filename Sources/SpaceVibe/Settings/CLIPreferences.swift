import Foundation
import Observation

/// Settings › CLIs (RB-R8): which CLIs the lists show and which ones Balance compares, saved in the app's defaults domain the
/// moment they change. The redesign's store reads it into `FrameFacts` (`FrameStore.world`), so every page and the sidebar
/// follow a change at once.
///
/// - **Show** ("Show in Settings › CLIs", "Show guard"): a hidden CLI's rows and sessions leave every list; who reads or
///   loses a file and Clean's locks still count it (`FrameWorld`). At least one registry CLI stays shown.
/// - **Balance pins** ("Pinning", RD55): none (Balance off), two or three, only CLIs that hold Skills or Subagents; exactly
///   one is never a state. Until the user changes a pin, the first two such CLIs in registry order are pinned, as the
///   reference mock starts (`UI.pin` in `src/b-chrome.js`). With one switch per CLI, a change that would leave one pin
///   moves a second switch too (`changePin`): unpinning one of two turns Balance off, pinning one when none is pinned pins
///   a partner with it, and the pane says which.
///
/// New keys, not shared with v5 (v5 has neither). Under `SPACEVIBE_TEST=1` in a development build the shared one keeps its
/// choices in memory, so tests and screenshots never read or write the machine's defaults.
@MainActor
@Observable
final class CLIPreferences {
    nonisolated static let hiddenKey = "spacevibe.hiddenCLIs"
    nonisolated static let pinsKey = "spacevibe.balancePins"
    nonisolated static let maxPins = 3
    nonisolated static let minPins = 2

    static let shared = CLIPreferences(defaults: isTestLaunch() ? nil : .standard)

    /// Why a switch did not change.
    enum Refusal: Equatable, Sendable {
        /// Hiding it would hide every CLI.
        case lastShown
        /// It holds neither Skills nor Subagents.
        case cannotBalance
        /// Three are pinned already.
        case pinsFull
        /// No pin yet, and no other CLI that can be compared to pin with it: one pin alone is never a state (RD55).
        case noPartner
    }

    /// What a Balance switch did (`changePin`): the press alone, a second switch moved with it so the pins stay none, two
    /// or three (RD55), or a refusal.
    enum PinChange: Equatable, Sendable {
        case changed
        /// The other of two pins went too: Balance is off.
        case alsoUnpinned(String)
        /// Pinned with the first other CLI that can be compared, so Balance has two.
        case alsoPinned(String)
        case refused(Refusal)

        var refusal: Refusal? { if case .refused(let refusal) = self { refusal } else { nil } }
    }

    @ObservationIgnored private let defaults: UserDefaults?

    /// Registry ids the user hid. An id the registry no longer lists is kept and ignored.
    private(set) var hidden: Set<String> {
        didSet { defaults?.set(hidden.sorted(), forKey: Self.hiddenKey) }
    }

    /// The pins the user chose, nil until the first change (then the default applies).
    private(set) var chosenPins: [String]? {
        didSet {
            if let chosenPins { defaults?.set(chosenPins, forKey: Self.pinsKey) } else { defaults?.removeObject(forKey: Self.pinsKey) }
        }
    }

    /// `defaults` nil keeps the choices in memory only, starting at `hidden` and `pins`.
    init(defaults: UserDefaults? = .standard, hidden: Set<String> = [], pins: [String]? = nil) {
        self.defaults = defaults
        // Setting a property in init does not fire didSet, so reading saves nothing. A value of another type reads as unset.
        self.hidden = (defaults?.array(forKey: Self.hiddenKey) as? [String]).map(Set.init) ?? hidden
        self.chosenPins = (defaults?.array(forKey: Self.pinsKey) as? [String]) ?? pins
    }

    nonisolated static func isTestLaunch(environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        CoreEnvironment.overridesAllowed() && environment[CoreEnvironment.testFlag] == "1"
    }

    // MARK: Reading

    /// Only a CLI that holds Skills or Subagents can be compared in Balance.
    nonisolated static func canBalance(_ cli: CoreRegistryCLI) -> Bool { cli.supports.skill || cli.supports.agent }

    /// The CLIs that own a Skills or Subagents folder SpaceVibe copies into, from `loadout.rows`' readers map (it lists each
    /// installed CLI's own folders); nil without a map.
    nonisolated static func installedForBalance(_ folders: [CoreReadersFolder]?) -> Set<String>? {
        guard let folders, !folders.isEmpty else { return nil }
        return Set(folders.filter { $0.copyTarget && ($0.kind == .skill || $0.kind == .agent) }.map(\.ownedBy))
    }

    /// The hidden ids among `registry`; never every one of them (an older defaults value cannot break the Show guard).
    func hidden(in registry: [CoreRegistryCLI]) -> Set<String> {
        let ids = registry.map(\.id)
        let listed = hidden.intersection(ids)
        return listed.count >= ids.count && !ids.isEmpty ? listed.subtracting([ids[0]]) : listed
    }

    func isShown(_ id: String, in registry: [CoreRegistryCLI]) -> Bool { !hidden(in: registry).contains(id) }

    /// The pinned CLIs in registry order: the chosen ones that can be compared, at most three; before any choice, the first
    /// two that can. A choice that leaves exactly one (an older stored value, a CLI the registry dropped) reads as none.
    ///
    /// `installed`: the CLIs that own a folder SpaceVibe copies Skills or Subagents into (`installedForBalance`, from the
    /// readers map); the default skips any other, so Balance never starts by comparing against a CLI that is not on this Mac
    /// or holds neither. Nil (no `loadout.rows` read yet) leaves the registry's order alone.
    func pins(in registry: [CoreRegistryCLI], installed: Set<String>? = nil) -> [String] {
        let eligible = registry.filter(Self.canBalance)
        guard let chosenPins else {
            let first = Array(eligible.filter { installed?.contains($0.id) ?? true }.prefix(Self.minPins).map(\.id))
            return first.count < Self.minPins ? [] : first
        }
        let chosen = Array(eligible.map(\.id).filter(chosenPins.contains).prefix(Self.maxPins))
        return chosen.count < Self.minPins ? [] : chosen
    }

    // MARK: Writing

    /// Shows or hides one CLI; nil when it changed or already was so.
    @discardableResult
    func setShown(_ isShown: Bool, for id: String, in registry: [CoreRegistryCLI]) -> Refusal? {
        if isShown {
            hidden.remove(id)
            return nil
        }
        let shown = registry.map(\.id).filter { !hidden(in: registry).contains($0) }
        if shown == [id] { return .lastShown }
        hidden.insert(id)
        return nil
    }

    /// Pins or unpins one CLI for Balance; nil when it changed (a partner may have moved with it, `changePin`) or already
    /// was so.
    @discardableResult
    func setPinned(_ isPinned: Bool, for id: String, in registry: [CoreRegistryCLI], installed: Set<String>? = nil) -> Refusal? {
        changePin(isPinned, for: id, in: registry, installed: installed).refusal
    }

    /// Pins or unpins one CLI for Balance, keeping the pins none, two or three (RD55): unpinning one of two unpins the other
    /// too (Balance off); pinning one when none is pinned pins with it the first other CLI in registry order that can be
    /// compared and is installed (`installed`, as the default pins), and is refused when there is none.
    @discardableResult
    func changePin(_ isPinned: Bool, for id: String, in registry: [CoreRegistryCLI], installed: Set<String>? = nil) -> PinChange {
        var pins = pins(in: registry, installed: installed)
        var change = PinChange.changed
        if isPinned {
            guard let cli = registry.first(where: { $0.id == id }), Self.canBalance(cli) else { return .refused(.cannotBalance) }
            if pins.contains(id) { return .changed }
            guard pins.count < Self.maxPins else { return .refused(.pinsFull) }
            if pins.isEmpty {
                guard let partner = registry.first(where: { $0.id != id && Self.canBalance($0) && (installed?.contains($0.id) ?? true) })
                else { return .refused(.noPartner) }
                pins.append(partner.id)
                change = .alsoPinned(partner.id)
            }
            pins.append(id)
        } else {
            guard pins.contains(id) else { return .changed }
            pins.removeAll { $0 == id }
            if pins.count < Self.minPins, let other = pins.first {
                pins = []
                change = .alsoUnpinned(other)
            }
        }
        chosenPins = registry.map(\.id).filter(pins.contains)
        return change
    }
}
