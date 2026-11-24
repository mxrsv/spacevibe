package mutate

import (
	"errors"
	"io"

	"spacevibe.dev/core/internal/fsx"
)

var errTooLarge = errors.New("file too large")

// readRegular reads a whole regular file. limit < 0 means no limit; otherwise a larger file gives errTooLarge. The
// result is never nil on success (an empty file is an empty, non-nil slice).
func readRegular(path string, limit int64) ([]byte, error) {
	f, err := fsx.OpenRegular(path)
	if err != nil {
		return nil, err
	}
	defer f.Close()
	var r io.Reader = f
	if limit >= 0 {
		r = io.LimitReader(f, limit+1)
	}
	data, err := io.ReadAll(r)
	if err != nil {
		return nil, err
	}
	if limit >= 0 && int64(len(data)) > limit {
		return nil, errTooLarge
	}
	if data == nil {
		data = []byte{}
	}
	return data, nil
}
