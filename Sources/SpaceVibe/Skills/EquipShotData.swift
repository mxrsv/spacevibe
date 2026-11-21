import Foundation

/// Synthetic `clis.registry` and `loadout.rows` for the Skills and Subagents shots (`EquipFrameShots`) and the many-CLI tests:
/// the reference mock's items (`src/a-core.js` SKILLS, SUBS, EXT; synthetic names only, S-R2) at 2, 6 and 10 CLIs. The engine
/// reads two CLIs today; the 6 and 10 CLI sets, their folders and who reads them are an illustration of RD13/RD28 (RD42), never
/// shown outside shot mode and tests.
enum EquipShotData {
    /// The CLIs, as the mock's research report gives them (`SUPPORT`, `CLIN`): 2 is today's registry.
    static func registry(count: Int) -> [CoreRegistryCLI] {
        let all: [(String, String, CoreRegistrySupports)] = [
            ("claude", "Claude Code", supports(skill: true, agent: true, hook: true, rule: true, logs: true, limits: true)),
            ("codex", "Codex", supports(skill: true, agent: true, hook: true, rule: true, logs: true, limits: true)),
            ("cursor", "Cursor CLI", supports(skill: true, agent: true, hook: true, rule: true, logs: false, limits: false)),
            ("copilot", "Copilot CLI", supports(skill: true, agent: true, hook: true, rule: false, logs: true, limits: true)),
            ("opencode", "opencode", supports(skill: true, agent: true, hook: false, rule: true, logs: false, limits: false)),
            ("amp", "Amp", supports(skill: true, agent: false, hook: false, rule: true, logs: false, limits: false)),
            ("antigravity", "Antigravity CLI", supports(skill: true, agent: true, hook: true, rule: false, logs: false, limits: false)),
            ("kiro", "Kiro", supports(skill: true, agent: true, hook: true, rule: true, logs: false, limits: false)),
            ("qwen", "Qwen Code", supports(skill: false, agent: true, hook: false, rule: false, logs: false, limits: false)),
            ("aider", "Aider", supports(skill: false, agent: false, hook: false, rule: false, logs: false, limits: false)),
        ]
        return all.prefix(max(2, min(count, all.count))).map { CoreRegistryCLI(id: $0.0, name: $0.1, supports: $0.2) }
    }

    private static func supports(skill: Bool, agent: Bool, hook: Bool, rule: Bool, logs: Bool, limits: Bool) -> CoreRegistrySupports {
        CoreRegistrySupports(skill: skill, agent: agent, hook: hook, rule: rule, logs: logs, limits: limits)
    }

    /// One folder a row can live in (the mock's `READERS`, `FILEPATH`, `OWNER`): its path, who reads it and whose it is.
    struct Folder {
        let key: String
        let path: String
        let readBy: [String]
        let owner: String
        var copyTarget = true
    }

    static func folders(_ kind: CoreKind) -> [Folder] {
        let dir = kind == .skill ? "skills" : "agents"
        let shared: [Folder] = kind == .skill ? [
            Folder(key: "claude", path: "~/.claude/skills", readBy: ["claude", "cursor", "opencode", "amp"], owner: "claude"),
            Folder(key: "codex", path: "~/.codex/skills", readBy: ["codex", "cursor"], owner: "codex"),
            Folder(key: "agents", path: "~/.agents/skills", readBy: ["codex", "cursor", "amp"], owner: "codex", copyTarget: false),
        ] : [
            Folder(key: "claude", path: "~/.claude/agents", readBy: ["claude", "cursor"], owner: "claude"),
            Folder(key: "codex", path: "~/.codex/agents", readBy: ["codex", "cursor"], owner: "codex"),
        ]
        let home = ["cursor": "~/.cursor", "copilot": "~/.copilot", "opencode": "~/.config/opencode", "amp": "~/.config/amp",
                    "antigravity": "~/.gemini", "kiro": "~/.kiro", "qwen": "~/.qwen", "aider": "~/.aider"]
        let own = ["cursor", "copilot", "opencode", "amp", "antigravity", "kiro", "qwen", "aider"].map { id in
            Folder(key: id, path: "\(home[id] ?? "~/.\(id)")/\(dir)", readBy: [id], owner: id)
        }
        return shared + own
    }

    /// One mock item: its counts in Claude Code and Codex (nil is Missing), the folders it lives in beyond those two, the
    /// sessions of the other CLIs, and its age and owner.
    struct Spec {
        let name: String
        let description: String
        var claude: Int?
        var codex: Int?
        /// Codex's copy lives in the shared `~/.agents/skills` (read by Codex, Cursor CLI and Amp).
        var agents = false
        /// Own folders of other CLIs that hold a copy.
        var extra: [String] = []
        var use: [String: Int] = [:]
        var lastDays = 0
        var addedDays: Double?
        var plugin: String?
        var project: String?
    }

