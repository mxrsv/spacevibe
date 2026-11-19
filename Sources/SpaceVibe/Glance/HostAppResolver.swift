import AppKit
import Darwin

/// The GUI app that hosts a CLI session: the nearest ancestor of the session's pid that macOS runs as a regular app
/// (iTerm, Ghostty, Terminal, VS Code, SpaceVibe Deck…), or the regular app whose bundle an ancestor runs from (Orca). Spec `docs/specs/2026-11-19-session-glance-widget.md`, GW-R6.
struct HostApp: Equatable, Sendable {
    let pid: pid_t
    let bundleIdentifier: String?
    /// The localized app name, for display only.
    let name: String?
}

/// What the walk reads about a process. Tests inject a table; the app uses `LiveHostProcessTable`.
protocol HostProcessTable: Sendable {
    /// The parent pid of `pid`, or nil when it cannot be read (the process is gone, or the read failed).
    func parent(of pid: pid_t) -> pid_t?
    /// The app at `pid` when it is a regular GUI app (Dock icon, menu bar), otherwise nil.
    func regularApp(at pid: pid_t) -> HostApp?
    /// The absolute path of the executable `pid` runs, or nil when it cannot be read.
    func executablePath(of pid: pid_t) -> String?
    /// The `CFBundleIdentifier` of the bundle at `bundlePath`, or nil when it has none or cannot be read.
    func bundleIdentifier(ofBundleAt bundlePath: String) -> String?
    /// A running regular app with that bundle id, or nil. With several, the active one, else the most recently launched.
    func regularApp(withBundleIdentifier bundleIdentifier: String) -> HostApp?
}

/// Reads the live process table in process. It starts nothing and signals nothing (S-R4): the parent pid comes from
/// `sysctl(KERN_PROC_PID)`, the executable path from `proc_pidpath` (libproc), the bundle id from the bundle's
/// `Info.plist`, and the app from `NSRunningApplication`.
struct LiveHostProcessTable: HostProcessTable {
    /// `PROC_PIDPATHINFO_MAXSIZE` (`4 * MAXPATHLEN`), a macro Swift does not import.
    private static let pathBufferSize = Int(MAXPATHLEN) * 4

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

    func executablePath(of pid: pid_t) -> String? {
        guard pid > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: Self.pathBufferSize)
        let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        return String(cString: buffer)
    }

    func bundleIdentifier(ofBundleAt bundlePath: String) -> String? {
        Bundle(url: URL(fileURLWithPath: bundlePath, isDirectory: true))?.bundleIdentifier
    }

    func regularApp(withBundleIdentifier bundleIdentifier: String) -> HostApp? {
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            .filter { $0.activationPolicy == .regular && !$0.isTerminated }
        let pick = apps.first(where: \.isActive)
            ?? apps.max { ($0.launchDate ?? .distantPast) < ($1.launchDate ?? .distantPast) }
        return pick.map { HostApp(pid: $0.processIdentifier, bundleIdentifier: $0.bundleIdentifier, name: $0.localizedName) }
    }
}

/// Finds the host app of a session and brings it forward. With no host app (tmux, screen, ssh, a dead parent) the caller
/// opens SpaceVibe's Activity at that session instead (GW6).
enum HostAppResolver {
    /// The most pids one walk examines, the session's own included. Real chains are a handful deep (shell, login,
    /// terminal); the cap only bounds a table that keeps answering.
    static let maxDepth = 64

    /// The nearest ancestor of `sessionPid` that is a regular app, or that runs from inside the bundle of a running
    /// regular app. Nil when the session pid is itself a regular app (a CLI session never is, so the pid is stale or was
    /// reused), at pid 1 (launchd) or below, on a failed parent read, on a pid seen twice, or once `maxDepth` pids have been
    /// examined.
    static func hostApp(
        of sessionPid: pid_t,
        in table: some HostProcessTable = LiveHostProcessTable(),
        maxDepth: Int = maxDepth
    ) -> HostApp? {
        guard sessionPid > 1, maxDepth > 0, table.regularApp(at: sessionPid) == nil,
              var pid = table.parent(of: sessionPid)
        else { return nil }
        var seen: Set<pid_t> = [sessionPid]
        while pid > 1, seen.count < maxDepth, seen.insert(pid).inserted {
            if let app = table.regularApp(at: pid) ?? bundleApp(at: pid, in: table) { return app }
            guard let parent = table.parent(of: pid) else { return nil }
            pid = parent
        }
        return nil
    }

    /// A process macOS does not list as a regular app but that runs from inside an app bundle: a terminal host or helper
    /// app (Orca's `Orca Agents.app`, `LSUIElement`, sharing the bundle id of `Orca.app`). The host is the running regular
    /// app with the same bundle id as the outermost bundle around its executable.
    private static func bundleApp(at pid: pid_t, in table: some HostProcessTable) -> HostApp? {
        guard let path = table.executablePath(of: pid),
              let bundle = enclosingAppBundle(of: path),
              let identifier = table.bundleIdentifier(ofBundleAt: bundle)
        else { return nil }
        return table.regularApp(withBundleIdentifier: identifier)
    }

    /// The outermost `*.app` directory around `executablePath` that has a `Contents` folder on the path
    /// (`/Applications/Orca.app/Contents/Frameworks/Orca Helper.app/Contents/MacOS/Orca Helper` → `/Applications/Orca.app`).
    /// Nil for a path outside any app bundle (`/bin/zsh`, `/usr/bin/login`) or one that is not absolute.
    static func enclosingAppBundle(of executablePath: String) -> String? {
        guard executablePath.hasPrefix("/") else { return nil }
        let components = executablePath.split(separator: "/", omittingEmptySubsequences: true)
        guard let index = components.indices.dropLast().first(where: {
            components[$0].hasSuffix(".app") && components[$0].count > 4 && components[$0 + 1] == "Contents"
        }) else { return nil }
        return "/" + components[...index].joined(separator: "/")
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
