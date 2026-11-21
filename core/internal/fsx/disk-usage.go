package fsx

import (
	"errors"
	"io/fs"
	"os"
	"path/filepath"

	"spacevibe.dev/core/internal/coreerr"
)

// Disk usage for Clean (CL-R6). A size is what the disk gives back once the file is gone: allocated blocks, the number
// `du` prints (BSD du counts st_blocks, not st_size; `du -A` would be the apparent size). Clean's scan and its move use
// these functions on the exact paths the move takes, so the estimate and the result are the same measure.

// Usage is the allocated bytes and the regular files under a path.
type Usage struct {
	Bytes int64
	Files int
}

// DiskUsage walks path without following any link (a link counts its own blocks) and sums the allocated bytes of every
// entry, folders included, and counts the regular files. A path that vanishes during the walk is skipped; an entry that
// cannot be read stops the walk with an error that names the path.
func DiskUsage(path string) (Usage, error) {
	var u Usage
	err := filepath.WalkDir(path, func(p string, d fs.DirEntry, err error) error {
		if err != nil {
			if errors.Is(err, fs.ErrNotExist) {
				return nil
			}
			return err
		}
		info, err := os.Lstat(p)
		if err != nil {
			if errors.Is(err, fs.ErrNotExist) {
				return nil
			}
			return err
		}
		u.Bytes += allocatedBytes(info)
		if info.Mode().IsRegular() {
			u.Files++
		}
		return nil
	})
	if err != nil {
		return Usage{}, coreerr.NewStatus("Could not measure "+path+" ("+reason(err)+").", coreerr.StatusInternalFailure)
	}
	return u, nil
}

// AllocatedBytes is the allocated size of one entry as Lstat reports it.
func AllocatedBytes(info fs.FileInfo) int64 { return allocatedBytes(info) }

// SameVolume reports whether every path (each must exist; links followed) sits on one device.
func SameVolume(paths ...string) (bool, error) {
	var first uint64
	for i, p := range paths {
		info, err := os.Stat(p)
		if err != nil {
			return false, coreerr.NewStatus("Could not read "+p+" ("+reason(err)+").", coreerr.StatusInternalFailure)
		}
		dev, ok := deviceOf(info)
		if !ok {
			return false, nil
		}
		if i == 0 {
			first = dev
		} else if dev != first {
			return false, nil
		}
	}
	return true, nil
}
