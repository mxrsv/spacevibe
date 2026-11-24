package inventory

import (
	"io"
	"io/fs"
	"os"
	"slices"

	"spacevibe.dev/core/internal/fsx"
	"spacevibe.dev/core/internal/ojson"
	"spacevibe.dev/core/internal/textjs"
)

const (
	// maxTextBytes: SKILL.md and agent files: only the head matters (frontmatter, description).
	maxTextBytes = 1 << 20
	// maxJSONBytes: settings and hook files.
	maxJSONBytes = 16 << 20
	// itemFileBytes is how much of a skill or agent file the detail view shows.
	itemFileBytes = 64 * 1024
)

// jsonStatus says how reading a JSON file went.
type jsonStatus int

const (
	jsonMissing jsonStatus = iota
	// jsonUnreadable: exists but cannot be opened or read (permission, a folder, a FIFO, an I/O error).
	jsonUnreadable
	jsonTooLarge
	jsonInvalid
	jsonValue
)

// exists is true only when the path is there.
func exists(path string) bool { return fsx.PathPresence(path) == fsx.Present }

// readData is up to maxBytes of the file; nil, false when it cannot be read.
func readData(path string, maxBytes int) ([]byte, bool) {
	f, err := fsx.OpenRegular(path)
	if err != nil {
		return nil, false
	}
	defer f.Close()
	data, err := io.ReadAll(io.LimitReader(f, int64(maxBytes)))
	if err != nil {
		return nil, false
	}
	return data, true
}

// readText is up to maxBytes of the file as text; invalid UTF-8 becomes U+FFFD, as Node does.
func readText(path string, maxBytes int) (string, bool) {
	data, ok := readData(path, maxBytes)
	if !ok {
		return "", false
	}
	return textjs.Repair(string(data)), true
}

// readJSON reads and parses a settings or hook file, classifying every failure.
func readJSON(path string) (ojson.Value, jsonStatus) {
	f, err := fsx.OpenRegular(path)
	if err != nil {
		if fsx.PathPresence(path) == fsx.Missing {
			return ojson.Value{}, jsonMissing
		}
		return ojson.Value{}, jsonUnreadable
	}
	defer f.Close()
	data, err := io.ReadAll(io.LimitReader(f, maxJSONBytes+1))
	if err != nil {
		return ojson.Value{}, jsonUnreadable
	}
	if len(data) > maxJSONBytes {
		return ojson.Value{}, jsonTooLarge
	}
	doc, err := ojson.ParseString(textjs.Repair(string(data)))
	if err != nil {
		return ojson.Value{}, jsonInvalid
	}
	return doc.Root(), jsonValue
}

// unusableReason finishes the sentence about a JSON file that was there but gave nothing; "" when the file is
// missing or fine.
func unusableReason(status jsonStatus) string {
	switch status {
	case jsonInvalid:
		return "is not valid JSON"
	case jsonTooLarge:
		return "is too large to read"
	case jsonUnreadable:
		return "cannot be read"
	}
	return ""
}

// listDir is the entry names of a folder, sorted. Empty when the folder is missing or cannot be read.
func listDir(path string) []string {
	entries, err := os.ReadDir(path)
	if err != nil {
		return nil
	}
	names := make([]string, len(entries))
	for i, e := range entries {
		names[i] = e.Name()
	}
	slices.Sort(names)
	return names
}

// isUnreadableFolder: the folder exists but cannot be listed, or a parent denies the lookup so nobody can
// tell (a denied folder reads as "not readable", never as empty).
func isUnreadableFolder(path string) bool {
	switch fsx.PathPresence(path) {
	case fsx.Missing:
		return false
	case fsx.Unknown:
		return true
	}
	if !isDirectory(path) {
		return false
	}
	_, err := os.ReadDir(path)
	return err != nil
}

// isDirectory follows symlinks. False for a path that cannot be statted.
func isDirectory(path string) bool {
	info, err := os.Stat(path)
	return err == nil && info.IsDir()
}

// modifiedMs is the modification time in ms since 1970, following symlinks; false when it cannot be statted.
// Computed as seconds*1000 + nanoseconds/1e6 in floating point, like the Swift reader.
func modifiedMs(path string) (float64, bool) {
	info, err := os.Stat(path)
	if err != nil {
		return 0, false
	}
	t := info.ModTime()
	return float64(t.Unix())*1000 + float64(t.Nanosecond())/1_000_000, true
}

// isSymlink reports whether the path itself is a symlink.
func isSymlink(path string) bool {
	info, err := os.Lstat(path)
	return err == nil && info.Mode()&fs.ModeSymlink != 0
}

func osStat(path string) (fs.FileInfo, error) { return os.Stat(path) }
