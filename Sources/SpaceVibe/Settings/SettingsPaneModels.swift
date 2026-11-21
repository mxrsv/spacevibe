import Foundation

/// The Settings window's states ("Inferred, not decided": Settings window states; RD-R13), as the reference mock's state
/// switch draws them: each opens the pane it changes. The window reads nothing that scans (`MOCK.na`), so it has no scanning
/// state; a switch applies at once and is its own undo, so it has no just-written toast.
enum SettingsWindowState: String, CaseIterable, Sendable {
    case normal
    /// No status-line snapshot yet: the Limits pane.
    case empty
    /// The limits could not be read: the Limits pane, Unmeasurable.
    case error
    /// Ten CLIs: the CLIs pane.
    case worst
    /// The CLIs pane with three pins, the fourth refused in place.
    case dialog
    /// A setting macOS refused (Open at login): the error toast over General.
    case refused

    /// The pane the state opens; nil keeps the window's own (General).
    var openingPane: SettingsPane? {
        switch self {
        case .empty, .error: .limits
        case .worst, .dialog: .clis
        case .normal, .refused: nil
        }
    }
}

/// What the panes read from the frame's store (AR2), as one value: the registry (CLIs pane), the status-line snapshot and
/// whether `limits.read` answered (Limits pane), and `journal.history` (the Journal window). A screenshot passes its own.
struct SettingsFacts: Equatable, Sendable {
    var registry: [CoreRegistryCLI] = []
    var statuslineAt: Date?
    /// Nil before the store has asked.
    var limits: FrameSourceState?
    var journal: CoreJournalHistory?
    var journalState: FrameSourceState?
    /// The CLIs the default Balance pins may take (`CLIPreferences.installedForBalance`); nil before `loadout.rows`.
    var installedForBalance: Set<String>?

    init(registry: [CoreRegistryCLI] = [], statuslineAt: Date? = nil, limits: FrameSourceState? = nil,
         journal: CoreJournalHistory? = nil, journalState: FrameSourceState? = nil) {
        self.registry = registry
        self.statuslineAt = statuslineAt
        self.limits = limits
        self.journal = journal
        self.journalState = journalState
    }

    @MainActor
    init(store: FrameStore?) {
        guard let store else { return }
        registry = store.snapshot.registry
        statuslineAt = FrameWorld.statuslineAt(store.snapshot)
        limits = store.states[.limits]
        journal = store.snapshot.journal
        journalState = store.states[.journal]
        installedForBalance = CLIPreferences.installedForBalance(store.snapshot.loadout?.folders)
    }
}

// MARK: CLIs

/// One line of Settings › CLIs: the logo, the name, what SpaceVibe can show for it, and its Show and Balance switches
/// (the mock's `cliRows`).
struct SettingsCLIRow: Identifiable, Equatable, Sendable {
    let cli: CLIIdentity
    /// "Skills · Subagents · Hooks · Rules · Logs · Limits", or "Nothing SpaceVibe can show".
    let supports: String
    let isShown: Bool
    /// False for the last shown CLI ("Show guard").
    let canChangeShow: Bool
    let isPinned: Bool
    /// False for a CLI without Skills or Subagents, and for an unpinned one while three are pinned.
    let canChangePin: Bool

    var id: String { cli.id }

    @MainActor
    static func rows(registry: [CoreRegistryCLI], preferences: CLIPreferences, installed: Set<String>? = nil) -> [SettingsCLIRow] {
        let hidden = preferences.hidden(in: registry)
        let shownCount = registry.filter { !hidden.contains($0.id) }.count
        let pins = preferences.pins(in: registry, installed: installed)
        return registry.map { cli in
            let isShown = !hidden.contains(cli.id)
            let canBalance = CLIPreferences.canBalance(cli)
            let isPinned = canBalance && pins.contains(cli.id)
            return SettingsCLIRow(
                cli: CLIIdentity(id: cli.id, name: cli.name), supports: supportText(cli.supports),
                isShown: isShown, canChangeShow: !(isShown && shownCount <= 1),
                isPinned: isPinned, canChangePin: canBalance && (isPinned || pins.count < CLIPreferences.maxPins))
        }
    }

    static func supportText(_ supports: CoreRegistrySupports) -> String {
        let parts: [(Bool, String)] = [(supports.skill, "Skills"), (supports.agent, "Subagents"), (supports.hook, "Hooks"),
                                       (supports.rule, "Rules"), (supports.logs, "Logs"), (supports.limits, "Limits")]
        let on = parts.filter(\.0).map(\.1)
        return on.isEmpty ? "Nothing SpaceVibe can show" : on.joined(separator: " · ")
    }

    /// The pane's footnote; a sentence more once three are pinned.
    static func footnote(pinCount: Int) -> String {
        let base = "Show hides a CLI from every list (one stays shown); removing a shared file still names it. Balance compares "
            + "the pinned CLIs: two to three, and only CLIs that hold Skills or Subagents."
        return pinCount >= CLIPreferences.maxPins ? base + " Three are pinned; unpin one to pin another." : base
    }

