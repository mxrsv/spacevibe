import Foundation

/// What one CLI's logo toggle shows for one Skill or Subagent (RD-R11, RD16, RD21/D53, RD31, RD-R10; the mock's `tglBtn` and
/// `tileInspector`). The row's logo and the inspector's tile take the same value, so they cannot disagree (RD-R12). Pure: the
/// shell model fills it from the readers map (RB-E2) and the cells (RB-E1); the block only draws it.
struct CLIToggleState: Hashable, Sendable {
    /// Whether the CLI has the item.
    enum Presence: Hashable, Sendable {
        /// The CLI loads the item; `usage` is what its logs say.
        case on(Usage)
        /// The CLI supports the concept and does not have the item: pressing adds it.
        case off
        /// The CLI has no such concept (`noun` is the page's plural: "Subagents"). A dash, no button (RD-R10).
        case notSupported(noun: String)
        /// The CLI's folder could not be read: every cell of it is unknown, Missing included (RD-R10).
        case unreadable
    }

    enum Usage: Hashable, Sendable {
        case sessions(Int)
        /// No scanned log shows it.
        case neverRan
        /// The CLI loads it but keeps no log SpaceVibe can count: never 0 (RD-R10).
        case unmeasurable
        /// The first usage scan is still running: the count is pending, and nothing can be pressed yet.
        case pending
    }

    /// Why a lit logo is not a toggle.
    enum Hold: Hashable, Sendable {
        case none
        /// The CLI reads the item only through these CLIs' folders (RD31): a link badge; `Remove…` removes it.
        case via([String])
        /// Turning it off would delete the item's last copy (D53, counted by files): a bar under the logo; `Remove…` is the
        /// explicit action.
        case lastCopy
        /// A plugin or a project owns the item (`owner`: "plugin", "project payments-web"): read-only, a lock on a lit logo.
        case readOnly(owner: String)
        /// Off, and the CLI owns no folder of the kind SpaceVibe copies into (`folder`: "skills", "agents"; the readers map's
        /// `copyTarget`), so Add would only be refused: faded like Not supported, not a toggle, and its label says why.
        case noCopyTarget(folder: String)
    }

    let cli: CLIIdentity
    var presence: Presence
    var hold: Hold = .none
    /// The other CLIs that read the same file (named before a removal, RD-R11 "Shared files").
    var sharedWith: [String] = []
    /// This CLI's own folder holds the file: only the owner carries the Never ran dot (RD16).
    var ownsFile = true

    // MARK: Derived

    /// Pressing it writes: a lit logo with nothing holding it, or an off logo of an item no plugin or project owns.
    var isToggle: Bool {
        switch presence {
        case .on(let usage): usage != .pending && hold == .none
        case .off: hold == .none
        case .notSupported, .unreadable: false
        }
    }

    /// The logo is drawn: everything but Not supported, which is a dash.
    var drawsLogo: Bool { if case .notSupported = presence { false } else { true } }

    var isOn: Bool { if case .on = presence { true } else { false } }

    /// The amber dot: on, never ran, and only on the CLI that owns the file.
    var showsNeverRanDot: Bool { presence == .on(.neverRan) && ownsFile }

    enum Badge: Hashable, Sendable {
        case lock, link, unknown
    }

    /// The small mark at the logo's corner. A plugin's or project's item carries the lock only where it is lit: an off logo or
    /// tile of it is plain, just not a toggle (the mock's `tglBtn` and `tileInspector` draw no lock on an off one).
    var badge: Badge? {
        if presence == .unreadable { return .unknown }
        switch hold {
        case .readOnly: return isOn ? .lock : nil
        case .via: return isOn ? .link : nil
        case .none, .lastCopy, .noCopyTarget: return nil
        }
    }

    /// The bar under a last-copy logo.
    var showsLastCopyBar: Bool { isOn && hold == .lastCopy }

    /// The success check on a tile (RD-R12): on, and not held by a plugin or another CLI's folder (the mock's `data-ok`).
    var showsCheck: Bool {
        guard isOn else { return false }
        switch hold {
        case .readOnly, .via, .noCopyTarget: return false
        case .none, .lastCopy: return true
        }
    }

