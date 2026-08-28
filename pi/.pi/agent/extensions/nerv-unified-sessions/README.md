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

### Step 1: Manual Consolidation (one-time)

Run this to move all existing sessions:

```bash
# Create unified directory
mkdir -p ~/.pi/agent/sessions/--proj-nerv--

# Move all sessions into it
for dir in ~/.pi/agent/sessions/--proj-nerv_*--; do
  if [ -d "$dir" ] && [ ! -L "$dir" ]; then
    echo "Moving sessions from $(basename $dir)..."
    mv "$dir"/*.jsonl ~/.pi/agent/sessions/--proj-nerv--/ 2>/dev/null || true
  fi
done

# Verify
echo "Total sessions consolidated:"
ls -1 ~/.pi/agent/sessions/--proj-nerv--/ | wc -l
```

### Step 2: Install Extension

The extension is auto-discovered in `~/.pi/agent/extensions/`. On next `pi` launch:

1. The extension will detect remaining old session directories
2. It will create symlinks: `--proj-nerv_hk-- → --proj-nerv--`, etc.
3. New sessions go directly to `--proj-nerv--`

**No manual action needed** — it's automatic on first run.

### Step 3: Test

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
| Other projects | Unaffected; still use their own session directories |

## Implementation Details

- **Consolidation**: Runs once on extension load. Copies sessions from old dirs to unified one.
- **Symlinks**: Replaces old directories with symlinks so pi's session discovery automatically routes to the unified directory.
- **Graceful**: Only touches directories matching the `--proj-nerv_*--` pattern. Other sessions stay isolated.
- **Safe**: Uses `fs.copyFileSync` to preserve existing data before removing old directories.

## Reverting (if needed)

To separate sessions back out:

```bash
# Remove symlinks
rm -f ~/.pi/agent/sessions/--proj-nerv_hk-- ~/.pi/agent/sessions/--proj-nerv_ck-- \
      ~/.pi/agent/sessions/--proj-nerv_sg-- ~/.pi/agent/sessions/--proj-nerv_ave_ck--

# Recreate individual directories and split sessions manually (or restore from git)
# Then disable the extension: PI_NERV_UNIFIED_SESSIONS=off
```

## Config

| Variable | Default | Meaning |
|---|---|---|
| `PI_NERV_UNIFIED_SESSIONS` | on | `off`/`0`/`false` to disable |

To disable:

```bash
export PI_NERV_UNIFIED_SESSIONS=off
```

## See also

[`force-session-name`](../force-session-name) — ensure all sessions have meaningful display names (recommended companion extension).
