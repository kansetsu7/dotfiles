# Dotfiles Repository

## Environment

These dotfiles are used in **two environments**. Apply the environment-specific
notes only when they match the machine you're actually on.

- **Symlink manager**: GNU Stow (both environments)

### macOS (host)

- Local development machine — no container persistence concerns.
- npm global installs go to the default Homebrew/npm prefix; **no
  `--prefix` override needed**.

### Dockerized dev environment

- **Dockerized dev repo**: `/project/vm/docker-dev/`
- **Dockerfile**: `/project/vm/docker-dev/src/build/edit/e3/Dockerfile`
- **Compose file**: `/project/vm/docker-dev/edit/e3/compose.yml`
- **Base image**: Alpine Linux 3.23

#### Important Notes (container only)

- `/root` is a persistent named volume (`e3-home:/root` in `compose.yml`), so
  **anything written under `/root` survives container restarts** (e.g.
  `/root/npm-global`, `/root/.pi/agent/npm`). pi plugins installed via
  `pi install npm:<pkg>` persist automatically for this reason.
- Installs landing **outside** `/root` do **not** persist — e.g. `apk add`
  (`/usr/...`), or npm global installs that default to `/usr/local`. Add these
  to the Dockerfile to persist them.
- **npm global installs**: use `--prefix=/root/npm-global` so they land on the
  persistent `/root` volume instead of `/usr/local`
  (e.g. `npm install -g --prefix=/root/npm-global <pkg>`).
- Go tools are installed to `/cache/go/bin` (may be a mounted volume)
- When suggesting package installs that land outside `/root`, remind about
  Dockerfile updates

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

Existing example: `/cr-3-review` → `/cr-4-plan` → `/cr-5-fix`

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

Prefer built-in Glob/Grep tools over reading entire files into context.
"80% of RAG can be replaced with glob/grep."

- Extract specific sections with targeted Grep patterns
- Filter before loading; only read the lines you actually need

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

## Audits

Two audits, run in this order. Each layer's correctness is defined by the
layer beneath it, so auditing outside-in wastes effort on prose that may be
describing something already wrong.

| When | Run | Covers |
|---|---|---|
| After a pi upgrade | `/pi-audit` | Extensions vs the new pi: typecheck, tests, export diff, CHANGELOG. Includes the self-check for free. |
| Periodically, or after editing a skill/command | `/audit-instructions` | The instruction artifacts themselves: CLAUDE.md, AGENTS.md, skills, commands. |

Within either one, mechanical before judgment — never spend reasoning on what
`bash claude/.claude/skills/pi-extension-audit/audit.sh --self-check` can
decide. It is free, needs no pi and no network, and exits non-zero on drift.

The auditors are not self-applicable: `/pi-audit` checks TypeScript against
pi's `.d.ts`, so it can never audit its own markdown. Ground them instead in
the two external fixed points — the deterministic script output, and past
findings as regression cases (e.g. the `TextContent` gap fixed in `f23716e`,
an undocumented break that typecheck caught). Judge a change to an auditor by
whether it still catches those, not by re-reading the prose.

## File Dependencies

When editing files in the left column, check if related files need updates:

| When you edit | Also check |
|---------------|------------|
| `skills/cr-3-review/SKILL.md` | `commands/cr-4-plan.md`, `commands/cr-5-fix.md` |
| `skills/code-review-criteria/SKILL.md` (§10 Documentation) | `skills/cr-3-review/SKILL.md` (Step 5 documentation analysis), `skills/doc-suggestions/SKILL.md` (both ground doc rules in the project's `docs/README.md` + Diátaxis/ADR) |
| `commands/cr-4-plan.md` | `commands/cr-5-fix.md` |
| `skills/merge-insights/main.go` | `skills/doc-suggestions/SKILL.md` (shares the binary via its `--docs`/`--open` mode) |
| `scripts/detect-branch-base.sh` (output keys / `METHOD` values) | `commands/mr-summary.md` (reads the keys and branches on `METHOD`/`CONFIDENCE`) |
| `skills/merge-insights/main.go` (`classifyType` / classification regexes) | `skills/merge-insights/SKILL.md` (the verbatim "How MR types are classified" methodology block must match the code) |
| `pi/.pi/agent/extensions/*/index.ts` (behaviour or env vars) | the sibling `README.md` (behaviour table + config table) and `test.mjs`. Every extension has a `README.md`; `trim-tool-output` additionally keeps `DESIGN.md` for rationale, which is *not* the config reference. Verify mechanically: the `PI_*` names in `index.ts` must match those in `README.md` |
| `pi/.pi/agent/extensions/force-session-name/` (name/location) | `pi/.pi/agent/extensions/session-header/README.md` (links to it as its companion) |
| `pi/.pi/agent/extensions/openspec-skills/index.ts` (skills path / flag semantics) | `pi/.pi/agent/settings.json` (the `skills` blocklist entry) and `pi/.pi/agent/skills-optional/openspec/` (the directory it loads) |
| `pi/.pi/agent/settings.json` (`skills` array) | `pi/.pi/agent/extensions/openspec-skills/README.md` (documents the exclusion pattern and why `**` cannot cross `.claude`) |
| `pi/.pi/agent/extensions/rm-session/index.ts` (`NAME_HANDOFF` key/protocol) | `pi/.pi/agent/extensions/force-session-name/index.ts` (`takeNameHandoff` consumes the same `globalThis.__piPendingSessionName`), plus both READMEs |
| `skills/pi-extension-audit/audit.sh` (sections / flags / state keys) | `skills/pi-extension-audit/SKILL.md` (Step 1 documents each). Enforced mechanically — run `audit.sh --self-check`, which fails on drift |
| `skills/pi-extension-audit/SKILL.md` | `commands/pi-audit.md` (thin trigger that delegates to it); the `--self-check` link is enforced by the same check |
| `commands/audit-instructions.md` (mechanical checks in Step 1) | `skills/pi-extension-audit/audit.sh` (it invokes `--self-check`) |
| `pi-hist/main.go` (keybindings / flags) | `pi-hist/README.md` (the keys table and usage block must match) |
