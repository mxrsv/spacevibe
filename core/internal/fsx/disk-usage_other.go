//go:build !unix

package fsx

import "io/fs"

// allocatedBytes falls back to the apparent size where no block count exists.
func allocatedBytes(info fs.FileInfo) int64 { return info.Size() }

// deviceOf cannot tell a volume here, so SameVolume answers false and Clean refuses to move (fail closed).
func deviceOf(fs.FileInfo) (uint64, bool) { return 0, false }
