# Usage scan and pricing

How the core finds out which skills, subagents and hooks ran, by reading both CLIs' session logs, and how it turns logged tokens into an estimated cost. The Agents page and its filter counts read the scan through the inventory join ([inventory.md](inventory.md)); the Activity page shows the cost of each session. The scan counts names, days and hook runs and never reads a token; tokens and cost belong to Activity, which only borrows the price table. Terms follow [GLOSSARY.md](../../GLOSSARY.md).

Code: [`core/internal/usage`](../../core/internal/usage) (line parsers, the scanner, the scan cache, aggregation), [`core/internal/logs`](../../core/internal/logs) (log discovery, line reading and the zstd stream; its offset readers serve Activity and Limits, not the scan) and [`core/internal/pricing`](../../core/internal/pricing) (the embedded price table).

## Where each fact comes from

| Fact | Claude Code | Codex |
| --- | --- | --- |
| Logs | `projects/**` under the CLI's root, including `<session>/subagents/*.jsonl` | `sessions/**`, plain and `.jsonl.zst` |
| Skill use | A `Skill` tool call, or a user line holding `<command-name>/x</command-name>` | A tool call (`function_call`, `custom_tool_call`, `CommandExecution`) that names `skills/<folder>/SKILL.md` |
| Subagent use | `"subagent_type":"x"` | `agent_type` inside a tool call |
| Hook runs | `attachment` records whose `type` starts with `hook_`; identity is event plus command | Not logged; the parser has no hook branch |
| Hook errors, time | `type` containing `error` or `exitCode` not 0; `durationMs` | none |
| Day of a use | First ten characters of the line's `timestamp`; no timestamp: the log's mtime day in UTC | same |
| Session id | Log file name without suffix; a log under `subagents/` takes the folder above it | Rollout file name without suffix |
| Tokens (Activity) | `message.usage` of assistant records, with the 1h cache-write share in `cache_creation` | `token_count` events (`total_token_usage`, `last_token_usage`); no cache-write count is read |
| Model (Activity) | `message.model`, `<synthetic>` ignored | `turn_context.model`; none seen: `unknown` |

## Runtime path

