---
name: pi-extension-audit
disable-model-invocation: true
description: Audit the local pi extensions in `pi/.pi/agent/extensions/` after a pi coding agent upgrade. Runs typecheck, tests, and an export-surface diff against the last audited version, then reviews the CHANGELOG range for behavioural changes. Records the audited version in `pi/.pi/agent/extension-audit.json`.
---

# pi Extension Audit

Run after upgrading the pi coding agent to check whether the local extensions in
`pi/.pi/agent/extensions/` still hold.

## Why it is split in two

The mechanical checks and the changelog reading catch **different** classes of
breakage, and neither is sufficient alone:

- **Typecheck / export diff** catch signature-level breaks. These are often
  *undocumented* — the `TextContent` export gap fixed in `f23716e` never
  appeared in any changelog entry.
- **The changelog** catches behavioural breaks that typecheck perfectly clean:
  an event that now fires at a different point, a widget placement whose
  semantics changed, a lifecycle guarantee that was tightened.

Do not skip step 3 because step 1 was green. A green typecheck only proves the
extensions still *compile*.

## Step 1: Run the mechanical checks

```bash
bash ~/.claude/skills/pi-extension-audit/audit.sh
```

Add `--no-net` to skip the npm tarball download (export diff is then skipped).
Override the repo root with `DOTFILES=/path/to/dotfiles` if it is not
`~/.dotfiles`.

The script reports:

| Section | Meaning |
|---|---|
| `TYPECHECK` | All extensions compiled against the newly installed `.d.ts` files. Any error is real. |
| `TESTS` | Each extension's `test.mjs`. `NO TESTS` is a coverage gap worth flagging. |
| `EXPORT SURFACE DIFF` | Exports present in the last audited version but gone now, intersected with what the extensions actually import. |
| `imported ... NOT in its current surface` | An import that resolves to nothing today. Flagged even when `removed` is 0, which means it is **pre-existing**, not upgrade fallout. |
| `CHANGELOG RANGE` | The exact line range and version list to read in step 3. |

## Step 2: Triage the mechanical findings

For every finding, establish whether it is a **regression** or **pre-existing**
before reporting it. The two demand different urgency and different commit
messages.

The export diff already distinguishes them: a name under `REMOVED AND USED BY
YOUR EXTENSIONS` regressed in this window; a name under `NOT in its current
surface` with `removed: 0` was always broken.

To confirm a suspected pre-existing issue, check the published types of older
versions directly rather than assuming:

```bash
npm view @earendil-works/pi-coding-agent@<ver> dist.tarball
curl -sL <tarball-url> -o p.tgz && tar xzf p.tgz package/dist/index.d.ts
grep -c '<SymbolName>' package/dist/index.d.ts
```

A type-only import that vanished is **not** a runtime break — pi erases those
during transpilation, so tests pass and the extension loads fine. Say so
explicitly instead of implying an outage.

## Step 3: Read the changelog range

The script prints the exact line range. Read it and look specifically for:

- **Breaking Changes** sections — cross-check every renamed/removed symbol
  against what the extensions use.
- Changed semantics of APIs the extensions rely on. Get the actual usage with:
  ```bash
  rg -n 'pi\.on\(|pi\.register|ctx\.ui\.|ctx\.' pi/.pi/agent/extensions/*/index.ts
  ```
- New events/APIs that would let an extension drop a workaround. Report these
  as **optional**, clearly separated from breakage. Do not implement them
  unprompted.

## Step 4: Verify against a live run

Typecheck and unit tests both use mocks. Confirm the extensions genuinely load
under the new version — the cheapest signal is observing an extension's own
side effects in a real session (e.g. `trim-tool-output` appends a
`[trim-tool-output: kept ...]` notice to large tool results).

Also check anything that mutates state on startup actually behaved:

```bash
ls -la ~/.pi/agent/sessions/   # nerv-unified-sessions rewrites symlinks here
```

## Step 5: Report, then record

Report as a table — one row per extension, with typecheck/tests/status — then
detail each finding. Separate three buckets explicitly:

1. **Broken by the upgrade** — needs a fix now.
2. **Pre-existing latent issues** — surfaced by the audit, not caused by it.
3. **Optional adoption opportunities** — new APIs, no action taken.

Only after the audit concludes, record the version. The script prints the exact
command; it writes `pi/.pi/agent/extension-audit.json`:

```json
{ "lastAuditedVersion": "0.84.4", "auditedAt": "2026-08-31" }
```

**Record it even when findings remain**, as long as they have been triaged and
reported — the field means "audited at", not "clean at". Leaving it stale makes
the next run re-diff a window that was already reviewed. If findings were left
unfixed, say so in the report so they are not silently lost.

Do not commit anything unless asked. When asked, follow the commit style in
`CLAUDE.md` — and stage only the audit's own changes, since this repo commonly
has unrelated dirty files.
