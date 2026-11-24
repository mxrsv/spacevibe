package textjs

import "strings"

// trimTrailingSlashes drops trailing "/" while more than one byte remains.
func trimTrailingSlashes(path string) string {
	for len(path) > 1 && strings.HasSuffix(path, "/") {
		path = path[:len(path)-1]
	}
	return path
}

// Basename is Node's path.basename on POSIX.
func Basename(path string) string {
	trimmed := trimTrailingSlashes(Repair(path))
	if trimmed == "/" {
		return ""
	}
	return trimmed[strings.LastIndexByte(trimmed, '/')+1:]
}

// Dirname is Node's path.dirname on POSIX (as the Swift port implements it).
func Dirname(path string) string {
	trimmed := trimTrailingSlashes(Repair(path))
	slash := strings.LastIndexByte(trimmed, '/')
	switch slash {
	case -1:
		return "."
	case 0:
		return "/"
	}
	return trimmed[:slash]
}

// JoinPath is NSString's appendingPathComponent: single slashes, nothing cleaned.
func JoinPath(base string, parts ...string) string {
	for _, p := range parts {
		base = strings.TrimRight(base, "/") + "/" + p
	}
	return base
}

// Normalize is path.resolve for an absolute path: "." and ".." folded, no trailing slash. Symlinks are not
// followed.
func Normalize(path string) string {
	var stack []string
	for _, part := range strings.Split(path, "/") {
		switch part {
		case "", ".":
		case "..":
			if len(stack) > 0 {
				stack = stack[:len(stack)-1]
			}
		default:
			stack = append(stack, part)
		}
	}
	return "/" + strings.Join(stack, "/")
}
