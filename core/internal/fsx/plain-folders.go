package fsx

import (
	"io/fs"
	"os"
	"path/filepath"
	"strings"

	"spacevibe.dev/core/internal/coreerr"
)

// PlainFoldersBelow checks every folder between root and the entry at rel (rel is relative to root): each one must be
// a real folder, never a link, so a path that starts under a CLI root cannot leave it through a link planted inside
// (CL-R7). The root itself may be a link (a dotfiles setup); the entry is the caller's to check.
func PlainFoldersBelow(root, rel string) error {
	parent := filepath.Dir(rel)
	if parent == "." {
		return nil
	}
	dir := root
	for _, part := range strings.Split(parent, string(filepath.Separator)) {
		dir = filepath.Join(dir, part)
		info, err := os.Lstat(dir)
		if err != nil || !info.IsDir() || info.Mode()&fs.ModeSymlink != 0 {
			return coreerr.NewStatus(dir+" is not a plain folder, so nothing below it was moved.", coreerr.StatusConflict)
		}
	}
	return nil
}
