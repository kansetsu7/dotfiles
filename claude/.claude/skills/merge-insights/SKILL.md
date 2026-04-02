---
name: merge-insights
description: Analyze branches merged into master with summaries, hotspot analysis, rapid-fix detection, and time-aware trend insights. Adapts output depth based on short vs long time range.
---

# Merge Insights

Analyze branches merged into master within a given time range (default: this week).

## Arguments

- Optional: time range like "this week", "last 2 weeks", "since 2026-03-01", "last 3 months". Default: "1 week ago".

## Step 1: Determine Time Range and Mode

Parse the user's time range argument and classify:
- **Short mode** (up to 2 weeks): detailed per-branch summaries, rapid-fix detection
- **Long mode** (over 2 weeks): trend analysis, compressed per-branch output

## Step 2: Find Merge Commits

```bash
git fetch origin master
git log origin/master --merges --first-parent --since="<date>" --format="%H %s"
```

Parse branch names from commit messages (format: `Merge branch '<branch>' into 'master'`).
Also extract branch type prefix: `feature/`, `bug/`, `patch/`, `hotfix/`, etc.

## Step 3: Get MR Details from GitLab

For each merge commit, find the corresponding MR to get the title and description (which often contains business context).

Use the `gitlab` skill's conventions for API access:
- Token: `$GITLAB_READONLY_TOKEN`
- Base URL: `https://gitlab.abagile.com/api/v4`
- Detect project from git remote and resolve to numeric ID

```bash
# Search for MR by source branch
curl -s --header "PRIVATE-TOKEN: $GITLAB_READONLY_TOKEN" \
  "https://gitlab.abagile.com/api/v4/projects/$PROJECT_ID/merge_requests?state=merged&source_branch=<branch>&per_page=1" \
  | jq '.[0] | {iid, title, description, author: .author.name, merged_at, web_url}'
```

## Step 4: Get Diff Summary

For each merge commit, get the diff stat and key changes:

```bash
# Diff stat from merge commit
git diff --stat <merge_sha>^1...<merge_sha>

# Changed files list (for hotspot/rapid-fix analysis)
git diff --name-only <merge_sha>^1...<merge_sha>

# For deeper understanding, read the actual diff (short mode only, or large/risky MRs in long mode)
git diff <merge_sha>^1...<merge_sha>
```

## Step 5: Hotspot Analysis

Collect all changed file paths across MRs.

- Find files touched by 2+ MRs (hotspots)
- Roll up to directory/module level for broader patterns (e.g. `app/models/payment_arrangement*`)
- In **long mode**, rank modules by total MR count to surface chronic hotspots

## Step 6: Rapid-Fix Detection

Identify cases where a `bug/*`, `patch/*`, or `hotfix/*` branch modifies files that were also touched by another MR merged within the prior 7 days.

For each bug/patch MR:
1. Get its changed file set
2. Check all other MRs merged within the 7 days before it
3. If file overlap exists, flag as a potential rapid fix

Classification:
- **Rapid fix**: bug/patch MR touches same files as a feature MR merged < 7 days prior — the feature likely introduced the issue
- **Follow-up fix**: bug/patch by the same author on their own recent MR — self-correction
- **Cascade**: multiple bug/patch MRs on the same files in quick succession — area is unstable

## Step 7: Cross-cutting Concerns

Group MRs that touch the same domain or are clearly related:
- Same model/module modified by different MRs
- Same author working on sequential branches in the same area
- Branch names sharing a prefix (e.g. multiple `topup-termination` branches)

Flag whether related MRs look like:
- **Incremental rollout** — planned sequence of changes
- **Churn signal** — same area getting repeated fixes, possibly unstable

## Step 8: Output

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

**Long mode** — compressed table, with full detail only for large/risky MRs:

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
- Use the git diff to understand changes, but don't dump raw diffs in output
- Process MRs in parallel (batch API calls) when possible for speed
- For hotspot analysis, roll up to meaningful boundaries (model, concept, view directory) not individual files unless a single file is hit 3+ times
- For rapid-fix detection, only flag when there's actual file overlap — don't flag based on branch name similarity alone
- In long mode, read full diffs only for notable MRs (large, risky, or flagged). For the rest, diff stat + commit messages are sufficient.
