import Foundation
import Testing
@testable import SpaceVibe

/// `HookLabel` is the mock's `hookLabel` (`src/a-core.js`) rule for rule, except that env assignments are never the name. The commands are the mock's demo and `extreme` Hooks,
/// the fixture home's Hooks and the break-ui cases: quotes, env prefixes, versions, RTL, emoji, empty and very long.
@Suite("Hook label")
struct HookLabelTests {
    @Test("a script path is named by its file, whatever runs it", arguments: [
        ("~/.claude/hooks/lint-staged.sh", "lint-staged.sh"),
        ("python3 ~/.claude/hooks/guard.py", "guard.py"),
        ("$CLAUDE_PROJECT_DIR/.claude/hooks/lint.sh", "lint.sh"),
        ("sh '$HOME/.claude/scripts/block-env-edit.sh'", "block-env-edit.sh"),
        ("sh '$HOME/bin/format-on-save.sh' --fix", "format-on-save.sh"),
        ("node \"$CLAUDE_PROJECT_DIR\"/.claude/hooks/prompt-log.mjs", "prompt-log.mjs"),
        ("cd /tmp && ./deploy.sh", "deploy.sh"),
        ("bash -c 'cd \"$CLAUDE_PROJECT_DIR\" && ./scripts/check.ts'", "check.ts"),
        ("FOO=1 BAR=\"two words\" node scripts/build.cjs", "build.cjs"),
    ])
    func script(command: String, label: String) {
        #expect(HookLabel.of(command) == label)
    }

    @Test("the extreme guard keeps its script even with quoted flags and a log path that ends in .jsonl")
    func quotedFlags() {
        let command = "python3 ~/.claude/hooks/guard.py --deny 'rm -rf' --deny 'git push --force' --log ~/Library/Logs/claude-guard/guard.jsonl"
        #expect(HookLabel.of(command) == "guard.py")
    }

    @Test("without a script, the first word that is not a launcher, flag or variable, without folders or version", arguments: [
        ("bash -c 'cd \"$CLAUDE_PROJECT_DIR\" && npx --yes prettier@3.3.3 --write \"$(jq -r .tool_input.file_path)\" 2>/dev/null || true'", "prettier"),
        ("osascript -e 'display notification \"Done\"'", "osascript"),
        ("osascript -e 'display notification \"Xong rồi 🎉\" with title \"Claude Code\"'", "osascript"),
        ("prettier --write \"$FILE\"", "prettier"),
        ("/usr/local/bin/my-tool@1.2.3 run", "my-tool"),
        ("exec env uvx ruff check", "ruff"),
        ("sh -c 'echo a\necho b'", "echo"),
    ])
    func tool(command: String, label: String) {
        #expect(HookLabel.of(command) == label)
    }

    @Test("an env assignment is never the name, its value quoted or not (RD-R17 over the mock's rule)", arguments: [
        ("env NODE_ENV=production npx --yes eslint@9.1.0 --fix", "eslint"),
        ("env NODE_ENV=production npx eslint@9.1.0 .", "eslint"),
        ("NODE_ENV=production FOO=1 ./scripts/x.sh", "x.sh"),
        ("FOO=\"two words\" BAR='a b' eslint .", "eslint"),
        ("FOO=\"a b\"tail eslint .", "eslint"),
        ("bash -c 'FOO=\"a b\" prettier --write x'", "prettier"),
        ("SCRIPT=./setup.sh node run.mjs", "run.mjs"),
        ("SCRIPT=./setup.sh lint", "lint"),
        ("_X=1 tool", "tool"),
        ("env -i PATH=/usr/bin HOME=\"$HOME\" python3 ~/hooks/guard.py", "guard.py"),
    ])
    func envAssignment(command: String, label: String) {
        #expect(HookLabel.of(command) == label)
    }

    @Test("a word that is not an identifier before `=` is not an assignment; a command of assignments only falls back to itself")
    func notAssignments() {
        #expect(HookLabel.of("9X=1 tool") == "9X=1")
        #expect(HookLabel.of("--fix=all tool") == "tool")
        #expect(HookLabel.of("FOO=1") == "FOO=1")
        #expect(HookLabel.of("FOO=1 BAR=2") == "FOO=1 BAR=2")
    }

    @Test("nothing but launchers, flags or variables falls back to the first word, then the command")
    func fallbacks() {
        #expect(HookLabel.of("--version") == "--version")
        #expect(HookLabel.of("$HOME") == "$HOME")
        #expect(HookLabel.of("sh") == "sh")
        #expect(HookLabel.of("") == "")
        #expect(HookLabel.of("   ") == "   ")
        #expect(HookLabel.of("''") == "")
    }

    @Test("RTL and emoji names come through whole")
    func scripts() {
        #expect(HookLabel.of("python3 ~/hooks/مراجعة.py") == "مراجعة.py")
        #expect(HookLabel.of("🎉notify --loud") == "🎉notify")
        #expect(HookLabel.of("sh '$HOME/日本語/レビュー.sh'") == "レビュー.sh")
    }

    @Test("a long tool name is cut at 40 characters; a script name is not")
    func length() {
        let tool = String(repeating: "x", count: 60)
        #expect(HookLabel.of("\(tool) --flag") == String(repeating: "x", count: HookLabel.maxLength))
        let script = String(repeating: "y", count: 60) + ".sh"
        #expect(HookLabel.of("~/hooks/\(script)") == script)
    }

    @Test("every Hook of the fixture home gets a label; one with a script path agrees with the v5 file name", .timeLimit(.minutes(1)))
    func fixtureHooks() async throws {
        let fixture = try await CoreFixtureHome.make()
        let client = try fixture.client()
        defer {
            client.shutdown()
            fixture.remove()
        }
        let hooks = try await client.inventoryRead().hooks
        try #require(!hooks.isEmpty)
        for hook in hooks {
            #expect(!hook.label.isEmpty, "\(hook.command)")
            if let path = hook.paths.first, !path.isEmpty {
                #expect(hook.label == URL(fileURLWithPath: path).lastPathComponent, "\(hook.command)")
            }
        }
        #expect(hooks.contains { $0.command == "prettier --write \"$FILE\"" && $0.label == "prettier" })
    }
}
