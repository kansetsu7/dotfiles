---
description: Generate a summary for the current branch changes
argument-hint: "[base-branch-or-commit]"
allowed-tools: Bash(git:*), Bash(sh ~/.claude/scripts/detect-branch-base.sh:*)
---

# MR Summary

Generate a merge request summary for the current branch.

**Base override**: $ARGUMENTS

## Instructions

1. **Determine the base commit** — run the detector, passing `$ARGUMENTS`
   through (it is ignored when empty):

   ```bash
   sh ~/.claude/scripts/detect-branch-base.sh $ARGUMENTS
   ```

   It prints `BASE_COMMIT`, `BASE_REF`, `METHOD`, `COMMIT_COUNT`,
   `CONFIDENCE` and `NOTE`. It finds the real fork point by looking for
   commits reachable from `HEAD` but from no other branch, so it works for
   branches cut from any branch — not just `master` or the `-fork`
   convention. A branch cut from `feature/lilith-csrf` resolves to that
   branch's commit, even after both branches have moved on since.

   Handle the result before going further:
   - `CONFIDENCE=high` — proceed.
   - `CONFIDENCE=medium|low`, or `METHOD` is `on-default` / `none` — tell the
     user what was detected and what `NOTE` says, then ask for an explicit
     base rather than summarizing a range that may be wrong.
   - `COMMIT_COUNT=0` — there is nothing to summarize; say so and stop.

2. **Analyze changes** using `BASE_COMMIT` (a commit SHA, not a branch name):

   ```bash
   git log <BASE_COMMIT>..HEAD --oneline
   git diff <BASE_COMMIT>...HEAD --stat
   git diff <BASE_COMMIT>...HEAD
   ```

   For `METHOD=root`, `BASE_COMMIT` is empty — the branch reaches a root
   commit, so summarize the whole history (`git log HEAD`, `git show HEAD`).

3. **Generate summary** with:
   - Focus on **why** the changes are needed, not what changed
   - Explain the problem being solved or motivation
   - Breaking changes (if any)
   - Testing notes

4. **Format as MR body**:
   ```markdown
   ## Summary
   [1-3 bullet points explaining why these changes are needed]

   ## Changes
   - [List of significant changes with rationale]

   ## Test Plan
   - [ ] [Testing checklist items]
   ```

   When `BASE_REF` is set and is not the default branch, note it above the
   summary so the reader knows what the MR should target:
   `**Target branch:** <BASE_REF>`