    /// How the logo is faded, one opacity role per job (DS-R7, RD49), the same on a row's toggle and on a tile: lit at full,
    /// off at `dim` (brightening to full under the pointer, as the press would make it), an off logo with nowhere to copy into
    /// and an unreadable one at `disabled` (they take no press), Not supported at `ghost`.
    enum Fade: Hashable, Sendable {
        case none, dim, disabled, ghost

        func opacity(hovered: Bool) -> Double {
            switch self {
            case .none: 1
            case .dim: hovered ? 1 : OpacityRole.dim
            case .disabled: OpacityRole.disabled
            case .ghost: OpacityRole.ghost
            }
        }
    }

    var fade: Fade {
        switch presence {
        case .on: .none
        case .off: Self.cannotAdd(hold) ? .disabled : .dim
        case .unreadable: .disabled
        case .notSupported: .ghost
        }
    }

    /// The state VoiceOver reads after the CLI's name, and the tooltip after "<name>: " (RD-R16 names and state): "On, 31
    /// sessions, shared file with Cursor CLI", "On, never ran here, only copy; remove it with Remove…", "Off, click to add",
    /// "Not supported", "Unmeasurable, folder could not be read".
    var spokenState: String {
        switch presence {
        case .notSupported: return "Not supported"
        case .unreadable: return "Unmeasurable, folder could not be read"
        case .off:
            switch hold {
            case .readOnly(let owner): return "Off, read-only (\(owner))"
            case .noCopyTarget(let folder): return "Off, no \(folder) folder of its own to copy into"
            case .none, .via, .lastCopy: return "Off, click to add"
            }
        case .on(let usage):
            var parts = ["On", Self.usageText(usage)]
            switch hold {
            case .via(let through): parts.append("via \(CLINames.sentence(through))’s folder; remove it with Remove…")
            case .lastCopy: parts.append("only copy; remove it with Remove…")
            case .none: if !sharedWith.isEmpty { parts.append("shared file with \(CLINames.sentence(sharedWith))") }
            case .readOnly(let owner): parts.append("read-only (\(owner))")
            case .noCopyTarget: break
            }
            return parts.joined(separator: ", ")
        }
    }

    /// While the toggle's own write runs: what the tooltip and VoiceOver say, and whether a press goes through (it does not:
    /// the pending toggle ignores it, and stays drawn pending, so nothing is sent twice).
    static let pendingTooltip = "Writing\u{2026}"
    static let pendingSpoken = "Writing, wait for it to finish"
    static func acceptsPress(isPending: Bool) -> Bool { !isPending }

    /// The tooltip: "Claude Code: On, 31 sessions"; Not supported says what is missing ("Amp has no Subagents").
    var tooltip: String {
        if case .notSupported(let noun) = presence { return "\(cli.name) has no \(noun)" }
        return "\(cli.name): \(spokenState)"
    }

    /// The figure a tile shows under the name: the session count, `?` when unmeasurable, `…` while pending, "Add" when off,
    /// a dash when Not supported or when it cannot be added. The inspector's tile shows the full count (`4,830,112`, RD53);
    /// only the list's narrow cells keep `4.8M`.
    var tileFigure: String {
        switch presence {
        case .on(.sessions(let n)): NumberWording.count(n)
        case .on(.neverRan): NumberWording.count(0)
        case .on(.unmeasurable), .unreadable: "?"
        case .on(.pending): "…"
        case .off: Self.cannotAdd(hold) ? NumberWording.missing : "Add"
        case .notSupported: NumberWording.missing
        }
    }

    /// The `?` figure is drawn as the question glyph, as the mock's tile draws `ic('question', 12)`: an unreadable CLI and a lit
    /// one that keeps no log.
    var tileFigureIsUnknown: Bool { presence == .unreadable || presence == .on(.unmeasurable) }

    /// Sessions the heat step counts: only measured sessions of a lit logo.
    var measuredSessions: Int {
        if case .on(.sessions(let n)) = presence { return max(0, n) }
        return 0
    }

    static func usageText(_ usage: Usage) -> String {
        switch usage {
        case .sessions(let n): n == 0 ? "never ran here" : NumberWording.plural(n, "session")
        case .neverRan: "never ran here"
        case .unmeasurable: "sessions Unmeasurable (no log)"
        case .pending: "counting sessions"
        }
    }

    private static func cannotAdd(_ hold: Hold) -> Bool { if case .noCopyTarget = hold { true } else { false } }
}
