import Darwin
import Testing
@testable import SpaceVibe

/// The host-app walk (GW-R6): nearest regular-app ancestor of a session's pid, or nil when there is none.
@Suite("Host app resolver")
struct HostAppResolverTests {
    /// An injected process table: `parents` maps a pid to its parent (a missing pid is a failed read), `apps` lists the
    /// pids that are regular apps.
    struct FakeTable: HostProcessTable {
        var parents: [pid_t: pid_t]
        var apps: [pid_t: String] = [:]

        func parent(of pid: pid_t) -> pid_t? { parents[pid] }

        func regularApp(at pid: pid_t) -> HostApp? {
            apps[pid].map { HostApp(pid: pid, bundleIdentifier: $0, name: nil) }
        }
    }

    static let terminal = "com.example.terminal"

    @Test("the direct parent is the app")
    func directParent() {
        let table = FakeTable(parents: [500: 400, 400: 1], apps: [400: Self.terminal])
        #expect(HostAppResolver.hostApp(of: 500, in: table)?.pid == 400)
    }

    @Test("a deep chain reaches the terminal app through shell and login")
    func deepChain() {
        // claude (900) → zsh (800) → login (700) → terminal (600) → launchd.
        let table = FakeTable(parents: [900: 800, 800: 700, 700: 600, 600: 1], apps: [600: Self.terminal])
        let app = HostAppResolver.hostApp(of: 900, in: table)
        #expect(app == HostApp(pid: 600, bundleIdentifier: Self.terminal, name: nil))
    }

    @Test("the nearest app wins over an app further up")
    func nearestApp() {
        let table = FakeTable(parents: [900: 800, 800: 700, 700: 1], apps: [800: "com.example.editor", 700: Self.terminal])
        #expect(HostAppResolver.hostApp(of: 900, in: table)?.pid == 800)
    }

    @Test("a tmux-like chain that reaches launchd has no host app")
    func tmuxChain() {
        // claude (900) → zsh (800) → tmux server (700) → launchd (1). The terminal app holds only the tmux client.
        let table = FakeTable(parents: [900: 800, 800: 700, 700: 1, 600: 1], apps: [600: Self.terminal])
        #expect(HostAppResolver.hostApp(of: 900, in: table) == nil)
    }

    @Test("a loop in the parent chain stops the walk")
    func loop() {
        let table = FakeTable(parents: [900: 800, 800: 700, 700: 900])
        #expect(HostAppResolver.hostApp(of: 900, in: table) == nil)
    }

    @Test("a pid that is its own parent stops the walk")
    func selfParent() {
        let table = FakeTable(parents: [900: 900])
        #expect(HostAppResolver.hostApp(of: 900, in: table) == nil)
    }

    @Test("a failed parent read stops the walk")
    func failedRead() {
        // 800's parent cannot be read, so the app at 600 is never reached.
        let table = FakeTable(parents: [900: 800, 700: 600], apps: [600: Self.terminal])
        #expect(HostAppResolver.hostApp(of: 900, in: table) == nil)
    }

    @Test("the walk gives up after the max depth")
    func maxDepth() {
        // A chain 2...(depth + 2) going up, with the app one step past the cap.
        let depth = 5
        let top = pid_t(depth + 2)
        var parents: [pid_t: pid_t] = [:]
        for pid in pid_t(2)..<top { parents[pid] = pid + 1 }
        parents[top] = 1
        let table = FakeTable(parents: parents, apps: [top: Self.terminal])
        // Session at 2: the app at `top` is the (depth + 1)th pid examined.
        #expect(HostAppResolver.hostApp(of: 2, in: table, maxDepth: depth) == nil)
        // One more step allowed reaches it, so the cap is the only thing that stopped the walk.
        #expect(HostAppResolver.hostApp(of: 2, in: table, maxDepth: depth + 1)?.pid == top)
    }

    @Test("the default max depth is a positive constant")
    func defaultDepth() {
        #expect(HostAppResolver.maxDepth > 0)
    }

    @Test("a session pid that is itself a regular app is its own host")
    func sessionIsApp() {
        let table = FakeTable(parents: [900: 1], apps: [900: Self.terminal])
        #expect(HostAppResolver.hostApp(of: 900, in: table)?.pid == 900)
    }

    @Test("pid 1 and below have no host app")
    func launchdAndInvalid() {
        let table = FakeTable(parents: [1: 0, 0: 0], apps: [1: Self.terminal, 0: Self.terminal])
        #expect(HostAppResolver.hostApp(of: 1, in: table) == nil)
        #expect(HostAppResolver.hostApp(of: 0, in: table) == nil)
        #expect(HostAppResolver.hostApp(of: -1, in: table) == nil)
    }

    /// Reads only; activates nothing.
    @Test("the live table reads this process's parent pid")
    func liveParent() {
        let table = LiveHostProcessTable()
        #expect(table.parent(of: getpid()) == getppid())
        #expect(table.parent(of: -1) == nil)
    }
}
