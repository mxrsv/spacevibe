package inventory

import "spacevibe.dev/core/internal/clis"

// The wire objects Cells and OnlyCLIs still have one fixed member per CLI ("claude", "codex"). This file is the only
// place that maps a CLI id to its member. TestEveryInventoryCLIHasAWireSlot fails when a CLI gains the inventory
// concept before the wire carries a map keyed by CLI id; until then such a CLI is not on the wire.

// wireCLIs are the CLIs the fixed wire objects carry, in wire order.
var wireCLIs = []CLI{clis.Claude, clis.Codex}

// For returns the cell of one CLI; false for a CLI the wire object has no member for.
func (c Cells) For(cli CLI) (Cell, bool) {
	switch cli {
	case clis.Claude:
		return c.Claude, true
	case clis.Codex:
		return c.Codex, true
	}
	return Cell{}, false
}

// cellsOf builds the cells of one row, one per wire CLI.
func cellsOf(cell func(CLI) Cell) *Cells {
	return &Cells{Claude: cell(clis.Claude), Codex: cell(clis.Codex)}
}

// onlyOf builds the "present in one CLI only" counts from counts keyed by CLI id.
func onlyOf(counts map[CLI]int) OnlyCLIs {
	return OnlyCLIs{Claude: counts[clis.Claude], Codex: counts[clis.Codex]}
}

// total is the number of rows present in exactly one CLI, whichever it is.
func (o OnlyCLIs) total() int { return o.Claude + o.Codex }