    /// The sentence for a refused switch, shown in the error toast.
    static func refusal(_ refusal: CLIPreferences.Refusal, name: String) -> String {
        switch refusal {
        case .lastShown: "\(name) is the only CLI shown; one stays shown. Nothing changed."
        case .cannotBalance: "\(name) holds no Skills or Subagents, so Balance cannot compare it. Nothing changed."
        case .pinsFull: "Three CLIs are pinned; unpin one to pin \(name). Nothing changed."
        }
    }
}

// MARK: Limits

/// Settings › Limits: the Weekly countdown lead (RD33) and the status-line capture's two copy commands (RD24, S-R4: the app
/// copies, the user runs them), with the age of the last snapshot.
enum SettingsLimitsWording {
    static let weeklyCountdown = "Weekly countdown"
    static let weeklyCountdownDetail = "How long before a Weekly Window resets its countdown starts. The 5-hour Window always counts its last hour."
    static let capture = "Status-line capture"
    static let footnote = "SpaceVibe copies the command; you run it in a terminal. Removing restores your original status line."
    static let copyInstall = "Copy Install Command"
    static let copyRemove = "Copy Remove Command"

    /// What the capture row says about the newest snapshot: its age, none yet, or that `limits.read` failed (Unmeasurable).
    static func snapshot(_ facts: SettingsFacts, now: Date) -> String {
        if let at = facts.statuslineAt { return "Last snapshot \(LimitsWording.ago(now.timeIntervalSince(at)))." }
        switch facts.limits {
        case .failed: return "Unmeasurable: the last snapshot could not be read."
        case .loading, nil: return "Reading the last snapshot\u{2026}"
        case .ready: return "No snapshot yet, so Claude Code Windows are Unmeasurable."
        }
    }

    /// The core's own sentence for a failed read, for the row's tooltip; nil otherwise.
    static func failure(_ facts: SettingsFacts) -> String? {
        if case .failed(let message) = facts.limits { return message }
        return nil
    }

    /// `'<helper>' statusline install` / `uninstall` for the core inside the app bundle (the same line as Limits).
    @MainActor
    static func command(remove: Bool, helper: URL = CoreEnvironment.binaryURL()) -> String {
        LimitsTab.captureCommand(helper: helper, subcommand: remove ? "uninstall" : "install")
    }
}

// MARK: Data

/// Settings › Data: SpaceVibe's own folder, the Journal and SpaceVibe's trash, shown and never emptied (RD25: emptying it
/// would end every pending Undo).
enum SettingsDataWording {
    static let dataFolder = "Data folder"
    static let journal = "Journal"
    static let journalDetail = "200 changes or 30 days, whichever ends first"
    static let showJournal = "Show Journal"
    static let trash = "SpaceVibe trash"
    static let trashDetail = "What you removed, kept so Undo can restore it: the last 200 changes or 30 days, whichever ends "
        + "first. A removed Hook leaves a copy of settings.json"
    static let showInFinder = "Show in Finder"
    static let trashMissing = "Nothing removed yet."

    /// SpaceVibe's data folder: `SPACEVIBE_HOME` in a development build that sets it, as the core resolves it
    /// (`roots.Resolve`), else `~/.spacevibe`.
    static func dataFolder(environment: [String: String] = ProcessInfo.processInfo.environment,
                           home: String = NSHomeDirectory(), overridesAllowed: Bool = CoreEnvironment.overridesAllowed()) -> URL {
        if overridesAllowed, let path = environment[CoreEnvironment.variable("HOME")], !path.isEmpty {
            return URL(fileURLWithPath: path, isDirectory: true)
        }
        return URL(fileURLWithPath: home, isDirectory: true).appendingPathComponent(".spacevibe", isDirectory: true)
    }

    /// Where removed items wait for Undo (`<data>/trash`, `mutate/trash.go`).
    static func trashFolder(in data: URL) -> URL { data.appendingPathComponent("trash", isDirectory: true) }

    /// "~/.spacevibe" for a folder under `home`.
    static func shown(_ url: URL, home: String = NSHomeDirectory()) -> String {
        let path = url.path
        guard path == home || path.hasPrefix(home + "/") else { return path }
        return "~" + path.dropFirst(home.count)
    }
}

// MARK: Updates

/// Settings › Updates: the version with Check Now, and Sparkle's daily check (S-R5: the only request the app makes). The status
/// words are v5's (`SettingsWording`), so both shells say the same.
enum SettingsUpdatesWording {
    static let version = "Version"
    static let daily = "Check once a day"
    static let dailyDetail = "Only network request the app makes"
    static let checkNow = "Check Now"
    static let viewUpdate = "View Update"

    /// "SpaceVibe 0.2.0 · build 3 · Up to date · Checked today at 14:02".
    @MainActor
    static func versionLine(_ updates: UpdateController, now: Date) -> String {
        let name = SettingsWording.appName(version: updates.version)
        let parts = [updates.build.map { "\(name) · build \($0)" } ?? name,
                     SettingsWording.tag(updates.status)?.text,
                     SettingsWording.lastCheck(updates.status, at: updates.lastCheck, now: now)]
        return parts.compactMap { $0 }.joined(separator: " · ")
    }

    /// The reason this launch cannot update, shown under the daily switch; nil while it can.
    @MainActor
    static func unavailable(_ updates: UpdateController) -> String? {
        if case .unavailable(let reason) = updates.status { return reason }
        return nil
    }
}
