# trim-tool-output — Design & Research Notes

Local pi extension to (1) hide tool-use detail in the TUI and (2) minimize
tool output retained in the model context.

Status: **design / discussion** — not yet implemented.

## Goals

1. **#1 Display** — collapse tool call/result noise so the transcript reads as
   a human↔agent conversation.
2. **#2 Context** — cap how many tokens tool results consume, both at ingestion
   and over the life of a (tree-structured) session.

## How other agents handle #1 and #2 (research)

### Claude Code — 5-level progressive compression (cheapest → heaviest)

1. **Tool Result Budget (zero cost):** tool result > **50k chars**
   (`DEFAULT_MAX_RESULT_SIZE_CHARS`) → **persist full output to disk**, keep a
   **2KB preview** in context inside `<persisted-output>` with the file path.
   Lossless: model can `Read` it back. Not truncation.
2. **History Snip (zero cost):** GC stale conversation scaffolding; feeds
   `snipTokensFreed` into the autocompact accounting so it doesn't over-fire.
3. **Microcompact (zero API cost):** clears OLD tool results, keeping the **N
   most recent compactable** ones; rest replaced with
   `[Old tool result content cleared]`. **Dual path selected by cache state:**
   - Path A — cache **cold** (prompt cache expired, default **5-min TTL**):
     directly rewrite message content (cache already dead, rebuild inevitable).
   - Path B — cache **hot** (active chat, warm prefix): use API-level
     `cache_edits` (tag blocks w/ `cache_reference`, server-side delete) so the
     warm cache is preserved; local messages returned unchanged.
4. **Context Collapse (zero, non-destructive):** projection-based folding ~90%.
5. **Autocompact (1 API call, irreversible):** fork child agent → full summary.
   Circuit breaker: stop after `MAX_CONSECUTIVE_AUTOCOMPACT_FAILURES = 3`.

Display: collapses tool calls by default (expand w/ ctrl-r); a configurable
verbosity toggle is still an open feature request.

### Codex CLI — simple hardcoded truncation

- Tool outputs truncated at **10 KiB or 256 lines** before entering context;
  **preserves head + tail**, marks the removed middle. Lossy, not disk-backed.
- Weakness: some paths bypass it — a single `function_call_output` of
  **948,372 tokens** was reported, bloating context and draining the 5h quota.
  Lesson: cap *every* tool result, no exceptions.

### grok-cli — same engine as pi (shared lineage)

- `src/agent/compaction.ts` ≈ pi's: `TOOL_RESULT_MAX_CHARS = 2000`,
  `DEFAULT_RESERVE_TOKENS = 16384`, `DEFAULT_KEEP_RECENT_TOKENS = 20000`,
  same structured summary format, trigger
  `contextTokens > contextWindow - reserveTokens`.
- Tool results truncated to 2000 chars **only during summary serialization**
  (i.e. only when compaction fires) — NOT at ingestion.
- Relies on **sub-agents (on by default)** to isolate big tool output.
- No mid-session "clear stale tool results" (no microcompact equivalent).

### pi (current state)

- Same as grok-cli. Compaction settings (`~/.pi/agent/settings.json`):
  `compaction.enabled=true`, `reserveTokens=16384`, `keepRecentTokens=20000`.
- Tool results only trimmed (to 2000 chars) during summary serialization.
- On a **1M window** the trigger sits at ~**984k** → compaction essentially
  never fires → tool output is never trimmed at ingestion → unbounded growth.

### Comparison

