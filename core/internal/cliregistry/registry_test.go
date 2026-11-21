package cliregistry_test

import (
	"encoding/json"
	"regexp"
	"slices"
	"testing"

	"spacevibe.dev/core/internal/activity"
	"spacevibe.dev/core/internal/cliregistry"
	"spacevibe.dev/core/internal/limits"
	"spacevibe.dev/core/internal/usage"
)

// The registry ids are the ids the rest of the protocol already uses for the two CLIs, in the same order, so
// a cliCells key, a Cli value, a roots key and a limits entry name the same CLI.
func TestRegistryIDsMatchTheProtocol(t *testing.T) {
	var ids []string
	for _, c := range cliregistry.All() {
		ids = append(ids, string(c.ID))
	}
	var scanned []string
	for _, c := range usage.CLIs {
		scanned = append(scanned, string(c))
	}
	if !slices.Equal(ids, scanned) {
		t.Fatalf("registry ids %v, usage.CLIs %v: the engine reads exactly the CLIs the registry lists", ids, scanned)
	}
	same := []struct{ registry, other string }{
		{string(cliregistry.Claude), string(limits.Claude)},
		{string(cliregistry.Codex), string(limits.Codex)},
		{string(cliregistry.Claude), string(activity.CLIClaude)},
		{string(cliregistry.Codex), string(activity.CLICodex)},
	}
	for _, pair := range same {
		if pair.registry != pair.other {
			t.Errorf("registry id %q, another package names the same CLI %q", pair.registry, pair.other)
		}
	}
}

func TestRegistryEntriesAreWellFormed(t *testing.T) {
	id := regexp.MustCompile(`^[a-z][a-z0-9-]*$`)
	seen := map[cliregistry.ID]bool{}
	for _, c := range cliregistry.All() {
		if !id.MatchString(string(c.ID)) {
			t.Errorf("id %q is not lowercase letters, digits and dashes", c.ID)
		}
		if seen[c.ID] {
			t.Errorf("id %q is listed twice", c.ID)
		}
		seen[c.ID] = true
		if c.Name == "" {
			t.Errorf("%s has no name", c.ID)
		}
		got, ok := cliregistry.Lookup(c.ID)
		if !ok || got != c {
			t.Errorf("Lookup(%q) = %+v, %v", c.ID, got, ok)
		}
	}
	if _, ok := cliregistry.Lookup("gemini"); ok {
		t.Error("the engine reads no third CLI, so the registry must not list one")
	}
}

// All hands out a copy: a caller that changes it cannot change the registry (C1).
func TestAllIsACopy(t *testing.T) {
	first := cliregistry.All()
	first[0].Name = "changed"
	first[0].Supports.Skill = false
	if again := cliregistry.All(); again[0].Name == "changed" || !again[0].Supports.Skill {
		t.Fatal("All returned the registry itself")
	}
}

// The wire shape of clis.registry: ordered entries with every supports member present.
func TestReadWireShape(t *testing.T) {
	data, err := json.Marshal(cliregistry.Read())
	if err != nil {
		t.Fatal(err)
	}
	want := `{"clis":[` +
		`{"id":"claude","name":"Claude Code","supports":{"skill":true,"agent":true,"hook":true,"rule":true,"logs":true,"limits":true}},` +
		`{"id":"codex","name":"Codex","supports":{"skill":true,"agent":true,"hook":true,"rule":true,"logs":true,"limits":true}}]}`
	if string(data) != want {
		t.Fatalf("clis.registry =\n%s\nwant\n%s", data, want)
	}
}
