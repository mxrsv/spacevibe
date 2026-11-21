package rules

import (
	"bytes"
	"context"
	"testing"

	"spacevibe.dev/core/internal/mutate"
)

// RB-E4: rules.removeMany removes the picked rules of one scope in one edit, one journal entry, one Undo.

func TestRemoveManyRulesOneEntryThenUndo(t *testing.T) {
	sb := newSandbox(t)
	text := "{\n  \"permissions\": {\n    \"allow\": [\"Read\", \"Bash(npm run:*)\", \"Edit\"],\n    \"deny\": [\"WebFetch\"]\n  }\n}\n"
	sb.write(".claude/settings.json", text)
	s := newService(t, sb)
	ctx := context.Background()

	res, err := s.RemoveMany(ctx, RemoveManyParams{Scope: KindGlobal, IDs: []string{"global:allow:Bash(npm run:*)", "global:deny:WebFetch", "global:deny:WebFetch"}})
	if err != nil {
		t.Fatal(err)
	}
	if res.Entry.Label != "Removed 2 rules (global)" || res.Entry.Count != 1 {
		t.Fatalf("entry %+v", res.Entry)
	}
	if allow, _ := permissionList(t, sb.settings(), Allow); len(allow) != 2 || allow[0] != "Read" || allow[1] != "Edit" {
		t.Fatalf("allow left %v", allow)
	}
	if deny, _ := permissionList(t, sb.settings(), Deny); len(deny) != 0 {
		t.Fatalf("deny left %v", deny)
	}
	if _, err := mutate.Undo(sb.r, res.Entry.ID); err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(sb.bytes(sb.settings()), []byte(text)) {
		t.Fatalf("Undo did not restore byte for byte:\n%s", sb.bytes(sb.settings()))
	}
}

func TestRemoveManyRulesRefusals(t *testing.T) {
	sb := newSandbox(t)
	proj := sb.project("proj")
	text := `{"permissions":{"allow":["Read","Edit"]}}`
	sb.write(".claude/settings.json", text)
	sb.write("proj/.claude/settings.json", `{"permissions":{"ask":["Bash"]}}`)
	s := newService(t, sb)
	ctx := context.Background()
	for _, c := range []struct {
		name   string
		params RemoveManyParams
		status int
		says   string
	}{
		{"empty", RemoveManyParams{Scope: KindGlobal}, 400, noRulesToRemoveMessage},
		{"another scope's id", RemoveManyParams{Scope: KindGlobal, IDs: []string{"project:ask:Bash"}}, 400, "That is not a rule of this scope."},
		{"bad verdict", RemoveManyParams{Scope: KindGlobal, IDs: []string{"global:maybe:Read"}}, 400, "That is not a rule of this scope."},
		{"no rule", RemoveManyParams{Scope: KindGlobal, IDs: []string{"global:allow:"}}, 400, "That is not a rule of this scope."},
		{"one is gone", RemoveManyParams{Scope: KindGlobal, IDs: []string{"global:allow:Read", "global:deny:Edit"}}, 409, ruleChangedMessage},
		{"unknown project", RemoveManyParams{Scope: KindProject, Dir: dirPtr(sb.path("nowhere")), IDs: []string{"project:ask:Bash"}}, 404, unknownProjectMessage},
	} {
		_, err := s.RemoveMany(ctx, c.params)
		if msg := wantErr(t, err, c.status); msg != c.says {
			t.Errorf("%s: %q", c.name, msg)
		}
	}
	if !bytes.Equal(sb.bytes(sb.settings()), []byte(text)) || len(historyOf(t, sb.r)) != 0 {
		t.Fatal("a refusal changed the file or the journal")
	}
	res, err := s.RemoveMany(ctx, RemoveManyParams{Scope: KindProject, Dir: dirPtr(proj), IDs: []string{"project:ask:Bash"}})
	if err != nil || res.Entry.Label != "Removed 1 rule (project "+proj+")" {
		t.Fatalf("project removal %+v %v", res, err)
	}
}
