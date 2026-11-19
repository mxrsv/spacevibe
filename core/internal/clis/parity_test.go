// The external test package may import the subsystems that import clis; the registry itself imports none.
package clis_test

import (
	"bytes"
	"encoding/json"
	"flag"
	"os"
	"path/filepath"
	"testing"

	"spacevibe.dev/core/internal/clis"
	"spacevibe.dev/core/internal/inventory"
	"spacevibe.dev/core/internal/limits"
)

// Rewrite the file on purpose, after a registry or adapter change:
//
//	cd core && SPACEVIBE_TEST=1 go test ./internal/clis -run TestRegistryParityFile -update
var update = flag.Bool("update", false, "rewrite core/testdata/cli-registry.json")

// parityFile is shared with the app: CLIRegistryTests.matchesTheCoreRegistry compares it to CLIRegistry. It sits outside
// testdata/fixtures, so the frozen fixture checksums do not cover it.
var parityFile = filepath.Join("..", "..", "testdata", "cli-registry.json")

// parityEntry is one CLI's facts that the core and the app each keep: the core in the registry and its adapters, the
// app in CLIRegistry. Each field is derived on both sides, never copied from this file.
type parityEntry struct {
	ID    clis.ID `json:"id"`
	Label string  `json:"label"`
	// Concepts in registry order. The app derives inventory, mutate and usage from the inventory wire enum (CoreCLI),
	// activity from readsSessionLog, and limits from its Limits list.
	Concepts []clis.Concept `json:"concepts"`
	// LogsHookRuns: the inventory adapter gives no unmeasurable reason for hook runs. False without inventory.
	LogsHookRuns bool `json:"logsHookRuns"`
	// LimitsReading is the limits adapter's kind, "" without the limits concept.
	LimitsReading limits.ReadingKind `json:"limitsReading"`
}

func parityEntries(t *testing.T) []parityEntry {
	t.Helper()
	var out []parityEntry
	for _, d := range clis.All() {
		e := parityEntry{ID: d.ID, Label: d.Label, Concepts: d.Concepts}
		if d.Has(clis.Inventory) {
			reason, err := inventory.UnloggedHooks(d.ID)
			if err != nil {
				t.Fatal(err)
			}
			e.LogsHookRuns = reason == ""
		}
		if d.Has(clis.Limits) {
			kind, err := limits.KindOf(d.ID)
			if err != nil {
				t.Fatal(err)
			}
			e.LimitsReading = kind
		}
		out = append(out, e)
	}
	return out
}

// The core and the app each keep a few per-CLI facts. This test fails when the core's drift from the committed file;
// the app's test fails when CLIRegistry drifts from it. Together they keep the two registries in step.
func TestRegistryParityFile(t *testing.T) {
	got, err := json.MarshalIndent(parityEntries(t), "", "  ")
	if err != nil {
		t.Fatal(err)
	}
	got = append(got, '\n')
	if *update {
		if err := os.WriteFile(parityFile, got, 0o644); err != nil {
			t.Fatal(err)
		}
		return
	}
	want, err := os.ReadFile(parityFile)
	if err != nil {
		t.Fatalf("%v: rerun with -update to create it", err)
	}
	if !bytes.Equal(got, want) {
		t.Fatalf("%s is out of date with the registry and its adapters. If the change is meant, rerun with -update, "+
			"then make CLIRegistry (Sources/SpaceVibe/Components) match it; scripts/test.sh checks the app side.\n got:\n%s",
			parityFile, got)
	}
}
