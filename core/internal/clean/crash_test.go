package clean

import "runtime"

// crashHere ends the calling goroutine at once, running only its deferred calls: what a core that dies mid-move
// leaves on disk (the kernel drops the flock the same way the deferred unlock does).
func crashHere() { runtime.Goexit() }
