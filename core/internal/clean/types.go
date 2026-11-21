// Package clean is Clean's engine (CL-R1 to CL-R8, RB-E7): clean.scan measures what Clean can move (session logs by
// age, the allowlisted caches, the size of every Skill and Subagent row) and the locks that hold some of it back, and
// clean.move moves a selection of logs and caches to the macOS Trash through mutate, with the usage of every moved log
// archived first (CL-R3). Equipment is removed through loadout.removeMany, never here.
//
// Every size is the allocated bytes of the exact paths a move takes (fsx.DiskUsage), so the scan's estimate, the move's
// result and `du` agree (CL-R6). docs/internals/clean.md holds the decisions and traps.
package clean

import "spacevibe.dev/core/internal/mutate"

// Ages are the "older than N days" buckets of the logs, in display order. A bucket holds every log last written
// longer ago than its age, so 30 includes 90 and 180.
var Ages = []int{30, 90, 180}

// Log states of one CLI.
const (
	LogsMeasured   = "measured"
	LogsMissing    = "missing"
	LogsUnreadable = "unreadable"
)

// Lock reasons.
const (
	// LockSessions: sessions of the CLI hold it (RD27 for logs: running or waiting; RD35 for caches: any live one).
	LockSessions = "sessions"
	// LockProcessUnknown: the process check failed, so whether the CLI runs is not known; the lock fails closed.
	LockProcessUnknown = "processUnknown"
)

// ScanResult is clean.scan.
type ScanResult struct {
	// CLIs are Claude Code and Codex in registry order (RD42: no other CLI's folders).
	CLIs []CLIScan `json:"clis"`
	// Items is the size of every Skill and Subagent row with a member the user can remove, by row key.
	Items []ItemSize `json:"items"`
}

// CLIScan is what one CLI leaves behind.
type CLIScan struct {
	CLI    string      `json:"cli"`
	Logs   LogScan     `json:"logs"`
	Caches []CacheScan `json:"caches"`
	Locks  Locks       `json:"locks"`
}

// LogScan is the session logs of one CLI.
type LogScan struct {
	// State is measured, missing (no logs folder) or unreadable (the folder exists and cannot be listed).
	State string `json:"state"`
	// Buckets holds only the ages with at least one log, ascending (RD-R17: empty log rows are not offered).
	Buckets []LogBucket `json:"buckets"`
}

// LogBucket is the logs older than an age.
type LogBucket struct {
	OlderThanDays int   `json:"olderThanDays"`
	Files         int   `json:"files"`
	Bytes         int64 `json:"bytes"`
}

// CacheScan is one allowlisted cache folder with something in it.
type CacheScan struct {
	ID   string `json:"id"`
	Path string `json:"path"`
	// Entries is how many entries sit directly in the folder: what a move takes, one rename each.
	Entries int   `json:"entries"`
	Files   int   `json:"files"`
	Bytes   int64 `json:"bytes"`
}

// Locks are what holds one CLI's logs and caches back; nil means not locked.
type Locks struct {
	Logs   *Lock `json:"logs"`
	Caches *Lock `json:"caches"`
}

// Lock is one lock with its reason.
type Lock struct {
	Reason string `json:"reason"`
	// Sessions are the Activity session ids that hold it, so the shell can name them; empty for processUnknown.
	Sessions []string `json:"sessions"`
	Message  string   `json:"message"`
}

// ItemSize is the allocated bytes a removal of the row's removable Skill and Subagent members frees: each real path
// once, a link as nothing (unlinking frees no data).
type ItemSize struct {
	Key   string `json:"key"`
	Bytes int64  `json:"bytes"`
}

// MoveParams is clean.move: which log buckets and which caches.
type MoveParams struct {
	Logs   []LogPick `json:"logs"`
	Caches []string  `json:"caches"`
}

// LogPick is the logs of one CLI older than one age.
type LogPick struct {
	CLI           string `json:"cli"`
	OlderThanDays int    `json:"olderThanDays"`
}

// MoveResult is what a move did. Entry is null when nothing moved (only with every group refused, which is an error).
type MoveResult struct {
	Entry *mutate.EntryRef `json:"entry"`
	// Moved is the files and allocated bytes that actually left the CLI folders (CL-R6).
	Moved mutate.TrashAmount `json:"moved"`
	// Groups is one row per picked group, in the order given: logs first, then caches.
	Groups []GroupResult `json:"groups"`
	// Cancelled is true when a $/cancelRequest stopped the move before its last file.
	Cancelled bool `json:"cancelled"`
	// Trash is the folder the files went to, inside the Trash.
	Trash *string `json:"trash"`
}

// GroupResult is one picked row: what moved, how many paths stayed and why.
type GroupResult struct {
	// ID is "logs:<cli>" or the cache id, the shell's row id.
	ID     string             `json:"id"`
	Moved  mutate.TrashAmount `json:"moved"`
	Stayed int                `json:"stayed"`
	Reason *string            `json:"reason"`
}

// ProgressParams is the clean/progress notification: phase "reading" archives the usage of the logs (CL-R3), phase
// "moving" renames; Bytes is what has moved so far.
type ProgressParams struct {
	Phase string `json:"phase"`
	Done  int    `json:"done"`
	Total int    `json:"total"`
	Bytes int64  `json:"bytes"`
}