| Capability                              | Claude Code | Codex | grok-cli | pi (now) |
|-----------------------------------------|:-----------:|:-----:|:--------:|:--------:|
| Cap tool output **at ingestion** (#2)   | ✅ 50k→disk | ✅ 10KiB/256ln | ❌ | ❌ |
| Clear **stale** tool results mid-session| ✅ microcompact | ❌ | ❌ | ❌ |
| Cache-aware pruning                     | ✅ | ❌ | ❌ | ❌ |
| Summarize at threshold                  | ✅ (last) | ✅ | ✅ | ✅ (~never at 1M) |
| Collapse tool detail in UI (#1)         | ✅ default | ✅ | ✅ | ❌ (needs plugin) |
| Sub-agent isolation                     | ✅ | ~ | ✅ default | ❌ |

## pi extension hooks available (from docs/extensions.md)

- `tool_result` — **can modify** a tool result as it's produced (ingestion cap).
- `context` — **can modify messages** before each request (stale pruning).
- Custom rendering — control how tool calls/results appear in the TUI (#1).
- `session_before_compact` / `session_compact` — custom summarization.

## The prompt-cache constraint (decisive for the design)

Prompt caching is **exact-prefix**: content is cached up to the first byte that
differs from the previous request. Anthropic pricing ≈ cache-write **1.25×**,
cache-read **0.1×**, normal input **1×**.

**Consequence:** any hook that *rewrites an earlier message* invalidates the
cache from that point onward. Folding old tool results every turn repeatedly
nukes the cache — a net loss at high hit rates (e.g. observed `CH98.7%`).

Trace (fold = replace body with summary/placeholder):

```
Req 1:  [sys][r1:8KB]                     → cache-write sys + r1
Req 2:  [sys][fold(r1)][r2:12KB]          → hit only [sys]; r1's 8KB cache WASTED,
                                            re-process from fold(r1) onward
Req 3:  [sys][fold(r1)][fold(r2)][r3]     → hit [sys][fold(r1)]; r2's 12KB WASTED
```

vs **append-only** (never fold): prefix only grows at the tail → every prior
block stays cached (0.1× reads), only the new delta is a cache-write.
Cache-optimal, but context grows.

| Strategy               | Context tokens | Cache behavior                    |
|------------------------|:--------------:|-----------------------------------|
| Append-only (no fold)  | grows          | **optimal** (append-only prefix)  |
| Fold every turn        | minimal        | **hostile** (re-invalidates each) |
| Fold **batched** at HWM| steps down     | one invalidation per fold, stable between |

**Why Claude Code escapes it (we can't fully):** its microcompact only rewrites
inline when the cache is *already* cold (5-min TTL expired → nothing to lose),
and when hot it uses server-side `cache_edits` to delete blocks **in place**
without re-upload. `cache_edits` is a privileged CC↔Anthropic mechanism **not
exposed to pi extensions** — our `context` hook can only do the cache-hostile
rewrite. So per-turn collapse in pi is a trap.

### Key implication

- **Ingestion cap is cache-SAFE by construction** — it transforms the result
  *once at creation*, before it ever enters the cached prefix; the entry is then
  immutable and caches/replays normally. It shrinks context **and** keeps cache
  warm. → **primary lever.**
- **Stale-pruning/collapse is inherently cache-costly** for a third party →
  only worthwhile **batched at a token high-water mark** (like a mini-compaction
  that rebuilds one new stable prefix), never per-turn. → **optional, off by
  default**, especially pointless on a 1M window that has little pressure.

## Proposed design

Single local extension `pi/.pi/extensions/trim-tool-output/`:

1. **Ingestion cap (`tool_result` hook)** — PRIMARY, cache-safe, tree-safe.
   If output > `maxChars` (~8KB):
   - **Mode `persist` (recommended, lossless, Claude-Code-style):** write full
     output to disk, keep head preview + path + `[N chars omitted, see <path>]`.
   - **Mode `truncate` (lossy, Codex-style):** keep head + tail + marker.
   Applied once at production time → immutable entry → same on every tree branch.
2. **(optional, OFF by default) Batched collapse (`context` hook)** — only when
   context tokens cross a high-water mark; fold tool-result bodies older than the
   hot-tail window into `«summary»`/`[folded → <path>]` in the **outgoing request
   only** (non-destructive `projectView` — stored entries untouched). Batched so
   the cache breaks once per fold event, not per turn. Discouraged on 1M windows.
3. **#1 Display** — pair with `pi-compact-transcript` (one-line collapsed view)
   OR add a render hook here.

### Config (draft)

```json
{
  "trimToolOutput": {
    "maxChars": 8192,
    "mode": "persist",            // "persist" | "truncate"
    "persistDir": "~/.pi/agent/tool-results",
    "headChars": 2048,
    "tailChars": 512,             // truncate mode only
    "collapse": {
      "enabled": false,           // batched stale-collapse; off by default
      "highWaterTokens": 300000,  // only fold once context crosses this
      "hotTailResults": 8         // keep N most recent results inline
    },
    "gc": {
      "maxAgeDays": 30,           // age-based sweep at session_start
      "maxDirBytes": 536870912    // cap persistDir total size (LRU by mtime)
    }
  }
}
```

## Resolved decisions

- **Trigger basis.** Ingestion cap: per-result **size** (`maxChars`), applied
  always. Collapse (if enabled): **token high-water mark**, batched — NOT time,
  NOT per-round. Recency only selects the hot tail to keep.
- **Disk-orphan lifecycle.** Decoupled from rounds. Only large outputs are
  persisted (keeps footprint small). Files keyed by `tool_use_id`. **Age/size
  GC** (`gc.maxAgeDays`, `gc.maxDirBytes`, LRU by mtime) runs at `session_start`
  — independent of how any session ends, so no round-based orphans.
- **Tree-structure hazard.** Never mutate stored session entries.
  - Ingestion cap is written **once, immutably** → identical on every branch;
    full text on disk keyed by `tool_use_id`, retained for the whole tree.
  - Collapse is a **non-destructive `projectView`** over the outgoing request
    only → resume/branch any node still sees the full (capped) history.

## Salience-aware capping (why positional truncation isn't enough)

Keeping only one end (head or tail) can drop the **critical middle** — e.g. a
test failure whose root cause is a stack frame in the middle of a long log. The
model may then conclude wrongly and never realize it should `read` the persisted
file. Claude Code's Level 1 (head-only preview) and Codex (head+tail) share this
weakness.

Fix: when over budget, assemble **head + salient-middle + tail**:
1. Keep a head block (recent-context anchor) and a tail block (summaries/final
   status usually land at the end).
2. Scan the omitted middle for **high-signal lines** (errors, failures, stack
   frames) and splice them in — with their original 1-based line numbers so the
   model can locate them in the persisted full file.
3. Enforce the byte budget across all three sections; persist full output to disk
   as the safety net.

### Stack-specific salience (project: /proj/nerv_sg — Rails + Go + Clojure/CLJS, dockerized)

Patterns live in `patterns.ts`, grouped and commented for easy iteration.
**Matching is unanchored/substring** so docker-compose log prefixes
(`web-1  | Failure/Error:`) and `docker exec` wrappers don't defeat them.

- **Generic:** `error`, `failed`, `failure`, `fatal`, `panic`, `exception`,
  `timeout`, `refused`, `undefined`, `unable to`, `not found` (word-boundary,
  case-insensitive) + any `\.(ext):\d+` file:line reference.
- **Ruby / Rails:** `Failure/Error:`, rspec `\d+ examples?, \d+ failures?`,
  minitest `\d+ runs?, .*\d+ failures?, \d+ errors?`, `\.rb:\d+:in`,
  `ActiveRecord::`, `PG::`, `NoMethodError`, `rails aborted!`, `rake aborted!`.
- **Go:** `--- FAIL`, `^FAIL\b`, `panic:`, `goroutine \d+`, `\.go:\d+`,
  `cannot use`, `undefined:`, `build failed`, `go: `.
- **Clojure / ClojureScript:** `FAIL in`, `ERROR in`, clojure.test
  `expected:` / `actual:`, `Syntax error`, `CompilerException`,
  `Execution error`, `\.clj[cs]?:\d+`, `at [\w.$]+\(.*:\d+\)`,
  shadow-cljs `------ WARNING`, `Closure compilation failed`,
  `The required namespace .* is not available`.
- **Docker:** `Error response from daemon`, `Cannot connect to the Docker
  daemon`, `exited with code \d+`, `failed to solve`, `ERROR \[`,
  `service .* failed to build`.

### Dockerized-dev considerations

- **Persist dir is pi-side, on the persistent volume** (`~/.pi/agent/tool-results`
  → `/root` named volume). pi and its `read` tool run in the same dev container,
  so persisted paths are always resolvable back by the model. Output produced
  *inside another container* (via `docker exec`/`compose run`) is still captured
  and persisted on pi's side, not in the target container.
- Log-prefix tolerance: patterns are substring, not `^`-anchored.

### Extra config (salience)

```json
{
  "salience": { "enabled": true, "headLines": 80, "tailLines": 40, "maxSalientLines": 60 },
  "neverCapTools": []   // e.g. ["bash"] to never cap test runs; empty = cap all
}
```
Env overrides: `PI_TRIM_SALIENCE=off`, `PI_TRIM_HEAD_LINES`, `PI_TRIM_TAIL_LINES`,
`PI_TRIM_MAX_SALIENT_LINES`, `PI_TRIM_NEVER_CAP_TOOLS=bash`,
`PI_TRIM_EXTRA_PATTERNS` (newline/`||`-separated regex strings for project tweaks).

## Build order

1. **Ingestion cap first** (`tool_result` hook, `persist` mode) + age/size GC.
   Biggest win, cache-safe, tree-safe. ✅ done
2. **Salience-aware head+tail+middle** with stack-specific patterns. ✅ done
3. Pair `pi-compact-transcript` for #1 display.
4. Batched collapse only if long single-branch sessions prove it's needed.

## Iteration notes (pi is new here — expect churn)

- Patterns are data in `patterns.ts` — edit/add without touching capping logic.
- `test.mjs` loads the extension via jiti (same loader pi uses) with real
  Rails/Go/Clojure/Docker error samples; run `node test.mjs` after any change.
- API surface used (pin points if pi updates): `tool_result` event
  (`content`, `toolName`, `toolCallId`), `ToolResultEventResult.content`,
  `session_start`; utils `truncateHead`/`truncateTail`/`formatSize` from
  `@earendil-works/pi-coding-agent`. Re-verify these on pi version bumps.
