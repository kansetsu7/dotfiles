---
triggers:
- /fix-plan
---

Analyze the code review and produce a comprehensive fix plan.

## Prerequisites

- `.claude/code-review.md` must exist with human decisions filled in

## Workflow

### Step 1: Read and Parse Review

1. Read `.claude/code-review.md`
2. Parse all items across all priority sections (Blocking, Important, Nit, Suggestions)
3. Categorize items by their Decision field:
   - **Accept** → will be planned
   - **Drop** → skip (note in plan)
   - **Won't Fix** → skip (note in plan)
   - No decision → flag as "Needs Decision"

### Step 2: Check Issue Relationships

If `## 🔗 Issue Relationships` section exists:

1. **Read Recommended Fix Order** - use as basis for plan ordering
2. **Note Cascading Fixes** - identify items that may be resolved by fixing another
3. **Note Conflicts** - flag items with conflicting solutions that need design decisions
4. **Note Same-Location Changes** - group items touching the same code area

### Step 3: Analyze Complexity & Dependencies

**Per-item investigation (parallelizable):**

If there are more than ~3 accepted items, dispatch one `Explore` subagent per
item in a single message (parallel fan-out). Each subagent should:

1. **Read the relevant code** around the file/line mentioned
2. **Assess complexity** and return a short report:
   - **Simple**: Straightforward change, no side effects (e.g., rename, add validation, fix typo)
   - **Moderate**: Requires understanding context, may affect related code
   - **Complex**: Requires design decision, touches multiple files, or has dependency on other items
3. Return: files touched, complexity rating, side-effect risks, any questions.
   Keep under ~150 words per item.

Use serial reads instead when there are only a few items, or when items
cluster in the same file (redundant reads).

**Cross-item synthesis (main thread only):**

After collecting per-item reports:

1. **Identify dependencies between items**:
   - Which items must be fixed before others?
   - Which items can be fixed independently in parallel?
   - Which items conflict and need a unified approach?
2. **Flag items needing design discussion**:
   - Items where the suggested fix may not be the best approach
   - Items with conflicting solutions from Issue Relationships
   - Items that would benefit from a broader refactor instead of point fixes

### Step 4: Write Fix Plan

Write the plan to `.claude/fix-plan.md`:

```markdown
# Fix Plan

**Source:** `.claude/code-review.md`
**Date:** <date>
**Accepted:** <count> | **Skipped:** <count> | **Needs Decision:** <count>

## Skipped Items

| # | Title | Decision | Reason |
|---|-------|----------|--------|
| X | brief title | Drop/Won't Fix | brief reason from Notes |

## Needs Decision

Items without a Decision that must be resolved before fixing:

- **#X** `<file:line>` - <title>: <what needs to be decided>

## Fix Groups

Items are organized into ordered groups. Complete each group before starting the next.

### Group 1: <theme/area>

**Why first:** <rationale for ordering>

#### #X `<file:line>` - <title>
- **Complexity:** Simple / Moderate / Complex
- **Approach:** Suggested fix / Alternative (from Notes)
- **Plan:** <concrete description of what to change>
- **Side effects:** <any risks or things to verify>
- **Resolves:** #Y, #Z (if cascading)
- **Todo:**
  - [ ] <specific task>
  - [ ] <another task if complex>
  - [ ] Verify: <side effects to check>

#### #Y `<file:line>` - <title>
...

### Group 2: <theme/area>

**Depends on:** Group 1 (if applicable)

...

## Design Decisions Needed

Items that are too complex for a simple fix and need discussion:

### #X `<file:line>` - <title>
- **Why:** <why this needs design discussion>
- **Options:**
  1. <option A> - pros/cons
  2. <option B> - pros/cons
- **Recommendation:** <your recommendation>
- **Blocked items:** #Y, #Z (items that depend on this decision)

## Execution Notes

- <any general notes about running tests, order concerns, etc.>
```

### Step 5: Report

Print a summary:

```
Fix plan written to `.claude/fix-plan.md`

<count> items planned in <count> groups
<count> items skipped (Drop/Won't Fix)
<count> items need decision
<count> items need design discussion

Run `/code-review-fix` to execute the plan.
```

## Important Notes

- Do NOT implement any fixes - this is planning only
- Read actual code to assess complexity, don't guess from the review alone
- Be honest about items that need design discussion rather than forcing a simple fix
- If an item's Notes contain questions, include those in the Design Decisions section
