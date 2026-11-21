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
        /// A plugin or a project owns the item (`owner`: "plugin", "project payments-web"): a lock, read-only.
        case readOnly(owner: String)
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
        case .off: !Self.isReadOnly(hold)
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

    /// The small mark at the logo's corner.
    var badge: Badge? {
        if presence == .unreadable { return .unknown }
        switch hold {
        case .readOnly: return .lock
        case .via: return isOn ? .link : nil
        case .none, .lastCopy: return nil
        }
    }

    /// The bar under a last-copy logo.
    var showsLastCopyBar: Bool { isOn && hold == .lastCopy }

    /// The success check on a tile (RD-R12): on, and not held by a plugin or another CLI's folder (the mock's `data-ok`).
    var showsCheck: Bool {
        guard isOn else { return false }
        switch hold {
        case .readOnly, .via: return false
        case .none, .lastCopy: return true
        }
    }

    /// How the logo is faded: off at `dim`, Not supported and unreadable at `ghost`, lit at full.
    enum Fade: Hashable, Sendable { case none, dim, ghost }

    var fade: Fade {
        switch presence {
        case .on: .none
        case .off: .dim
        case .notSupported, .unreadable: .ghost
        }
    }

    /// The state VoiceOver reads after the CLI's name, and the tooltip after "<name>: " (RD-R16 names and state): "On, 31
    /// sessions, shared file with Cursor CLI", "On, never ran here, only copy; remove it with Remove…", "Off, click to add",
    /// "Not supported", "Unmeasurable, folder could not be read".
    var spokenState: String {
        switch presence {
        case .notSupported: return "Not supported"
        case .unreadable: return "Unmeasurable, folder could not be read"
        case .off: return Self.isReadOnly(hold) ? "Off, read-only (\(Self.owner(hold)))" : "Off, click to add"
        case .on(let usage):
            var parts = ["On", Self.usageText(usage)]
            switch hold {
            case .via(let through): parts.append("via \(CLINames.sentence(through))’s folder; remove it with Remove…")
            case .lastCopy: parts.append("only copy; remove it with Remove…")
            case .none: if !sharedWith.isEmpty { parts.append("shared file with \(CLINames.sentence(sharedWith))") }
            case .readOnly(let owner): parts.append("read-only (\(owner))")
            }
            return parts.joined(separator: ", ")
        }
    }

    /// The tooltip: "Claude Code: On, 31 sessions"; Not supported says what is missing ("Amp has no Subagents").
    var tooltip: String {
        if case .notSupported(let noun) = presence { return "\(cli.name) has no \(noun)" }
        return "\(cli.name): \(spokenState)"
    }

    /// The figure a tile shows under the name: the session count, `?` when unmeasurable, `…` while pending, "Add" when off,
    /// a dash when Not supported.
    var tileFigure: String {
        switch presence {
        case .on(.sessions(let n)): NumberWording.compactCount(n)
        case .on(.neverRan): NumberWording.count(0)
        case .on(.unmeasurable), .unreadable: "?"
        case .on(.pending): "…"
        case .off: "Add"
        case .notSupported: NumberWording.missing
        }
    }

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

    private static func isReadOnly(_ hold: Hold) -> Bool { if case .readOnly = hold { true } else { false } }
    private static func owner(_ hold: Hold) -> String { if case .readOnly(let owner) = hold { owner } else { "" } }
}
