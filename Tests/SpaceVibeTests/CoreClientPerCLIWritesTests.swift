import Foundation
import Testing
@testable import SpaceVibe

/// The new frame's writes through `CoreClient` against the real Go core (RB-E3, RB-E4, RB-E5): each method's params reach
/// the core as it takes them (params are strict) and its answer decodes. Each test has its own fixture home and client.
@Suite("CoreClient, per-CLI, batch and Keep writes")
struct CoreClientPerCLIWritesTests {
    /// A Claude Code skill Codex does not have in the fixture home.
    private static let tdd = "claude:skill:local:tdd"

    private func withClient<T>(_ body: (CoreClient) async throws -> T) async throws -> T {
        let fixture = try await CoreFixtureHome.make()
        let client = try fixture.client()
        defer {
            client.shutdown()
            fixture.remove()
        }
        return try await body(client)
    }

    private func codexCell(_ client: CoreClient) async throws -> CoreCLICell? {
        let rows = try await client.loadoutRows()
        return (rows.items + rows.extraItems).first { $0.key == "skill::tdd" }?.cliCells?["codex"]
    }

    @Test("copyTo gives Codex the skill, removeFrom takes it back naming who lost and who still has it, Undo restores", .timeLimit(.minutes(1)))
    func copyThenRemoveFrom() async throws {
        try await withClient { client in
            #expect(try await codexCell(client) == .missing)
            let copied = try await client.loadoutCopyTo(id: Self.tdd, targets: ["codex"])
            #expect(copied.alsoReaders.isEmpty && copied.entry.count == 1)
            #expect(try await codexCell(client).map { $0 != .missing } == true)
            let removed = try await client.loadoutRemoveFrom(id: Self.tdd, clis: ["codex"])
            #expect(removed.lost == ["codex"] && removed.stillHave == ["claude"])
            #expect(try await codexCell(client) == .missing)
            _ = try await client.journalUndo(id: removed.entry.id)
            #expect(try await codexCell(client).map { $0 != .missing } == true)
        }
    }

    @Test("removeMany takes exactly the ids as one entry; a target the core cannot write is its 400", .timeLimit(.minutes(1)))
    func removeMany() async throws {
        try await withClient { client in
            let refused = try await #require(throws: CoreError.self) { try await client.loadoutCopyTo(id: Self.tdd, targets: ["gemini"]) }
            #expect(refused.status == 400)
            let removed = try await client.loadoutRemoveMany(ids: [Self.tdd])
            #expect(removed.lost == ["claude"] && removed.entry.count == 1)
            #expect(try await client.loadoutRows().items.contains { $0.id == Self.tdd } == false)
            _ = try await client.journalUndo(id: removed.entry.id)
            #expect(try await client.loadoutRows().items.contains { $0.id == Self.tdd })
        }
    }

    @Test("rules.removeMany removes the picked rules of one file in one edit", .timeLimit(.minutes(1)))
    func rulesRemoveMany() async throws {
        try await withClient { client in
            for rule in ["Bash(sv-one)", "Bash(sv-two)"] { _ = try await client.rulesAdd(scope: .global, dir: nil, verdict: .allow, rule: rule) }
            let entry = try await client.rulesRemoveMany(scope: .global, dir: nil, ids: ["global:allow:Bash(sv-one)", "global:allow:Bash(sv-two)"]).entry
            #expect(entry.count == 1)
            let rules = try await client.rulesSnapshot(scope: .global, dir: nil, refreshProjects: false).rules
            #expect(!rules.contains { $0.rule.hasPrefix("Bash(sv-") })
        }
    }

    @Test("the Keep list starts empty, keeps and stops keeping an id, refuses a second keep, and Undo puts it back", .timeLimit(.minutes(1)))
    func keepList() async throws {
        try await withClient { client in
            #expect(try await client.findingsKept().kept.isEmpty)
            _ = try await client.findingsKeep(id: "W:claude:5-hour:1800000000")
            #expect(try await client.findingsKept().kept == ["W:claude:5-hour:1800000000"])
            let again = try await #require(throws: CoreError.self) { try await client.findingsKeep(id: "W:claude:5-hour:1800000000") }
            #expect(again.status == 409)
            let unkept = try await client.findingsUnkeep(id: "W:claude:5-hour:1800000000").entry
            #expect(try await client.findingsKept().kept.isEmpty)
            _ = try await client.journalUndo(id: unkept.id)
            #expect(try await client.findingsKept().kept == ["W:claude:5-hour:1800000000"])
        }
    }
}
