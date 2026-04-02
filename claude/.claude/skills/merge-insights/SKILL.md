---
name: merge-insights
description: Analyze branches merged into master with summaries, hotspot analysis, rapid-fix detection, and time-aware trend insights. Adapts output depth based on short vs long time range.
---

# Merge Insights

Analyze branches merged into master within a given time range (default: this week).

## Arguments

- Optional: time range like "this week", "last 2 weeks", "since 2026-03-01", "last 3 months". Default: "1 week ago".

## Step 1: Run gather script

The gather script handles ALL data collection (git log, GitLab API, diff stats, hotspot counting, rapid-fix detection, weekly density, author summary) and outputs compact structured text.

```bash
bash ~/.claude/skills/merge-insights/gather.sh "<time_range>"
```

The script outputs sections delimited by `---MERGE---`, `---HOTSPOTS---`, `---RAPID-FIXES---`, `---WEEKLY-DENSITY---`, `---AUTHORS---`, and `---METADATA---`.

The `---METADATA---` section includes `mode: short` or `mode: long` (short = up to 14 days, long = over 14 days).

## Step 2: Read full diffs for notable MRs only

From the gather output, identify notable MRs:
- Large diffs (insertions > 200)
- Flagged in rapid-fix section
- Bug/patch branches touching hotspot files

For these only, read the full diff for business context:

```bash
git diff <merge_sha>^1...<merge_sha>
```

Do NOT read diffs for small/routine MRs — the commit messages from the gather output are sufficient.

## Step 3: Analyze and write report

Using the structured data from the script, the LLM's job is:

1. **Classify rapid fixes** as: rapid fix, follow-up fix, or cascade
2. **Group related MR clusters** by domain and assess: incremental rollout vs churn signal
3. **Summarize business logic** for each MR from commit messages + MR descriptions
4. **Write narrative highlights** — what matters to a tech lead

## Step 4: Output

### Part 1: Tech Lead Dashboard (always present)

```
## Key Highlights
- Largest/riskiest changes (by diff size or domain impact)
- New architectural patterns or infrastructure changes
- Compliance/regulatory related changes

## Rapid Fixes
| Bug/Patch MR | Likely caused by | Files in common | Days apart | Type |
|---|---|---|---|---|
(omit section if none detected)

## Hotspots
| File/Module | Touched by MRs | Concern |
|---|---|---|

## Related MR Clusters
- **<domain>**: !iid1, !iid2, !iid3 — <incremental rollout | churn signal | ...>

## Risk Signals
- Schema migrations: list any
- Data patches: list any
- Large diffs (>200 lines): list any

## Author Distribution
| Author | MRs | Areas |
|---|---|---|
```

### Part 2: Per-Branch Details

**Short mode** — full detail, grouped by date:

```
### N. `<branch-name>` (MR !<iid>)
**Author**: <name> | **Merged**: <date>
**Summary**: <1-2 sentence summary of what changed and why>
- Key change 1
- Key change 2
```

**Long mode** — compressed table, with full detail only for notable MRs:

```
## All MRs

| # | Date | Branch | MR | Author | Type | Summary |
|---|---|---|---|---|---|---|

## Notable MRs (detail)
(Only for MRs that are large >200 lines, risky, architectural, or flagged as rapid fixes)
```

### Part 3: Trend Insights (long mode only)

```
## Module Churn Rate
| Module | Total MRs | Features | Bugs/Patches | Bug Ratio |
|---|---|---|---|---|
(sorted by bug ratio descending — high ratio = potentially unstable)

## Bug Density Over Time
- Week 1: N features, M bugs
- Week 2: ...
(simple weekly breakdown to spot if bugs are increasing)

## Repeat Offender Files
| File | MR Count | Types |
|---|---|---|
(files appearing in 5+ MRs — candidates for refactoring)
```

## Guidelines

- Keep summaries concise — focus on *what* and *why*, not *how*
- Highlight business logic changes over mechanical/refactoring changes
- If an MR description contains business context (Trello links, user stories), include it
- Group related MRs together if they're part of the same feature
- For hotspot analysis, roll up to meaningful boundaries (model, concept, view directory) not individual files unless a single file is hit 3+ times
- For rapid-fix detection, only flag when there's actual file overlap — don't flag based on branch name similarity alone
- In long mode, read full diffs only for notable MRs (large, risky, or flagged). For the rest, commit messages from the script output are sufficient.
