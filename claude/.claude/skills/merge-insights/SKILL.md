---
name: merge-insights
description: Analyze branches merged into master with summaries, hotspot analysis, rapid-fix detection, review metrics, pipeline health, and time-aware trend insights. Adapts output depth based on short vs long time range.
---

# Merge Insights

Analyze branches merged into master within a given time range (default: this week).

## Arguments

- Optional: time range like "this week", "last 2 weeks", "since 2026-03-01", "last 3 months". Default: "1 week ago".

## Step 1: Build and run the gather script

The gather script handles ALL data collection (git log, GitLab API, diff stats, hotspot counting, rapid-fix detection, weekly density, author summary) and outputs compact structured text.

Each Bash call is a fresh shell — env vars and `cwd` do NOT persist between calls — so build and run are **two separate commands**, and the run command must decrypt the token inline.

**1. Build the binary** (cd into the skill dir is fine here — the build needs no token and no project context):

```bash
( cd ~/.claude/skills/merge-insights && go build -o /tmp/merge-insights . )
```

**2. Run it from the target project directory.** Do NOT `cd` anywhere in this command — the binary reads the GitLab project from `git remote get-url origin` in the current directory, which must be the repo you are analyzing (cd'ing into the skill dir resolves the wrong project). The read-only token is stored encrypted and must be decrypted inline in the same command. `>|` overrides zsh `noclobber` so the output file overwrites cleanly on re-runs:

```bash
eval "$(gpg --quiet --decrypt ~/.config/credentials/gitlab-readonly-token.env.gpg)" \
  && /tmp/merge-insights "<time_range>" >| /tmp/merge-insights-output.txt
```

Then grep/read the sections you need from `/tmp/merge-insights-output.txt` rather than loading the whole file (the output can run to >1000 lines).

The script outputs sections delimited by `---MERGE---`, `---HOTSPOTS---`, `---RAPID-FIXES---`, `---WEEKLY-DENSITY---`, `---AUTHORS---`, `---REVIEW-METRICS---`, `---SIZE-DISTRIBUTION---`, `---TEST-COVERAGE---`, `---DOC-CHANGES---`, `---PIPELINE-HEALTH---`, `---REVIEWERS---`, and `---METADATA---`.

Each `---MERGE---` record now includes: `time_to_merge_hours`, `cycle_time_hours`, `reviewers` (the MR assignee(s) — by team convention the reviewer is set as the assignee), `has_tests`, `has_docs`, `pipeline_runs`, `pipeline_failures`.

`---REVIEW-METRICS---` reports both `median_*_hours` and `avg_*_hours` for time-to-merge and cycle time — prefer the median. `---PIPELINE-HEALTH---` reports the per-MR final-pipeline metric (`mrs_with_pipelines`, `mrs_final_failed`, `final_failure_rate`) plus run-level context (`total_runs`, `total_failures`, `run_failure_rate`, counting all executions incl. retries).

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
5. **Interpret review metrics** — flag MRs with unusually long time-to-merge or cycle time; note if avg TTM suggests review bottlenecks
6. **Assess MR size discipline** — comment on size distribution shape (healthy = mostly xs/s/m; concerning = many l/xl)
7. **Evaluate test coverage signal** — highlight if ratio is low or if large feature MRs lack tests
8. **Flag pipeline concerns** — high failure rate suggests flaky tests or CI issues
9. **Note reviewer load imbalance** — if one reviewer handles disproportionate share, flag as bottleneck risk

## Step 4: Output

Write the final report as a **self-contained HTML file** to `/download/merge-insights-<slug>.html` where `<slug>` is a filesystem-safe version of the time range (e.g. "last 3 months" → `last-3-months`, "2026 Q1" → `2026-Q1`). Writing to `/download` (a mounted volume) keeps the report out of the analyzed project — do NOT leave a copy under the project's `.claude/`.

The report is a single self-contained HTML file (inline CSS from the template), so it renders correctly from `/download` with no other assets.

Build it from the template at `templates/report.html` (relative to this skill directory):

1. Read `templates/report.html` and keep its `<head>`/`<style>` **verbatim** — never inline different CSS or strip the stylesheet.
2. Replace the header placeholders: `{{TITLE}}` (the time range), `{{PROJECT}}`, `{{RANGE}}` (resolved `since`/`until` from `---METADATA---`), `{{TOTAL}}` (MR count), `{{MODE}}` (short/long), and `{{GENERATED}}` (today's date).
3. Replace `{{BODY}}` inside `<main>` with the report sections below, rendered as HTML using the template's classes.

After writing, tell the user the file path (`/download/merge-insights-<slug>.html`) and note it opens in a browser.

### HTML conventions (classes are defined in the template)

- **Section** — `<section><h2>Title <span class="count">(n)</span></h2> … </section>`
- **Table** — wrap every `<table>` in `<div class="table-wrap">…</div>`. For a numeric column, put `class="num"` on **both** its `<th>` and its `<td>` cells so the header right-aligns with its values (e.g. `<th class="num">` + `<td class="num">`); a `class="num"` header over plain `<td>` values, or vice-versa, will misalign. Text columns use plain `<th>`/`<td>`.
- **Type badge** — `<span class="badge badge--bug">bug</span>` (variants: `feature`, `bug`, `patch`, `refactor`, `doc`, `other`)
- **Concern tag** — `<span class="tag tag--danger">churn signal</span>` (variants: `ok`, `warn`, `danger`) — use `danger` for high risk, `warn` for caution, `ok` for healthy
- **Branch / file paths** — wrap in `<code>…</code>`
- **MR reference** — `<a href="WEB_URL">!IID</a>` when the MR's `web_url` is known, otherwise plain `!IID`
- Always HTML-escape `&`, `<`, `>` in commit messages, titles, and descriptions.

### Summary stat cards (top of `<main>`, always present)

Open the body with a `<div class="stat-grid">` of `<div class="stat-card">` tiles for at-a-glance metrics, e.g. Total MRs, Median time-to-merge, MRs with tests %, Final-pipeline failure rate, plus mode-relevant ones (e.g. Bug ratio in long mode). Card labels must not mislead: use "Median time-to-merge" (not "Avg"), "MRs with tests" (never "Test coverage" — this is not code-coverage %), and "Final-pipeline failure rate" (the per-MR `final_failure_rate`, not the run-level rate). "Bug ratio" counts type `bug` only (excludes `patch`); label it `Bug ratio (N/total)`. Add `is-warn` / `is-danger` to a card's class when its value crosses a concern threshold (e.g. final-pipeline failure rate >10% → `is-danger`, low test-touch rate → `is-warn`):

```html
<div class="stat-grid">
  <div class="stat-card"><div class="value">42</div><div class="label">Merged MRs</div></div>
  <div class="stat-card is-danger"><div class="value">18%</div><div class="label">Pipeline failures</div></div>
</div>
```

### Classification methodology note (always present)

Type badges (`bug`, `feature`, …) are assigned by the gather binary's `classifyType`, not the LLM, so the reader can't tell how a type was decided. Immediately **after** the stat cards, add a collapsed methodology block that documents the rule. The rule is fixed in the binary — paste this block **verbatim** (do not paraphrase; if `classifyType` in `main.go` changes, update this block to match):

```html
<details class="mr-fold">
  <summary>How MR types are classified <span class="count">(methodology)</span></summary>
  <div class="table-wrap">
    <table>
      <thead><tr><th class="num">#</th><th>Rule (checked in order)</th><th>Type</th></tr></thead>
      <tbody>
        <tr><td class="num">1</td><td>Branch name has a non-<code>feature</code> prefix — <code>bug/</code>, <code>patch/</code>, <code>refactor/</code>, <code>doc/</code>. <strong>Trusted by name.</strong></td><td><span class="badge badge--bug">bug</span> <span class="badge badge--patch">patch</span> <span class="badge badge--refactor">refactor</span> <span class="badge badge--doc">doc</span></td></tr>
        <tr><td class="num">2</td><td><code>feature/</code> or unprefixed branch whose commit messages or MR title match a fix signal — <code>fix</code>/<code>fixes</code>/<code>fixed</code>, <code>bug</code>, <code>revert</code>, <code>repair</code>, <code>correct</code>/<code>corrected</code>/<code>correction</code>, or <code>patch(ed) data|record|amount|balance</code>. <strong>Detected by content, not branch name.</strong></td><td><span class="badge badge--bug">bug</span></td></tr>
        <tr><td class="num">3</td><td><code>feature/</code> prefix, no fix signal.</td><td><span class="badge badge--feature">feature</span></td></tr>
        <tr><td class="num">4</td><td>No recognized prefix, no fix signal.</td><td><span class="badge badge--other">other</span></td></tr>
      </tbody>
    </table>
  </div>
</details>
```

### Part 1: Tech Lead Dashboard (always present)

One `<section>` per item below. Omit a section entirely where noted.

- **Key Highlights** — `<ul>`: largest/riskiest changes (by diff size or domain impact), new architectural/infra patterns, compliance/regulatory changes.
- **Rapid Fixes** — table: Bug/Patch MR · Likely caused by · Files in common · Days apart · Type. *Omit section if none detected.*
- **Hotspots** — table: File/Module · Touched by MRs · Concern (use a `tag`).
- **Related MR Clusters** — `<ul>`: `<strong>domain</strong>: !iid1, !iid2 — <tag>` assessing incremental rollout vs churn signal.
- **Risk Signals** — `<ul>`: schema migrations, data patches, large diffs (>200 lines) — list any.
- **Author Distribution** — table: Author · MRs · Areas.
- **Review Quality** — `<p>`: lead with the **median** as the typical value — Median time-to-merge Xh · Median cycle time Xh (from `median_ttm_hours`/`median_cycle_hours`) — then give the mean in parentheses noting it is skewed upward by long-lived branches (e.g. `median 6d (mean 15d, skewed by a few long-lived branches)`). Base any bottleneck flag on the **median, not the mean**. Then a short list of the slowest top-3 MRs by time-to-merge with a brief reason if apparent. Below the numbers, add a muted definitions line **verbatim** so the reader knows what each metric measures: `<p class="muted"><strong>Time-to-merge</strong>: hours from the MR being opened to merge (includes any draft/waiting time, not just active review). <strong>Cycle time</strong>: hours from the branch's first commit to merge (full development lifecycle, including coding before the MR was opened).</p>` *Omit section if no data.*
- **Reviewer Load** — table: Reviewer · MRs Reviewed · Concern. Flag (`tag--danger`) any reviewer handling >40% of MRs as bottleneck risk. *Omit section if no data.* (This uses the MR **assignee** field — by team convention the reviewer is set as the assignee, so assignee counts are a valid reviewer-load signal; this is intentional, not a bug.)
- **MR Size Distribution** — table with columns XS (<10) · S (10-50) · M (50-200) · L (200-500) · XL (500+); cells are MR counts and each MR is bucketed by **total lines changed (insertions + deletions)** from the `---SIZE-DISTRIBUTION---` section. Then a one-line commentary: healthy if mostly XS-M; flag if >30% are L/XL. Below the table add this muted definition line **verbatim**: `<p class="muted">Each MR is bucketed by total lines changed (insertions + deletions); cells are MR counts. Ranges are lines-changed thresholds (upper bound exclusive, e.g. S = 10–49).</p>`
- **Test Coverage Signal** — `<p>`: X/Y MRs (Z%) include test file changes; list feature MRs without tests by name. Word it as "MRs with tests", never "test coverage" (this is not code-coverage %). *Omit section if ratio is 100%.*
- **Pipeline Health** — `<p>`: lead with the per-MR final-pipeline metric — `mrs_final_failed`/`mrs_with_pipelines` MRs (final_failure_rate%) merged with a failing final pipeline; flag (`tag--danger`) only if that rate is high (>10%). Then mention run-level context in parentheses: total_runs N, run_failure_rate% across all executions incl. retries — and note a high run rate alone is normal iteration, not a red flag. *Omit section if no pipeline data.*
- **Documentation Changes** — `<p>`: X/Y MRs include doc/changelog changes. *Omit section if not meaningful (e.g. all bug fixes).*

### Part 2: Per-Branch Details

**Short mode** — full detail as cards grouped by date. Each date is a `<div class="date-group">` with an `<h3>` date heading containing the cards:

```html
<div class="date-group">
  <h3>2026-06-24</h3>
  <div class="mr-card">
    <h3><code>branch-name</code> <span class="badge badge--feature">feature</span> <a href="WEB_URL">!1234</a></h3>
    <div class="mr-meta">Author: Name · Merged: 2026-06-24</div>
    <p class="mr-summary">1-2 sentence summary of what changed and why.</p>
    <ul><li>Key change 1</li><li>Key change 2</li></ul>
  </div>
</div>
```

**Long mode** — the per-month "All MRs" tables act as lookup references that readers usually scroll past to reach "Notable MRs", so **collapse them by default**. Group the listing by calendar month (one table per month, columns: # · Date · Branch · MR · Author · Type · Summary), and wrap **each** month's table in a collapsed `<details class="mr-fold">` whose `<summary>` shows the month and MR count. Do **not** add the `open` attribute — the reader clicks to expand the month they need.

```html
<section>
  <h2>All MRs <span class="count">(by month — click to expand)</span></h2>
  <details class="mr-fold">
    <summary>2026-01 <span class="count">(12 MRs)</span></summary>
    <div class="table-wrap"><table> … rows … </table></div>
  </details>
  <details class="mr-fold">
    <summary>2026-02 <span class="count">(9 MRs)</span></summary>
    <div class="table-wrap"><table> … rows … </table></div>
  </details>
</section>
```

Then add a **separate, always-visible** "Notable MRs" `<section>` with detail cards (the `mr-card` pattern) — never collapsed — only for MRs that are large (>200 lines), risky, architectural, or flagged as rapid fixes. This is the section readers come for, so it sits below the folded month tables in full view.

### Part 3: Trend Insights (long mode only)

- **Module Churn Rate** — table: Module · Total MRs · Features · Bugs · Bug Ratio, sorted by bug ratio descending (high ratio = potentially unstable). "Bugs" and "Bug Ratio" count type `bug` only (exclude `patch`), consistent with the Bug ratio stat card.
- **Bug Density Over Time** — `<ul>` weekly breakdown (Week → N features, M bugs) to spot if bugs are increasing.
- **Repeat Offender Files** — table: File · MR Count · Types, for files appearing in 5+ MRs (refactoring candidates).

## Guidelines

- Keep summaries concise — focus on *what* and *why*, not *how*
- Highlight business logic changes over mechanical/refactoring changes
- If an MR description contains business context (Trello links, user stories), include it
- Group related MRs together if they're part of the same feature
- For hotspot analysis, roll up to meaningful boundaries (model, concept, view directory) not individual files unless a single file is hit 3+ times
- For rapid-fix detection, only flag when there's actual file overlap — don't flag based on branch name similarity alone
- In long mode, read full diffs only for notable MRs (large, risky, or flagged). For the rest, commit messages from the script output are sufficient.
