package fsx

import (
	"path/filepath"

	"spacevibe.dev/core/internal/textjs"
)

// RealPath is the path with symlinks followed, or the normalized path when it does not exist.
func RealPath(path string) string {
	abs := textjs.Normalize(path)
	if resolved, err := filepath.EvalSymlinks(abs); err == nil {
		return resolved
	}
	return abs
}
