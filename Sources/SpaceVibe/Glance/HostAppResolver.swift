import AppKit
import Darwin

/// The GUI app that hosts a CLI session: the nearest ancestor of the session's pid that macOS runs as a regular app
/// (iTerm, Ghostty, Terminal, VS Code, SpaceVibe Deck…). Spec `docs/specs/2026-11-19-session-glance-widget.md`, GW-R6.
struct HostApp: Equatable, Sendable {
    let pid: pid_t
    let bundleIdentifier: String?
    /// The localized app name, for display only.
    let name: String?
}

/// The two facts the walk reads about a process. Tests inject a table; the app uses `LiveHostProcessTable`.
protocol HostProcessTable: Sendable {
    /// The parent pid of `pid`, or nil when it cannot be read (the process is gone, or the read failed).
    func parent(of pid: pid_t) -> pid_t?
    /// The app at `pid` when it is a regular GUI app (Dock icon, menu bar), otherwise nil.
    func regularApp(at pid: pid_t) -> HostApp?
}

/// Reads the live process table in process. It starts nothing and signals nothing (S-R4): the parent pid comes from
/// `sysctl(KERN_PROC_PID)` and the app from `NSRunningApplication`.
struct LiveHostProcessTable: HostProcessTable {
    func parent(of pid: pid_t) -> pid_t? {
        guard pid > 0 else { return nil }
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        let status = mib.withUnsafeMutableBufferPointer { name in
            sysctl(name.baseAddress, u_int(name.count), &info, &size, nil, 0)
        }
        // A pid with no process answers success with a size of zero.
        guard status == 0, size > 0 else { return nil }
        return info.kp_eproc.e_ppid
    }

    func regularApp(at pid: pid_t) -> HostApp? {
        guard pid > 0,
              let app = NSRunningApplication(processIdentifier: pid),
              app.activationPolicy == .regular,
              !app.isTerminated
        else { return nil }
        return HostApp(pid: pid, bundleIdentifier: app.bundleIdentifier, name: app.localizedName)
    }
}

/// Finds the host app of a session and brings it forward. With no host app (tmux, screen, ssh, a dead parent) the caller
/// opens SpaceVibe's Activity at that session instead (GW6).
enum HostAppResolver {
    /// The most pids one walk examines, the session's own included. Real chains are a handful deep (shell, login,
    /// terminal); the cap only bounds a table that keeps answering.
    static let maxDepth = 64

    /// The session pid itself when it is a regular app, else the nearest regular-app ancestor. Nil at pid 1 (launchd) or
    /// below, on a failed parent read, on a pid seen twice, or once `maxDepth` pids have been examined.
    static func hostApp(
        of sessionPid: pid_t,
        in table: some HostProcessTable = LiveHostProcessTable(),
        maxDepth: Int = maxDepth
    ) -> HostApp? {
        var pid = sessionPid
        var seen = Set<pid_t>()
        while pid > 1, seen.count < maxDepth, seen.insert(pid).inserted {
            if let app = table.regularApp(at: pid) { return app }
            guard let parent = table.parent(of: pid) else { return nil }
            pid = parent
        }
        return nil
    }

    /// Brings `app` forward. Returns false when it has quit or is no longer a regular app, or when macOS refuses the
    /// request. Never sends a signal and never starts a process (S-R4).
    @MainActor
    @discardableResult
    static func activate(_ app: HostApp) -> Bool {
        guard let running = NSRunningApplication(processIdentifier: app.pid),
              running.activationPolicy == .regular,
              !running.isTerminated
        else { return false }
        if running.isHidden { running.unhide() }
        // Cooperative activation (macOS 14+): SpaceVibe hands its active status over, then asks for the switch. When
        // SpaceVibe is not the active app there is nothing to yield, so the plain request is the fallback.
        NSApp?.yieldActivation(to: running)
        if running.activate(from: .current, options: []) { return true }
        return running.activate(options: [])
    }
}
