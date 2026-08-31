# nerv-unified-sessions

Unifies session storage across multiple Nerv worktrees so you can resume sessions from any subsidiary repo.

## Problem

With multiple git worktrees (nerv_hk, nerv_ck, nerv_sg, nerv_ave_ck), pi stores sessions separately by pwd:
- Session started in `/proj/nerv_hk` → `~/.pi/agent/sessions/--proj-nerv_hk--/`
- Session started in `/proj/nerv_ck` → `~/.pi/agent/sessions/--proj-nerv_ck--/`

You can only resume a session in the worktree where it was created, even though most features are shared.

## Solution

This extension:
1. **Consolidates** all existing Nerv sessions into `~/.pi/agent/sessions/--proj-nerv--/`
2. **Symlinks** old directories to the unified one so new sessions always land in the same place
3. Works **transparently** — you can now `pi` from any Nerv worktree and resume any Nerv session

## Setup

### Step 1: Install Extension

The extension is auto-discovered in `~/.pi/agent/extensions/`. No manual
consolidation step is needed — on the next `pi` launch it will:

1. Detect old session directories matching `--proj-nerv_*--`
2. Move their sessions into `--proj-nerv--`
3. Replace each one with a symlink: `--proj-nerv_hk-- → --proj-nerv--`

After that first run it is a no-op: already-linked directories are left
completely untouched, so it performs zero filesystem writes on every
subsequent launch.

### Step 2: Test

```bash
cd /proj/nerv_hk
pi
# Verify you see sessions from all worktrees in /resume

cd /proj/nerv_sg  
pi -r  
# You should see the same session list here
```

## Behaviour

| Situation | What happens |
|---|---|
| `pi` in any nerv_* worktree | Sessions listed from `--proj-nerv--` |
| `/resume` | Shows all Nerv sessions, regardless of which worktree you're in |
| `--proj-nerv_*--` dirs | Symlinked to `--proj-nerv--` for backward compatibility |
| Already-symlinked dir | Left untouched (no writes); only re-pointed if it aims elsewhere |
| Name collision in unified | Existing file wins; the incoming one is kept as `<name>.conflict-<ts>` |
| Old dir contains a subdirectory | Dir is left in place, not symlinked; its `.jsonl` files still move |
| Other projects | Unaffected; still use their own session directories |

## Implementation Details

- **Consolidation**: runs on extension load, and is idempotent — a directory
  that is already a symlink to the unified dir is skipped without any writes.
- **Symlinks**: replaces old directories with symlinks so pi's session
  discovery automatically routes to the unified directory.
- **Graceful**: only touches directories matching `PI_NERV_UNIFIED_SESSIONS_PATTERN`.
  Other sessions stay isolated.
- **Safe**: sessions are *moved* (`renameSync`, falling back to copy+unlink
  across filesystems), and a source directory is only removed with `rmdirSync`
  once it is verifiably empty. A partial or failed move leaves the directory
  and its data in place rather than deleting it.

### Detection footgun

`fs.statSync()` follows symlinks, so `statSync(dir).isSymbolicLink()` is *always*
false. An earlier version used it and therefore re-consolidated and re-created
every symlink on each launch. Detection uses `fs.lstatSync()`.

## Reverting (if needed)

To separate sessions back out:

```bash
# Remove symlinks
rm -f ~/.pi/agent/sessions/--proj-nerv_hk-- ~/.pi/agent/sessions/--proj-nerv_ck-- \
      ~/.pi/agent/sessions/--proj-nerv_sg-- ~/.pi/agent/sessions/--proj-nerv_ave_ck--

# Recreate individual directories and split sessions manually (or restore from git)
# Then disable the extension: PI_NERV_UNIFIED_SESSIONS=off
```

## Tests

```bash
node test.mjs
```

Runs against a throwaway session tree under `$TMPDIR`; your real
`~/.pi/agent/sessions` is never touched.

## Config

| Variable | Default | Meaning |
|---|---|---|
| `PI_NERV_UNIFIED_SESSIONS` | on | `off`/`0`/`false` to disable |
| `PI_NERV_UNIFIED_SESSIONS_DIR` | `--proj-nerv--` | Name of the unified session directory |
| `PI_NERV_UNIFIED_SESSIONS_PATTERN` | `^--proj-nerv_.*--$` | Regex for directories to fold in |

To disable:

```bash
export PI_NERV_UNIFIED_SESSIONS=off
```

## See also

[`force-session-name`](../force-session-name) — ensure all sessions have meaningful display names (recommended companion extension).