    static let skills: [Spec] = [
        Spec(name: "pdf-extract", description: "Pull text and tables out of PDF files", claude: 0, codex: 0, agents: true, addedDays: 41),
        Spec(name: "changelog-writer", description: "Draft a changelog entry from merged commits", claude: 0, addedDays: 63),
        Spec(name: "sql-explainer", description: "Explain a slow query and suggest an index", claude: 3, codex: 0, lastDays: 19),
        Spec(name: "release-notes", description: "Turn a tag range into release notes", claude: 0, codex: 0, addedDays: 2.0 / 24),
        Spec(name: "commit-helper", description: "Write a conventional commit from the staged diff", claude: 31, codex: 12, agents: true,
             extra: ["antigravity"], use: ["cursor": 9, "amp": 4, "opencode": 3, "antigravity": 5]),
        Spec(name: "review-pr", description: "Review a pull request against the team checklist", claude: 24, use: ["cursor": 2, "opencode": 1]),
        Spec(name: "test-scaffold", description: "Generate a test file next to the module", claude: 22, codex: 14, extra: ["kiro"],
             use: ["cursor": 6], lastDays: 1),
        Spec(name: "lint-fixer", description: "Apply safe lint fixes and report the rest", claude: 40, codex: 27, agents: true, extra: ["kiro"],
             use: ["cursor": 14, "opencode": 5, "kiro": 3]),
        Spec(name: "api-docs", description: "Keep the API reference in sync with routes", claude: 6, extra: ["copilot"], use: ["copilot": 3], lastDays: 6),
        Spec(name: "figma-sync", description: "Pull frames and tokens from a Figma file", claude: 4, lastDays: 3, plugin: "design-kit"),
        Spec(name: "tidy-imports", description: "Sort and prune imports across a package", claude: 18, codex: 9, use: ["cursor": 5, "opencode": 2], lastDays: 1),
        Spec(name: "migrate-tailwind", description: "Move a stylesheet to utility classes", claude: 2, codex: 0, lastDays: 17),
        Spec(name: "db-seed", description: "Seed a local database from fixtures", codex: 8, use: ["cursor": 1], lastDays: 2),
        Spec(name: "screenshot-diff", description: "Compare two screenshots and mark changes", claude: 11, codex: 0, extra: ["copilot"],
             use: ["copilot": 2], lastDays: 5),
        Spec(name: "checkout-flows", description: "Shared steps for the checkout repository", claude: 0, addedDays: 30, project: "~/work/payments-web"),
        Spec(name: "brand-voice", description: "Rewrite copy in the house tone", claude: 0, addedDays: 70, plugin: "design-kit"),
    ]

    static let subagents: [Spec] = [
        Spec(name: "code-reviewer", description: "Reads a diff and ranks findings by severity", claude: 18, codex: 7, extra: ["antigravity", "qwen"],
             use: ["cursor": 6, "antigravity": 2, "qwen": 4]),
        Spec(name: "test-runner", description: "Runs the suite and returns only failures", claude: 26, extra: ["copilot"], use: ["cursor": 3, "copilot": 4]),
        Spec(name: "db-migrator", description: "Plans and checks a schema migration", claude: 0, codex: 0, addedDays: 55),
        Spec(name: "docs-writer", description: "Writes a short page from a code path", claude: 5, extra: ["opencode"], use: ["opencode": 2], lastDays: 8),
        Spec(name: "security-scan", description: "Looks for secrets and unsafe calls", claude: 4, lastDays: 9),
        Spec(name: "api-reviewer", description: "Checks a route change against the API guide", claude: 3, lastDays: 4, project: "~/work/ledger-api"),
        Spec(name: "release-captain", description: "Walks a release checklist step by step", codex: 3, lastDays: 11),
    ]

    /// The break-ui extremes (the mock's `x-data.js`): long and non-Latin names, a huge count, a long description, and 40 more rows.
    static func worst(_ kind: CoreKind) -> [Spec] {
        var specs = kind == .skill ? skills : subagents
        specs[0] = Spec(name: "a-very-long-\(kind == .skill ? "skill" : "subagent")-name-that-keeps-going-past-the-column-edge-and-then-some-more",
                        description: String(repeating: "A description long enough to be clamped in the inspector, ", count: 5),
                        claude: 0, codex: 0, agents: kind == .skill, addedDays: 412)
        specs[1] = Spec(name: "Rút trích văn bản từ PDF 📄", description: "非常に長い説明 · Văn bản tiếng Việt có dấu", claude: 4_830_112,
                        codex: 1, use: ["cursor": 999_999], lastDays: 0)
        specs += (0..<40).map { index in
            Spec(name: "generated-\(kind == .skill ? "skill" : "subagent")-\(index)", description: "Row \(index) of the worst-case list",
                 claude: index % 3 == 0 ? 0 : index * 37, codex: index % 2 == 0 ? nil : index, lastDays: index % 30,
                 addedDays: index % 3 == 0 ? Double(index) : nil)
        }
        return specs
    }

