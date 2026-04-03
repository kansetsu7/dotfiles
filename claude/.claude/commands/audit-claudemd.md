---
description: Review CLAUDE.md files for obsolete, redundant, or conflicting instructions
---

# Audit CLAUDE.md

Review all CLAUDE.md files for instructions that are outdated, redundant with
Claude Code's built-in behavior, or internally conflicting.

## Step 1: Gather

Read every CLAUDE.md in scope:
- `~/.claude/CLAUDE.md` (global)
- Project-level `CLAUDE.md` (repo root)
- Any nested `.claude/CLAUDE.md`

Also check for referenced files (e.g., `@.claude/tooling.md`) — verify they
exist and are still relevant.

## Step 2: Classify each instruction

For every distinct instruction or rule, classify it as one of:

- **Redundant** — Claude Code's system prompt already enforces this.
  Examples: "never use --no-verify", "prefer Edit over sed",
  "don't commit secrets", "create new commits instead of amending".

- **Conflicting** — Contradicts built-in behavior.
  Examples: "use rg instead of grep" (conflicts with built-in Grep tool),
  "always use fd" (conflicts with built-in Glob tool).

- **Stale** — References files, tools, or patterns that no longer exist
  or are no longer used.

- **Over-prescribed** — Spells out behavior the model handles well natively
  at current capability level (e.g., step-by-step instructions for trivial
  decisions, generic quality checklists).

- **Active** — Genuinely custom preference, project-specific context, or
  behavioral guidance the model wouldn't know without being told.

## Step 3: Report

Output a concise report grouped by file:

```
## ~/.claude/CLAUDE.md

### Redundant
- Line NN: "never use --no-verify" — built-in system prompt rule
- Line NN: ...

### Conflicting
- Line NN: "use rg for search" — conflicts with built-in Grep tool

### Stale
- Line NN: references @.claude/tooling.md — file no longer exists

### Over-prescribed
- Line NN: 5-step implementation flow — model follows TDD natively

### Summary
- Total instructions: NN
- Active: NN | Redundant: NN | Conflicting: NN | Stale: NN | Over-prescribed: NN
- Estimated token savings from cleanup: ~NNN tokens
```

## Step 4: Suggest

For each non-Active item, suggest one of:
- **Remove** — delete entirely
- **Condense** — rewrite in fewer words
- **Reword** — fix the conflict while preserving intent

Do NOT apply changes automatically. Present suggestions for user review.
