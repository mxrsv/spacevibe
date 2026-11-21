package methods

import (
	"context"
	"encoding/json"

	"spacevibe.dev/core/internal/clean"
	"spacevibe.dev/core/internal/inventory"
	"spacevibe.dev/core/internal/rpc"
	"spacevibe.dev/core/internal/usage"
)

// shareProjects hands the project list of an inventory read to rules, so both see the same folders.
func (s *Services) shareProjects() { s.rules.SetProjects(s.inventory.Known()) }

func (s *Services) inventoryRead(ctx context.Context, _ none) (inventory.Snapshot, error) {
	snapshot, err := s.inventory.Read(ctx)
	if err != nil {
		return inventory.Snapshot{}, err
	}
	s.shareProjects()
	return snapshot, nil
}

func (s *Services) loadoutRows(ctx context.Context, _ none) (inventory.LoadoutRows, error) {
	rows, err := s.inventory.Rows(ctx)
	if err != nil {
		return inventory.LoadoutRows{}, err
	}
	s.shareProjects()
	return rows, nil
}

// progressParams is the params of usage/progress; ID is the usage.scan request id as sent.
type progressParams struct {
	ID    json.RawMessage `json:"id"`
	Done  int             `json:"done"`
	Total int             `json:"total"`
}

// usageScan is usage.scan: it owns the usage state, sends usage/progress and stops on cancel. A second scan
// while one runs is the scanner's 409.
func (s *Services) usageScan(ctx context.Context, call rpc.Call) (any, error) {
	var p none
	if err := rpc.DecodeParams(call.Params, &p); err != nil {
		return nil, err
	}
	result, err := s.usage.Scan(ctx, func(pr usage.Progress) {
		call.Notify("usage/progress", progressParams{ID: call.ID, Done: pr.Done, Total: pr.Total})
	})
	if err != nil {
		s.noteFailure("usage.scan", err)
		return nil, err
	}
	return result, nil
}

// cleanProgress is the params of clean/progress; ID is the clean.move request id as sent.
type cleanProgress struct {
	ID json.RawMessage `json:"id"`
	clean.ProgressParams
}

// cleanMove is clean.move: it sends clean/progress and stops before the next file on cancel (clean.Service.Move).
func (s *Services) cleanMove(ctx context.Context, call rpc.Call) (any, error) {
	var p clean.MoveParams
	if err := rpc.DecodeParams(call.Params, &p); err != nil {
		return nil, err
	}
	result, err := s.clean.Move(ctx, p, func(pr clean.ProgressParams) {
		call.Notify("clean/progress", cleanProgress{ID: call.ID, ProgressParams: pr})
	})
	if err != nil {
		s.noteFailure("clean.move", err)
		return nil, err
	}
	return result, nil
}
