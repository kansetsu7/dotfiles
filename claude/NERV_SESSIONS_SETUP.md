# Nerv Unified Sessions Setup Guide

## Overview

This guide consolidates session histories across all Nerv worktrees (nerv_hk, nerv_ck, nerv_sg, nerv_ave_ck) into a single directory, allowing you to resume any session from any worktree.

## Files Created

- **Extension**: `/root/.pi/agent/extensions/nerv-unified-sessions/`
  - `index.ts` — consolidation logic (auto-detects and symlinks old directories)
  - `README.md` — detailed docs

## Setup Instructions

### Step 1: Run Consolidation Script

This moves all existing sessions into the unified directory:

```bash
mkdir -p ~/.pi/agent/sessions/--proj-nerv--

# Move all existing nerv sessions
for dir in ~/.pi/agent/sessions/--proj-nerv_*--; do
  if [ -d "$dir" ] && [ ! -L "$dir" ]; then
    echo "Moving sessions from $(basename $dir)..."
    mv "$dir"/*.jsonl ~/.pi/agent/sessions/--proj-nerv--/ 2>/dev/null || true
  fi
done

# Verify consolidation
echo ""
echo "Total consolidated sessions:"
ls -1 ~/.pi/agent/sessions/--proj-nerv--/ | wc -l
```

**Expected output**: Should show the total count of `.jsonl` files moved.

### Step 2: Start Pi

Next time you run `pi` from any Nerv worktree, the extension will:
1. Auto-detect remaining old session directories
2. Create symlinks: `--proj-nerv_hk-- → --proj-nerv--`, etc.
3. Route all new sessions to `--proj-nerv--`

**No manual symlink creation needed** — the extension handles it.

### Step 3: Verify

```bash
# Test in one worktree
cd /proj/nerv_hk
pi -r

# You should see all consolidated sessions, not just ones from nerv_hk
# Sessions will show their creation date/time
```

### Step 4 (Optional): Name Your Sessions

For better organization across worktrees, use `force-session-name` extension (already enabled):

```bash
# When creating a new session in any worktree, you'll be prompted for a name
cd /proj/nerv_ck
pi

# Follow the name prompt to give it a meaningful name
# e.g., "Audit refactor — nerv_ck" or "Fix payment flow"
```

## Testing Checklist

- [ ] Step 1 consolidation script runs without errors
- [ ] `~/.pi/agent/sessions/--proj-nerv--/` contains all `.jsonl` files
- [ ] `pi -r` in `/proj/nerv_hk` shows all sessions
- [ ] `pi -r` in `/proj/nerv_ck` shows the same sessions
- [ ] New session created in `/proj/nerv_sg` appears in `/proj/nerv_ave_ck`'s session list

## Troubleshooting

### Sessions aren't showing up in other worktrees

1. Verify consolidation completed:
   ```bash
   ls ~/.pi/agent/sessions/--proj-nerv--/ | head -5
   ```

2. Check that old directories are symlinked:
   ```bash
   ls -la ~/.pi/agent/sessions/--proj-nerv* | head
   # You should see `--proj-nerv_hk-- -> --proj-nerv--` (symlink)
   ```

3. If symlinks weren't created, run pi from a Nerv worktree once to trigger auto-linking:
   ```bash
   cd /proj/nerv_hk && pi -c  # Should log consolidation
   ```

### "Command not found: pi"

Set up pi in your shell:
```bash
export PATH="/root/.pi/agent/bin:$PATH"
# Or add to ~/.zshrc / ~/.bashrc
```

### I want to disable this for a session

```bash
# Temporarily disable
export PI_NERV_UNIFIED_SESSIONS=off
pi

# Or permanently in ~/.zshrc
echo 'export PI_NERV_UNIFIED_SESSIONS=off' >> ~/.zshrc
```

### Reverting to separate sessions

```bash
# Remove symlinks
rm -f ~/.pi/agent/sessions/--proj-nerv_hk-- \
      ~/.pi/agent/sessions/--proj-nerv_ck-- \
      ~/.pi/agent/sessions/--proj-nerv_sg-- \
      ~/.pi/agent/sessions/--proj-nerv_ave_ck--

# Disable extension
export PI_NERV_UNIFIED_SESSIONS=off
```

## How It Works

1. **On first launch** (from any Nerv worktree):
   - Extension loads and reads `~/.pi/agent/sessions/`
   - Finds all `--proj-nerv_*--` directories
   - Moves their `.jsonl` files to `--proj-nerv--`
   - Replaces old directories with symlinks

2. **On subsequent launches**:
   - Pi's session discovery sees `--proj-nerv_*--` → all symlink to `--proj-nerv--`
   - All sessions appear unified regardless of which worktree you're in

3. **New sessions**:
   - When you `pi` from `/proj/nerv_ck`, pi looks for sessions in the cwd-derived path
   - But that path is symlinked to `--proj-nerv--`, so new sessions go there automatically

## File Structure (After Setup)

```
~/.pi/agent/sessions/
├── --proj-nerv--/                    # Unified directory (real)
│   ├── 2026-08-18T06-24-23-992Z_....jsonl
│   ├── 2026-08-19T06-16-11-542Z_....jsonl
│   └── ...
│
├── --proj-nerv_hk-- → --proj-nerv-- # Symlink
├── --proj-nerv_ck-- → --proj-nerv-- # Symlink
├── --proj-nerv_sg-- → --proj-nerv-- # Symlink
└── --proj-nerv_ave_ck-- → --proj-nerv-- # Symlink
```

## See Also

- [`force-session-name`](~/.pi/agent/extensions/force-session-name/README.md) — name your sessions meaningfully
- [`session-header`](~/.pi/agent/extensions/session-header/README.md) — display session name in footer
