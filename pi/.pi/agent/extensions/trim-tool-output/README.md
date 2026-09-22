# trim-tool-output

Caps oversized tool results **at ingestion**, keeping head + tail *and* the
salient middle lines (errors, test failures, stack frames), and writes the full
output to disk so nothing is lost.

```
[trim-tool-output: kept 8.0KB of 28.3KB, incl. 7 salient middle line(s), 163 line(s)
omitted. Full output on disk — read it before concluding if diagnosing an error:
~/.pi/agent/tool-results/toolu_0166r3….txt]
```

## Why

A single `rg` over a large tree can put more text into the context window than
the rest of the session combined, and it stays there for every later request.
Blind head/tail truncation is the usual fix, but it drops exactly the lines you
needed — the error in the middle.

Two properties make this safe to do at ingestion:

- **cache-safe** — the result is transformed once, before it enters the cached
  prefix, and the stored entry is immutable, so it replays from cache instead of
  invalidating it every turn.
- **tree-safe** — the entry is capped once and never mutated, so resuming or
  branching any node sees identical content.

See [DESIGN.md](DESIGN.md) for the rationale and the Claude Code / Codex /
grok-cli comparison.

## Behaviour

| Situation | What happens |
|---|---|
| Result within `PI_TRIM_MAX_BYTES` **and** `PI_TRIM_MAX_LINES` | Untouched — true zero information loss |
| Over either limit | Head + salient middle + tail, plus a `[trim-tool-output: …]` notice |
| `PI_TRIM_MODE=persist` (default) | Full text written to `PI_TRIM_PERSIST_DIR/<toolCallId>.txt`, path quoted in the notice |
| `PI_TRIM_MODE=truncate` | Overflow dropped; notice still reports what was omitted |
| Disk write fails | Notice omits the path; the tool result is still returned |
| Tool listed in `PI_TRIM_NEVER_CAP_TOOLS` | Skipped entirely |
| Non-text content (images) | Passed through untouched, appended after the capped text |
| `session_start` | Disk GC runs (see below) |

Budget split within `PI_TRIM_MAX_BYTES`: head 50%, tail 30%, salient middle gets
the remainder. Salient lines are rendered with their original line numbers
(`L42| …`) so they can be located in the persisted file.

### Disk GC

Runs on `session_start`, decoupled from tool rounds so short sessions never
orphan files:

1. Delete files older than `PI_TRIM_GC_MAX_AGE_DAYS`.
2. If the directory still exceeds `PI_TRIM_GC_MAX_DIR_BYTES`, delete
   oldest-first until it fits.

Set either to `0` to disable that pass.

## Config (environment variables)

| Variable | Default | Meaning |
|---|---|---|
| `PI_TRIM_MAX_BYTES` | `8192` | Byte budget for the kept text; also the cap trigger |
| `PI_TRIM_MAX_LINES` | `300` | Line-count trigger — exceeding it caps even if under the byte budget |
| `PI_TRIM_HEAD_LINES` | `80` | Max lines kept from the start |
| `PI_TRIM_TAIL_LINES` | `40` | Max lines kept from the end |
| `PI_TRIM_MAX_SALIENT_LINES` | `60` | Max salient middle lines spliced in |
| `PI_TRIM_SALIENCE` | on | `off` disables salience detection (plain head/tail) |
| `PI_TRIM_EXTRA_PATTERNS` | – | Newline- or `\|\|`-separated regexes added to the salience set |
| `PI_TRIM_NEVER_CAP_TOOLS` | – | Comma-separated tool names to exempt, e.g. `bash` |
| `PI_TRIM_MODE` | `persist` | `persist` = full output to disk + preview; `truncate` = drop it |
| `PI_TRIM_PERSIST_DIR` | `~/.pi/agent/tool-results` | Where full outputs are written (`~` expanded) |
| `PI_TRIM_GC_MAX_AGE_DAYS` | `30` | Delete persisted files older than this; `0` disables |
| `PI_TRIM_GC_MAX_DIR_BYTES` | `536870912` (512 MB) | Directory cap, oldest deleted first; `0` disables |

Numeric variables fall back to their default when unset, empty, or not a number.

## Tests

```bash
node test.mjs
```

Mocks `ExtensionAPI` and the `tool_result` event, so no session is needed.
