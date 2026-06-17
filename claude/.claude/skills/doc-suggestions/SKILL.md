---
name: doc-suggestions
description: For each open MR (or merged MRs in a time range), suggest what documentation the MR should add — categorized by the Diátaxis framework (Tutorial / How-to / Reference / Explanation) — grounded in the project's docs/README.md. Explicitly flags MRs that warrant an ADR but lack one.
---

# Doc Suggestions

Scan merge requests and, per MR, recommend the documentation it should add. Each
suggestion is grounded in the project's own `docs/README.md` (its doc structure +
conventions) and categorized by **Diátaxis**. MRs that introduce significant
decisions but lack an **ADR** are called out explicitly.

The data-gathering reuses the `merge-insights` Go binary in its `--docs` mode.

## Arguments

- `open` (default) — every currently-open MR in the project.
- A time range — analyze MRs **merged** in that range. Same grammar as
  `merge-insights`: `"last 2 weeks"`, `"since 2026-03-01"`, `"2026-05-01 to 2026-05-31"`.

If no argument is given, ask the user: open MRs, or a merged range?

## Step 1: Checkout latest master

The report must reflect the latest `docs/README.md` and ADR layout on master.

1. Run `git status --porcelain`. **If the working tree is dirty, STOP** and tell the
   user to commit/stash first — do not stash or discard their work.
2. `git fetch origin && git checkout master && git pull --ff-only`.

(Open-MR branches are NOT checked out — their diffs come from the GitLab API in Step 5.)

## Step 2: Build and run the gather binary

Same pattern and caveats as `merge-insights`: each Bash call is a fresh shell, so
**build and run are separate commands**, the run decrypts the token inline, and `>|`
overrides zsh `noclobber`.

**1. Build** (cd into the skill dir is fine — the build needs no token or project context):

```bash
( cd ~/.claude/skills/merge-insights && go build -o /tmp/merge-insights . )
```

**2. Run from the target project directory.** Do NOT `cd` anywhere in this command —
the binary resolves the GitLab project from `git remote get-url origin` in the current
directory, which must be the repo you are analyzing.

```bash
# open MRs:
eval "$(gpg --quiet --decrypt ~/.config/credentials/gitlab-readonly-token.env.gpg)" \
  && /tmp/merge-insights --docs --open >| /tmp/doc-suggestions-gather.txt

# OR merged MRs in a range:
eval "$(gpg --quiet --decrypt ~/.config/credentials/gitlab-readonly-token.env.gpg)" \
  && /tmp/merge-insights --docs "<range>" >| /tmp/doc-suggestions-gather.txt
```

The output is a stream of `---MERGE---` records followed by `---METADATA---`.
Each record has: `sha` (merged only), `date`, `branch`, `type`, `mr_iid`, `mr_title`,
`author`, `web_url`, `has_docs`, `files_changed`, a `changed_files:` block (one path per
line), and `mr_description_excerpt`. The metadata footer has `mode` (`docs-open` /
`docs-merged`), `total`, and `project: <path> (ID: <n>)` — **note the numeric project ID;
the open-MR diff fetch in Step 5 needs it.**

Grep records from the file rather than loading the whole thing. **Note the `total`**;
analyze all MRs (no silent truncation). If `total` is large (say >25), tell the user the
count before fanning out so they know the scope of work.

## Step 3: Derive the documentation policy from docs/README.md

Read `docs/README.md` (and skim the `docs/` tree with Glob to learn its real layout).
From it, build a compact **doc policy** capturing, for THIS project:

