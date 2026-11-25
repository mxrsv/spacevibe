package fsx

import (
	"io/fs"
	"os"
	"time"
)

// ModificationTime is the file's modification time, to the nanosecond where the filesystem keeps it.
// Swift's modificationTime(_:) picked st_mtimespec on Darwin and st_mtim elsewhere; Go's
// os.FileInfo already does that, so this is only a named, documented entry point.
func ModificationTime(info fs.FileInfo) time.Time { return info.ModTime() }

// ModifiedMs is the modification time in ms since 1970, following symlinks; false when it cannot be statted.
// Computed as seconds*1000 + nanoseconds/1e6 in floating point, like the Swift readers.
func ModifiedMs(path string) (float64, bool) {
	info, err := os.Stat(path)
	if err != nil {
		return 0, false
	}
	t := info.ModTime()
	return float64(t.Unix())*1000 + float64(t.Nanosecond())/1_000_000, true
}
