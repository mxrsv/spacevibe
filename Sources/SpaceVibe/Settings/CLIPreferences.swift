import Foundation
import Observation

/// Settings › CLIs (RB-R8): which CLIs the lists show and which ones Balance compares, saved in the app's defaults domain the
/// moment they change. The redesign's store reads it into `FrameFacts` (`FrameStore.world`), so every page and the sidebar
/// follow a change at once.
///
/// - **Show** ("Show in Settings › CLIs", "Show guard"): a hidden CLI's rows and sessions leave every list; who reads or
///   loses a file and Clean's locks still count it (`FrameWorld`). At least one registry CLI stays shown.
/// - **Balance pins** ("Pinning"): two to three, only CLIs that hold Skills or Subagents. Until the user changes a pin, the
///   first two such CLIs in registry order are pinned, as the reference mock starts (`UI.pin` in `src/b-chrome.js`).
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

    /// The hidden ids among `registry`; never every one of them (an older defaults value cannot break the Show guard).
    func hidden(in registry: [CoreRegistryCLI]) -> Set<String> {
        let ids = registry.map(\.id)
        let listed = hidden.intersection(ids)
        return listed.count >= ids.count && !ids.isEmpty ? listed.subtracting([ids[0]]) : listed
    }

    func isShown(_ id: String, in registry: [CoreRegistryCLI]) -> Bool { !hidden(in: registry).contains(id) }

    /// The pinned CLIs in registry order: the chosen ones that can be compared, at most three; before any choice, the first
    /// two that can.
    func pins(in registry: [CoreRegistryCLI]) -> [String] {
        let eligible = registry.filter(Self.canBalance)
        guard let chosenPins else { return Array(eligible.prefix(Self.minPins).map(\.id)) }
        return Array(eligible.map(\.id).filter(chosenPins.contains).prefix(Self.maxPins))
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

    /// Pins or unpins one CLI for Balance; nil when it changed or already was so.
    @discardableResult
    func setPinned(_ isPinned: Bool, for id: String, in registry: [CoreRegistryCLI]) -> Refusal? {
        var pins = pins(in: registry)
        if isPinned {
            guard let cli = registry.first(where: { $0.id == id }), Self.canBalance(cli) else { return .cannotBalance }
            if pins.contains(id) { return nil }
            guard pins.count < Self.maxPins else { return .pinsFull }
            pins.append(id)
        } else {
            pins.removeAll { $0 == id }
        }
        chosenPins = registry.map(\.id).filter(pins.contains)
        return nil
    }
}