- How docs are organized and **where each Diátaxis type lives** (actual paths, e.g.
  `docs/tutorials/`, `docs/how-to/`, `docs/reference/`, `docs/explanation/` — or whatever
  the project actually uses; map the project's structure onto Diátaxis).
- Any stated rules for **when documentation is required** (which kinds of change must be
  documented).
- **Where ADRs live** (e.g. `docs/adr/`, `docs/decisions/`, a wiki) and **when one is
  expected** per the project's conventions.

Write the policy to `/tmp/doc-suggestions-policy.md` so analysis subagents share one
consistent ruleset.

If `docs/README.md` is absent, fall back to the generic Diátaxis definitions in the
Reference appendix below, suggest a sensible `docs/` location, and note in the report that
no project doc policy was found.

## Step 4: Per-MR analysis (subagents)

For each MR record, dispatch a **general-purpose** subagent (launch in parallel batches —
several Agent calls in a single message; keep concurrency reasonable, ~8 at a time). Give
each subagent:

- The MR's gather record (iid, branch, sha, web_url, changed_files, description, type).
- The project ID and mode (`docs-open` / `docs-merged`) from metadata.
- The **absolute path of the project repo** (subagents don't inherit cwd — they need it
  to run `git -C <repo> diff ...` in merged mode).
- The path `/tmp/doc-suggestions-policy.md` to read first.
- The instruction to write its result to `/tmp/doc-suggestions/mr-<iid>.md` and return
  only a one-line status.

Each subagent must:

1. Read `/tmp/doc-suggestions-policy.md`.
2. Read the diff:
   - **merged** (`docs-merged`, record has `sha`): `git -C <repo> diff <sha>^1...<sha>`.
   - **open** (`docs-open`, no `sha`): use MCP `mcp__gitlab__get_merge_request_diffs`
     with the project ID and `merge_request_iid`. (Load it via ToolSearch first:
     `select:mcp__gitlab__get_merge_request_diffs`.)
3. Decide, grounded in the policy:
   - **Docs needed?** yes / no — judge by what the change introduces or alters
     (new feature/endpoint/config/CLI/workflow/behavior change), not by diff size.
     Mechanical refactors, test-only, or dependency bumps usually need none.
   - **Diátaxis category(ies)** — which type(s) of doc, *what* to write (1–2 lines), and
     *where* it should live per the project's actual structure.
   - **ADR assessment** — does the change warrant an ADR (architectural / cross-cutting /
     new infra or service / data-model or security/compliance decision / tech choice /
     breaking change)? Is one **already present** (the MR touches the ADR dir, or links an
     ADR in its description)? Classify as: `not needed` / `needed + missing` / `present`.
   - Note if the MR is a **Draft** (title starts `Draft:`) and whether it **already
     changed docs** (`has_docs: yes`).

Result file format (`/tmp/doc-suggestions/mr-<iid>.md`):

```
iid: <iid>
type: <feature|bug|...>
docs_needed: <yes|no>
diataxis: <Tutorial|How-to|Reference|Explanation|none>  (may list several)
adr: <not needed|needed+missing|present>
draft: <yes|no>
what_changed: <1–2 line summary>
suggestion: <what doc to write and where, per policy — or "none">
adr_reason: <why an ADR is/ isn't warranted; suggested location if missing>
```

## Step 5: Aggregate and write the report

Read all `/tmp/doc-suggestions/mr-*.md` files and assemble the report. Write to
`.claude/doc-suggestions-<slug>.md` where `<slug>` is `open` for open mode, or a
filesystem-safe version of the range (e.g. `last 2 weeks` → `last-2-weeks`,
`2026-05-01 to 2026-05-31` → `2026-05-01-to-2026-05-31`). Then tell the user the path.

```markdown
# Doc Suggestions — <open MRs | merged: <range>>
**Project:** <path> | **Analyzed:** <N> MRs | **Date:** <today>

## Summary
| MR | Type | Docs needed | Diátaxis | ADR | Title |
|----|------|-------------|----------|-----|-------|
| !<iid> | feature | yes | How-to, Reference | needed+missing | ... |

## ⚠️ Missing ADRs
MRs that warrant an ADR but don't have one — write these first.
- **!<iid>** <title> ([MR](<web_url>)) — <why an ADR is warranted; suggested location>
(omit section if none)

## Per-MR Detail
### !<iid> `<branch>` — <title>   ([MR](<web_url>))
- **What changed:** <1–2 lines>
- **Docs:** <Diátaxis category> — <what to write> → `<target path per policy>`
  (or "No docs needed — <brief reason>")
- **ADR:** <not needed | ⚠️ needed + missing (suggest `<path>`) | present>
(group/sort so MRs needing docs or ADRs come first; keep "no docs needed" terse)
```

## Reference: Diátaxis categories

Use these definitions when the project's `docs/README.md` doesn't map cleanly:

- **Tutorial** — learning-oriented. A guided lesson that takes a newcomer through doing
  something for the first time. (New onboarding-worthy feature/flow.)
- **How-to guide** — task-oriented. Steps to accomplish a specific real-world task.
  (New operational procedure, configuration, or "how do I X" capability.)
- **Reference** — information-oriented. Dry, factual description: API endpoints, config
  options, schema, CLI flags, env vars. (New/changed interface surface.)
- **Explanation** — understanding-oriented. Background and rationale; the *why*.
  (Design context, trade-offs, concepts.)

**ADR (Architecture Decision Record)** is a focused kind of Explanation that records a
significant decision, its context, and consequences. Suggest one when an MR makes a
choice future maintainers would need the reasoning for: architecture, cross-cutting
patterns, new infrastructure/services, data-model design, security/compliance approach,
notable technology choices, or breaking changes.

## Guidelines

- Ground every suggestion in `docs/README.md`; point to real target paths, not generic ones.
- Judge doc-worthiness by what the change *introduces or alters*, not by diff size.
- Don't over-recommend: refactors, test-only changes, and dependency bumps usually need no docs.
- One MR can warrant more than one doc type (e.g. Reference + How-to).
- The Missing-ADRs section is mandatory output (even if empty, state "none").
- Drafts are still analyzed; just mark them so the user knows they're in flight.

## Output files

- `/tmp/doc-suggestions-gather.txt` — raw gather output (intermediate).
- `/tmp/doc-suggestions-policy.md` — derived doc policy (intermediate, subagent handoff).
- `/tmp/doc-suggestions/mr-<iid>.md` — per-MR analysis (intermediate).
- `.claude/doc-suggestions-<slug>.md` — final report.
