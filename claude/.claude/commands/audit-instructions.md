---
description: Review instruction artifacts (CLAUDE.md, AGENTS.md, skills, commands) for obsolete, redundant, conflicting, or drifted content
---

# Audit Instructions

Review the repo's instruction artifacts for content that is outdated, redundant
with built-in behavior, internally conflicting, or out of sync with the code it
describes.

Scope defaults to everything below. Narrow it if the user named a target.

| Kind | Where |
|---|---|
| Instruction files | `~/.claude/CLAUDE.md`, repo-root `CLAUDE.md`, nested `.claude/CLAUDE.md`, `~/.pi/agent/AGENTS.md` |
| Skills | `claude/.claude/skills/*/SKILL.md` + their helper scripts |
| Commands | `claude/.claude/commands/*.md` |

Skills and commands are instructions too — they are just instructions the model
loads on demand. The same rot applies.

## Step 1: Run the mechanical checks first

Do not spend judgment on anything a script can decide. Three deterministic
passes, each cheap:

```bash
# a. Doc-vs-code drift, for skills that ship a self-check.
bash ~/.claude/skills/pi-extension-audit/audit.sh --self-check

# b. Dead references — paths and files named in instructions that do not exist.
rg -oN '`[^`]*\.(md|sh|ts|mjs|json|go)`' --glob '*.md' ~/.claude claude/.claude \
  | sort -u

# c. Skills missing required frontmatter keys.
for f in claude/.claude/skills/*/SKILL.md; do
  head -8 "$f" | rg -q '^name:' || echo "no name: $f"
  head -8 "$f" | rg -q '^description:' || echo "no description: $f"
done
```

Resolve each path from (b) before reading further — a stale path is a finding,
not a judgment call.

Also check the `File Dependencies` table in `CLAUDE.md`: every row asserts a
coupling. Verify the left-hand file still exists and the right-hand file still
reflects it.

## Step 2: Classify each instruction

For every distinct instruction or rule, classify it as one of:

- **Redundant** — the system prompt already enforces this.
  Examples: "never use --no-verify", "prefer Edit over sed",
  "don't commit secrets", "create new commits instead of amending".

- **Conflicting** — contradicts built-in behavior or another instruction.
  Examples: "use rg instead of grep" (conflicts with a built-in Grep tool),
  two files prescribing different commit formats.

- **Stale** — references files, tools, or patterns that no longer exist
  or are no longer used.

- **Drifted** — prose that describes code, and no longer matches it. Section
  tables that omit a section the script emits, documented flags the script
  dropped, an example payload with the wrong keys. **Fix the prose, not the
  code** — the code is the side that runs, so it is the side that is right,
  unless the code itself is the bug.

- **Over-prescribed** — spells out behavior the model handles well natively
  (step-by-step instructions for trivial decisions, generic quality
  checklists).

- **Active** — genuinely custom preference, project-specific context, or
  behavioral guidance the model would not know without being told.

### Judging skills and commands specifically

Beyond the classes above, ask:

- **Does the command duplicate its skill?** A command should trigger and
  constrain, not restate. Prose living in both drifts in one.
- **Is the workflow still grounded?** A skill that cites a concrete past
  failure (a commit, a bug it caught) is anchored. One that only asserts
  best practice is a candidate for deletion.
- **Could a step be mechanical?** Any step asking the model to eyeball
  something a `grep` could decide belongs in a script, exactly as (a) above.
- **Is `disable-model-invocation` right?** Expensive or destructive skills
  should be explicit-invoke only.

## Step 3: Report

Output a concise report grouped by file:

```
## ~/.claude/CLAUDE.md

### Redundant
- Line NN: "never use --no-verify" — built-in system prompt rule

### Conflicting
- Line NN: "use rg for search" — conflicts with built-in Grep tool

### Stale
- Line NN: references @.claude/tooling.md — file no longer exists

### Drifted
- Line NN: section table omits `SUMMARY`, which audit.sh emits

### Over-prescribed
- Line NN: 5-step implementation flow — model follows TDD natively

### Summary
- Total instructions: NN
- Active: NN | Redundant: NN | Conflicting: NN | Stale: NN | Drifted: NN | Over-prescribed: NN
- Estimated token savings from cleanup: ~NNN tokens
```

## Step 4: Suggest

For each non-Active item, suggest one of:

- **Remove** — delete entirely
- **Condense** — rewrite in fewer words
- **Reword** — fix the conflict while preserving intent
- **Mechanize** — replace the prose with a deterministic check in a script

Do NOT apply changes automatically. Present suggestions for user review.

Do not commit anything unless asked.
