package rules

import (
	"encoding/json"
	"flag"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"testing"

	"spacevibe.dev/core/internal/config"
	"spacevibe.dev/core/internal/goldentest"
)

// updateRulesWide rewrites golden/rules-wide.json, a new golden of the redesign build (RB-E6). The frozen rules.json
// projection (ruleObject) has no `wide`, so it stays as it is; after a rewrite the new file's line in SHA256SUMS must be
// updated in the same commit.
var updateRulesWide = flag.Bool("update-rules-wide", false, "rewrite core/testdata/fixtures/golden/rules-wide.json")

// Swift has no counterpart: Rule.wide is new in RB-E6 (RD26, RD-R17). One case per pattern.
func TestRuleWidePatterns(t *testing.T) {
	wide := []string{
		"Bash", "Bash()", "Bash(  )", "Bash(*)", "Bash( * )", "  Bash  ",
		"Read", "Read(*)", "Edit", "Edit(*)", "Write", "Write(*)", "MultiEdit", "MultiEdit(*)",
		"NotebookEdit", "NotebookEdit(*)", "WebFetch", "WebFetch(*)", "WebSearch", "WebSearch(*)",
	}
	narrow := []string{
		// a specifier that is not exactly "*" after trimming, even when a person would read it as "everything"
		"Bash(:*)", "Bash(*:*)", "Bash(**)", "Bash(* *)", "Bash(npm test:*)", "Bash(git push *)",
		"Read(**)", "Read(//**)", "Read(~/**)", "Read(./.env)", "Edit(src/**)",
		"WebFetch(domain:*)", "WebFetch(domain:github.com)", "WebSearch(query)",
		// not a tool that takes a specifier
		"mcp__demo", "mcp__demo__lookup", "mcp__demo__lookup(*)", "Skill", "Task", "Glob", "Grep", "Glob(*)", "NotebookRead",
		// tool names are case-sensitive
		"bash", "read(*)", "BASH",
		// not a rule at all
		"not a rule!", "Bash(unclosed",
	}
	for _, text := range wide {
		if r := rl(Allow, text); !r.Wide {
			t.Errorf("%q: wide = false, want true", text)
		}
	}
	for _, text := range narrow {
		if r := rl(Allow, text); r.Wide {
			t.Errorf("%q: wide = true, want false", text)
		}
	}
}

// The flag says what the rule covers, not what it allows: every verdict and every scope carries it.
func TestRuleWideAnyVerdictAndScope(t *testing.T) {
	for _, scope := range []Scope{Global, ProjectScope("/p"), LocalScope("/p")} {
		for _, v := range Verdicts {
			if !newRule(scope, "f", v, "Bash").Wide || newRule(scope, "f", v, "Bash(ls)").Wide {
				t.Errorf("%v %s: wrong wide flag", scope, v)
			}
		}
	}
}

// For every tool the grid places, a wide rule is exactly a rule with the grid's wide role, so the flag and a cell
// write agree on which rules are "the whole tool".
func TestRuleWideMatchesGridRole(t *testing.T) {
	texts := []string{"Read", "Read(*)", "Read(**)", "Read(./.env)", "Edit", "Write(x)", "MultiEdit(*)", "Bash", "Bash(:*)",
		"Bash(git push)", "WebFetch", "WebSearch(domain:*)"}
	for _, text := range texts {
		parsed, _ := ParseRule(text)
		gridWide := false
		for _, p := range placements(parsed) {
			if p.role == roleWide {
				gridWide = true
			}
		}
		if got := rl(Deny, text).Wide; got != gridWide {
			t.Errorf("%q: wide %v, grid wide role %v", text, got, gridWide)
		}
	}
}

// The wire carries `wide` on every Rule, in the list and in each grid cell, beside the old members (AR1).
func TestRuleWideOnTheWire(t *testing.T) {
	rules := []Rule{rl(Allow, "Bash"), rl(Allow, "Bash(ls)"), rl(Allow, "mcp__demo")}
	data, err := json.Marshal(rules)
	if err != nil {
		t.Fatal(err)
	}
	var decoded []map[string]any
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatal(err)
	}
	for i, want := range []bool{true, false, false} {
		if got, ok := decoded[i]["wide"].(bool); !ok || got != want {
			t.Errorf("rule %d: wide %v (present %v), want %v", i, decoded[i]["wide"], ok, want)
		}
		for _, key := range []string{"id", "scope", "dir", "file", "verdict", "rule", "tool", "specifier"} {
			if _, ok := decoded[i][key]; !ok {
				t.Errorf("rule %d lost %q", i, key)
			}
		}
	}
	for _, cell := range CapabilityGrid(rules) {
		for _, r := range cell.Rules {
			if r.Wide != (r.Rule == "Bash") {
				t.Errorf("grid %s: %s wide %v", cell.Capability, r.Rule, r.Wide)
			}
		}
	}
}

// wideView is {scope key: [{id, wide}]} for every file the frozen rules golden lists in one section, in file order.
func wideView(v goldenView, section obj) obj {
	keys := make([]string, 0)
	for k := range asObj(section["lists"]) {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	out := obj{}
	for _, key := range keys {
		items := []any{}
		for _, r := range v.list(scopeFromKey(v.root, key)).Rules {
			items = append(items, obj{"id": r.ID, "wide": r.Wide})
		}
		out[key] = items
	}
	return out
}

// Swift has no counterpart. The golden is the `wide` of every rule of the shared fixture HOME (global, every project's
// Shared and Local file) and of rules-home/main (with an MCP name and a string that is not a rule).
func TestGoldenRulesWide(t *testing.T) {
	golden := loadRulesGolden(t)
	root, err := goldentest.Materialize()
	if err != nil {
		t.Fatal(err)
	}
	env := goldentest.Env(root)
	env["SPACEVIBE_HOME"] = t.TempDir()
	cfg, err := config.LoadFrom(func(k string) string { return env[k] })
	if err != nil {
		t.Fatal(err)
	}
	home := newHome(t)
	materialize(t, "main", home.root)
	got := obj{
		"shared": wideView(newView(t, resolveRoots(t, cfg), root), asObj(golden["shared"])),
		"main":   wideView(newView(t, home.roots(), home.root), asObj(golden["main"])),
	}
	if *updateRulesWide {
		text, err := goldentest.Canonical(got)
		if err != nil {
			t.Fatal(err)
		}
		dir, err := goldentest.FixturesDir()
		if err != nil {
			t.Fatal(err)
		}
		if err := os.WriteFile(filepath.Join(dir, "golden", "rules-wide.json"), text, 0o644); err != nil {
			t.Fatal(err)
		}
		t.Log("wrote golden/rules-wide.json: update its line in SHA256SUMS")
	}
	want, err := goldentest.LoadGolden("rules-wide")
	if err != nil {
		t.Fatal(err)
	}
	goldentest.AssertCanonicalEqual(t, "rules-wide", want, got)
	wideCount := 0
	for _, section := range got {
		for _, items := range asObj(section) {
			for _, item := range asList(items) {
				if asObj(item)["wide"] == true {
					wideCount++
				}
			}
		}
	}
	text, _ := goldentest.Canonical(got)
	if !strings.Contains(string(text), "mcp__demo__lookup") || !strings.Contains(string(text), "not a rule!") {
		t.Error("the golden must keep covering an MCP name and a string that is not a rule")
	}
	goldentest.AssertCaseCount(t, "rules-wide wide rules", wideCount, 12)
}