1. The shell calls `usage.scan` ([core-protocol.md](core-protocol.md)); [`usageScan`](../../core/internal/rpc/methods/reads.go) calls `Scanner.Scan`. A second call while one runs is a 409.
2. `loadCache` reads the cache; anything unusable is an empty cache.
3. `logs.Walk` lists the Claude logs, then the Codex logs, each sorted by path.
4. Per log: `os.Stat`, stamp `<size>:<mtime ms>`. Same stamp and `ScanVersion`: reuse the record. Otherwise `scanFile` streams every line through `claudeLine` or `codexLine`.
5. Progress goes out after every 20 logs and once at the end.
6. If the context is still live, `saveCache` writes the records of this run, `aggregate` builds the `Result`, and `Scanner` keeps it as `last`.
7. `loadout.rows` reads `last` through `Last()`: `usage.Ready(result)`, or `usage.Scanning` before any scan finished in this process. The cells are built in [inventory.md](inventory.md#usage-cell-states).
8. Cost is a separate path: Activity folds tokens per log, [`costFor`](../../core/internal/activity/engine.go) sums them per session and model, and `pricing.EstimateCost` prices them.

## Rules that are easy to get wrong

- **Find and open logs only through `logs`, never by matching `.jsonl`.** Codex keeps older rollouts as `.jsonl.zst` (also `.zstd`). `Walk` lists them, and `ForEachChunk` decompresses by file name suffix alone, not by magic bytes. When both forms of one session sit in a folder, only the plain file is listed and its compressed twin is never read, even if the content differs. A reader that matches only `.jsonl` silently loses most of a machine's Codex history; one that lists both counts a session twice. `Walk` lists regular files only and follows no symlink, file or folder. [log-files.go](../../core/internal/logs/log-files.go), test `TestCompressedRollouts`.
- **A changed log is parsed again in full; the scan never resumes at an offset.** Trust is the stamp (size and mtime in ms) plus `ScanVersion`, never content, so a rewrite with the same size and mtime goes unseen. The stamp is taken before the read: bytes appended mid-parse leave a stale stamp, so the next scan parses again. Keep the stat first. Bump `ScanVersion` whenever a pattern or rule changes what a log yields, or every unchanged log keeps its old counts. The cache keeps only names, days, hook hashes and durations, never log text (S-R3), and only for logs seen this run, so a deleted log leaves it. [scanner.go](../../core/internal/usage/scanner.go), test `TestWindowAndCacheVersion`.
- **A session counts once per name, and a subagent log belongs to its parent session.** `aggregate` puts the session id in a set per name, so ten uses in one session are 1. A use inside `<session>/subagents/x.jsonl` counts for `<session>`. Hooks are the exception: every matching attachment adds one run. This is the Sessions versus Runs split in [GLOSSARY.md](../../GLOSSARY.md). [aggregate.go](../../core/internal/usage/aggregate.go), `sessionID` in [scanner.go](../../core/internal/usage/scanner.go).
- **Claude names come from the text shape of a line, not from parsed JSON.** The patterns need the exact key order with no spaces (`"name":"Skill","input":{"skill":"`), so a line written another way matches nothing and raises no error. Only hook attachments are parsed. A slash pattern takes any `/name`, built-in or not, and the inventory join keeps what is installed. `plugin:skill` is stored as `skill`, so same-named skills of two plugins merge. [lines.go](../../core/internal/usage/lines.go).
- **Codex skill and subagent use is inferred from tool calls only.** Codex writes no "skill invoked" record, so a tool call that names a `SKILL.md` path (usually a read) counts as use, under the folder name. A user message that merely quotes the path is ignored by `codexCallPattern`. No hook runs are logged, so a Codex hook is unmeasurable ([inventory.md](inventory.md#usage-cell-states)). Test `TestCodexCalls`.
- **A day is the date text written in the line, not a local date.** The first ten characters of `timestamp` are used as they are, with no zone conversion. The fallback is the log's mtime in UTC. `Windows.Oldest` is the first timestamp's day of the oldest log; `Windows.Newest` is the newest log's mtime, not a timestamp inside it. [lines.go](../../core/internal/usage/lines.go) `dayOf`, `isoDay`.
- **A model with no price has no estimate, never 0.** `Price` takes an exact name, else the name minus one trailing `[...]` and a `-YYYYMMDD` date. It never guesses by family. A model with tokens and no price makes the whole session's estimate a note naming that model; a model with zero tokens is skipped. A log that never names a model is keyed `unknown` and so unpriced. A log Activity read only from its tail has no estimate either. Price a model by adding it to `pricing.json`, which is the embedded table. [pricing.go](../../core/internal/pricing/pricing.go), test `TestEstimateRules`.
- **Tokens are increments, and `cacheWriteLong` is a share of `cacheWrite`.** Claude repeats a message's usage in streamed records, so the fold keeps the maximum per model and message id and adds only the growth. Codex logs input including cached tokens, so the fold subtracts the cached part before pricing it again as a cache read. `EstimateCost` bills `min(cacheWrite, cacheWriteLong)` at the long rate and the rest at the normal one; a log with only long tokens has no usage. [fold-claude.go](../../core/internal/activity/fold-claude.go), [fold-codex.go](../../core/internal/activity/fold-codex.go).
- **The arithmetic order of `EstimateCost` is pinned.** Models are summed in the order given, and each product is wrapped in `float64()` so arm64 cannot fuse a multiply with the add. The goldens compare exact values and `TestEstimateBitIdenticalToSwift` pins the bits; a tidy-up moves the last bit. [pricing.go](../../core/internal/pricing/pricing.go).

## Failure behavior

- **Missing or unreadable root or folder.** Counts as empty. The CLI's window stays at zero files, which the inventory join reads as "no scanned logs", never as an error.
- **A log that cannot be read to the end** (permission, vanished, FIFO, corrupt or truncated zstd, output over 512 MiB, declared window over 128 MiB). It is left out whole: no partial counts, no cache record. It still counts in `Result.Files`, while `Sessions` and `Windows.Files` count readable logs only. The scan carries on and the result lists no per-file error.
- **A line over 32 MiB.** Skipped without a count; the next line is read. A hook line that does not parse, or has no command, is skipped.
- **Cache unreadable, over 512 MiB or not JSON.** Treated as empty, so the next scan is full. One malformed entry drops only itself. A cache that cannot be written is ignored and costs only speed; the file is 0600 in a 0700 folder.
- **Cancel or a second scan.** The only errors a scan returns are the context's and the 409. A cancel leaves the cache and `last` as they were ([core-protocol.md](core-protocol.md)).
- **Errors carry no file content (S-R3).** zstd errors are fixed sentences, `ReadError` holds an errno, and the one logged string in a cost note is the model name.

## Verification

`cd core && SPACEVIBE_TEST=1 go test -count=1 ./internal/usage/... ./internal/logs/... ./internal/pricing/...` (the same packages run under `scripts/test.sh`), against temporary homes or the fixture home, never the real config.
