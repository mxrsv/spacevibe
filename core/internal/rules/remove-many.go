package rules

import (
	"context"
	"slices"
	"strconv"
	"strings"

	"spacevibe.dev/core/internal/coreerr"
	"spacevibe.dev/core/internal/mutate"
	"spacevibe.dev/core/internal/ojson"
)

// rules.removeMany (RB-E4, spec RD-R4 and RD-A6): the ticked rules of one scope removed in one edit of its settings file,
// one backup and one journal entry, so one Undo restores them all. The Rules page lists one scope at a time, and a rule
// id ("<scope>:<verdict>:<rule>") does not carry the project folder, so the call names its scope like every other
// rules.* write.

// RemoveManyParams is the params of rules.removeMany.
type RemoveManyParams struct {
	Scope ScopeKind `json:"scope"`
	Dir   *string   `json:"dir"`
	IDs   []string  `json:"ids"`
}

const noRulesToRemoveMessage = "Pick at least one rule to remove."

// RemoveMany is rules.removeMany.
func (s *Service) RemoveMany(ctx context.Context, p RemoveManyParams) (mutate.EntryResult, error) {
	scope, store, err := s.begin(ctx, p.Scope, p.Dir)
	if err != nil {
		return mutate.EntryResult{}, err
	}
	entry, err := store.RemoveRules(scope, p.IDs)
	return resultOf(entry), s.scrubbed(store, scope, err)
}

// RemoveRules removes every rule the ids name from the scope's file in one write. It refuses (400) an empty list or an
// id that is not a rule id of this scope, and (409, nothing written) when any rule is no longer in the file under its
// verdict.
func (s *Store) RemoveRules(scope Scope, ids []string) (mutate.Entry, error) {
	if len(ids) == 0 {
		return mutate.Entry{}, coreerr.New(noRulesToRemoveMessage)
	}
	var remove []VerdictRule
	for _, id := range ids {
		rule, err := ruleOfID(scope, id)
		if err != nil {
			return mutate.Entry{}, err
		}
		if !slices.Contains(remove, rule) {
			remove = append(remove, rule)
		}
	}
	noun := " rules"
	if len(remove) == 1 {
		noun = " rule"
	}
	label := "Removed " + strconv.Itoa(len(remove)) + noun + " (" + scope.journalLabel() + ")"
	return s.required(s.edit(scope, label, func(file string, doc *ojson.Document) (*ojson.Document, error) {
		for _, r := range remove {
			if err := requireRule(r.Rule, r.Verdict, doc, file); err != nil {
				return nil, err
			}
		}
		return editRules(doc, file, remove, nil)
	}))
}

// ruleOfID reads "<scope>:<verdict>:<rule>" (Rule.ID). The scope must be the call's; the rule is everything after the
// second colon, so a rule with a colon in it ("Bash(npm run:*)") reads whole.
func ruleOfID(scope Scope, id string) (VerdictRule, error) {
	bad := coreerr.New("That is not a rule of this scope.")
	rest, ok := strings.CutPrefix(id, string(scope.Kind)+":")
	if !ok {
		return VerdictRule{}, bad
	}
	verdict, rule, ok := strings.Cut(rest, ":")
	if !ok || rule == "" || !Verdict(verdict).Valid() {
		return VerdictRule{}, bad
	}
	return VerdictRule{Verdict: Verdict(verdict), Rule: rule}, nil
}
