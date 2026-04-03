# Dotfiles Repository

## Environment

This is a dotfiles repo used inside a dockerized dev environment.

- **Dockerized dev repo**: `/project/vm/docker-dev/`
- **Dockerfile**: `/project/vm/docker-dev/src/build/edit/e3/Dockerfile`
- **Compose file**: `/project/vm/docker-dev/edit/e3/compose.yml`
- **Base image**: Alpine Linux 3.23
- **Symlink manager**: GNU Stow

### Important Notes

- Packages installed at runtime will **not persist** after container restart
- To persist packages, add them to the Dockerfile
- Go tools are installed to `/cache/go/bin` (may be a mounted volume)
- When suggesting package installations, remind about Dockerfile updates

## Structure

- `nvim/` - Neovim configuration (stow target: `~/.config/nvim`)
- `zsh/` - Zsh configuration
- `claude/` - Claude Code settings

## Stow Usage

```bash
# Link configs
stow --verbose nvim

# If conflicts with existing files, adopt them into repo
stow --adopt --verbose nvim
```

## Skill Authoring Guidelines

When creating or improving skills in `claude/.claude/skills/`, follow these
principles to maximize effectiveness within Claude Code's context constraints.

### 1. Phase Separation

Split complex skills into sequential phases with disk-based handoff.
Each phase runs with clean context and produces a discrete artifact.

```
Phase 1 (analyze)  → writes .claude/review.md
Phase 2 (plan)     → reads review.md → writes .claude/fix-plan.md
Phase 3 (execute)  → reads fix-plan.md → applies fixes
```

Why: Each phase gets full context budget. Prevents error cascading from
attention drift. Enables human review between phases.

Existing example: `code-review` → `/fix-plan` → `/code-review-fix`

### 2. Subagent Delegation

Dispatch subagents for data gathering and summarization. Return only
condensed results to the main thread.

- Use subagents for: file scanning, diff analysis, API calls, summarization
- Store subagent output on disk when results are large
- Main thread should orchestrate, not do heavy lifting

Why: Independent context windows prevent main thread pollution.
Enables parallel computation across multiple files/tasks.

### 3. Filesystem as Single Source of Truth

Persist all plans, progress, and intermediate artifacts to disk — never
rely on agent memory or built-in tasklist alone for cross-phase state.

- Write artifacts to `.claude/` directory
- Use markdown format for human readability
- Document expected input/output files in SKILL.md

### 4. Shell Over Loading

Prefer `glob`/`grep`/shell commands over reading entire files into context.
"80% of RAG can be replaced with glob/grep."

- Extract specific sections with targeted grep patterns
- Use shell pipelines to filter before loading
- Only read the lines you actually need

### 5. Script Delegation

For data transformation across many files, have the agent write and execute
a script, returning only the final result — not the raw data.

Example: Instead of reading 10 files to extract summaries, write a script
that extracts the relevant sections, combines them, and outputs a single
condensed result.

### 6. Self-Review Before Delivery

Include a retro step at the end of complex skills:
"Looking back, what did you do wrong or right? Starting over, what would
you change?" Then execute corrections while context is still fresh.

### 7. Skill Structure Checklist

```
skills/my-skill/
├── SKILL.md          # Required: frontmatter + step-by-step workflow
├── gather.sh         # Optional: shell script for data gathering
└── templates/        # Optional: output templates
```

SKILL.md must include:
- `name`, `description` in frontmatter
- Numbered steps (Step 1, Step 2...)
- Input prerequisites and output files documented
- Error handling and recovery guidance

## File Dependencies

When editing files in the left column, check if related files need updates:

| When you edit | Also check |
|---------------|------------|
| `skills/code-review/SKILL.md` | `commands/fix-plan.md`, `commands/code-review-fix.md` |
| `commands/fix-plan.md` | `commands/code-review-fix.md` |
