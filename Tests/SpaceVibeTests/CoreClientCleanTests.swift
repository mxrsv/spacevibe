import Foundation
import Testing
@testable import SpaceVibe

/// `clean.scan` and `clean.move` through `CoreClient` against the real Go core on a private fixture copy (S-R1; under
/// `SPACEVIBE_TEST=1` the Trash is `<data>/test-trash`): the params reach the core as it takes them, `clean/progress` reaches
/// the caller, the move is one Journal entry and its Undo puts every file back.
@Suite("CoreClient, Clean")
struct CoreClientCleanTests {
    /// Logs dated before every age bucket, as the contract case does.
    private static let oldLogs = [".claude/projects/-work-spacevibe-api/session-010.jsonl", ".claude/projects/-work-spacevibe-api/session-013.jsonl",
                                  ".codex/sessions/2026/10/rollout-014.jsonl"]

    private final class Notes: @unchecked Sendable {
        private let lock = NSLock()
        private var _notes: [CoreCleanProgress] = []
        var notes: [CoreCleanProgress] { lock.withLock { _notes } }
        func add(_ note: CoreCleanProgress) { lock.withLock { _notes.append(note) } }
    }

    @Test("scan, move the open log buckets with progress, Undo puts them back", .timeLimit(.minutes(1)))
    func moveThenUndo() async throws {
        let fixture = try await CoreFixtureHome.make()
        let client = try fixture.client()
        defer {
            client.shutdown()
            fixture.remove()
        }
        let old = Date(timeIntervalSince1970: 1_735_732_800) // 2025-01-01T12:00:00Z
        for log in Self.oldLogs {
            try FileManager.default.setAttributes([.modificationDate: old], ofItemAtPath: fixture.home.appendingPathComponent(log).path)
        }
        let before = try await client.cleanScan()
        #expect(before.clis.map(\.cli) == ["claude", "codex"])
        let open = before.clis.filter { $0.locks.logs == nil && $0.logs.buckets.contains { $0.olderThanDays == 180 } }
        try #require(!open.isEmpty, "the fixture has an unlocked CLI with logs older than 180 days")
        let picks = open.map { CoreCleanLogPick(cli: $0.cli, olderThanDays: 180) }
        let expected = open.compactMap { $0.logs.buckets.first { $0.olderThanDays == 180 } }
        let notes = Notes()
        let result = try await client.cleanMove(logs: picks, caches: [], progress: { notes.add($0) })
        #expect(!result.cancelled && result.entry != nil && result.trash?.contains("SpaceVibe Clean") == true)
        #expect(result.moved.files == expected.map(\.files).reduce(0, +))
        #expect(result.moved.bytes == expected.map(\.bytes).reduce(0, +), "the move reports what the scan measured (CL-R6)")
        #expect(notes.notes.contains { $0.phase == "moving" && $0.done == $0.total }, "clean/progress reaches the caller")
        for log in Self.oldLogs where open.contains(where: { log.hasPrefix(".\($0.cli)/") }) {
            #expect(!FileManager.default.fileExists(atPath: fixture.home.appendingPathComponent(log).path), "\(log) moved")
        }
        let after = try await client.cleanScan()
        #expect(after.clis.filter { picks.map(\.cli).contains($0.cli) }.allSatisfy { !$0.logs.buckets.contains { $0.olderThanDays == 180 } })
        _ = try await client.journalUndo(id: try #require(result.entry).id)
        for log in Self.oldLogs { #expect(FileManager.default.fileExists(atPath: fixture.home.appendingPathComponent(log).path), "\(log) is back") }
        #expect(try await client.cleanScan().clis.map(\.logs) == before.clis.map(\.logs))
    }

    @Test("bad picks are the core's 400 with its sentence; nothing to move is its 409", .timeLimit(.minutes(1)))
    func refusals() async throws {
        let fixture = try await CoreFixtureHome.make()
        let client = try fixture.client()
        defer {
            client.shutdown()
            fixture.remove()
        }
        let age = try await #require(throws: CoreError.self) { try await client.cleanMove(logs: [CoreCleanLogPick(cli: "claude", olderThanDays: 60)], caches: [], progress: nil) }
        #expect(age.status == 400 && age.message == "olderThanDays must be 30, 90 or 180.")
        let none = try await #require(throws: CoreError.self) { try await client.cleanMove(logs: [], caches: [], progress: nil) }
        #expect(none.status == 400)
        let empty = try await #require(throws: CoreError.self) { try await client.cleanMove(logs: [], caches: ["codex:cache"], progress: nil) }
        #expect(empty.status == 409)
    }
}