    /// The members and cells of `specs` for `registry` at `now`. `unreadable` CLIs get every cell unknown; `scanning` turns every
    /// installed cell into `scanning` (the first usage scan, RD-R13).
    static func loadout(_ kind: CoreKind, specs: [Spec], registry: [CoreRegistryCLI], now: Date, unreadable: Set<String> = [],
                        scanning: Bool = false) -> CoreLoadoutRows {
        let ids = Set(registry.map(\.id))
        let folderList = folders(kind)
        let byKey = Dictionary(uniqueKeysWithValues: folderList.map { ($0.key, $0) })
        var items: [CoreInventoryItem] = []
        for spec in specs {
            var keys: [String] = []
            if spec.claude != nil { keys.append("claude") }
            if spec.codex != nil { keys.append(spec.agents ? "agents" : "codex") }
            keys += spec.extra.filter(ids.contains)
            let cells = cells(spec, keys: keys, kind: kind, registry: registry, byKey: byKey, now: now, unreadable: unreadable, scanning: scanning)
            let seen = spec.addedDays.map { ISO8601DateFormatter().string(from: now.addingTimeInterval(-$0 * 86_400)) }
            for key in keys {
                guard let folder = byKey[key] else { continue }
                let path = "\(folder.path)/\(spec.name)"
                let owner = spec.plugin ?? "user"
                items.append(CoreInventoryItem(
                    id: "\(key):\(kind.rawValue):\(spec.name)", cli: key == "claude" ? .claude : .codex, kind: kind, name: spec.name,
                    entry: spec.name, description: spec.description, owner: owner, path: spec.project.map { "\($0)/.claude/\(folder.path.split(separator: "/").last ?? "")/\(spec.name)" } ?? path,
                    file: path, removable: spec.plugin == nil && spec.project == nil, scope: spec.project == nil ? .global : .project,
                    project: spec.project, inOther: false, key: "\(kind.rawValue):\(spec.project ?? ""):\(spec.name)", cliCells: cells,
                    folder: folder.path, realPath: path, firstSeen: seen))
            }
        }
        let readers = folderList.compactMap { folder -> CoreReadersFolder? in
            let readBy = registry.filter { folder.readBy.contains($0.id) && $0.supports.supports(kind) }.map(\.id)
            guard !readBy.isEmpty, ids.contains(folder.owner) else { return nil }
            return CoreReadersFolder(path: folder.path, realPath: folder.path, kind: kind, readBy: readBy, ownedBy: folder.owner,
                                     copyTarget: folder.copyTarget)
        }
        return CoreLoadoutRows(usage: scanning ? .scanning : .ready, items: items, hooks: [], problems: [], events: [:],
                               roots: ["claude": "~/.claude", "codex": "~/.codex"], countsByScope: [:], rowFlags: [:], folders: readers)
    }

    private static func cells(_ spec: Spec, keys: [String], kind: CoreKind, registry: [CoreRegistryCLI], byKey: [String: Folder], now: Date,
                              unreadable: Set<String>, scanning: Bool) -> CoreCLICells {
        let day = usageDay(now.addingTimeInterval(-Double(spec.lastDays) * 86_400))
        var cells: CoreCLICells = [:]
        for cli in registry {
            if !cli.supports.supports(kind) { cells[cli.id] = .notSupported; continue }
            if unreadable.contains(cli.id) { cells[cli.id] = .unknown; continue }
            guard keys.contains(where: { byKey[$0]?.readBy.contains(cli.id) ?? false }) else { cells[cli.id] = .missing; continue }
            if scanning { cells[cli.id] = .scanning; continue }
            if !cli.supports.logs { cells[cli.id] = .unmeasurable(reason: "\(cli.name) keeps no session log SpaceVibe can count"); continue }
            let n = cli.id == "claude" ? spec.claude ?? 0 : cli.id == "codex" ? spec.codex ?? 0 : spec.use[cli.id] ?? 0
            cells[cli.id] = .sessions(count: n, days: n > 0 ? [day] : [], last: n > 0 ? day : nil, note: nil)
        }
        return cells
    }

    /// `YYYY-MM-DD` in UTC, as the engine records a use.
    static func usageDay(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
