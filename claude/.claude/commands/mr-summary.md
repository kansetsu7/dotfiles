---
description: Generate a summary for the current branch changes
allowed-tools: Bash(git:*)
---

# MR Summary

Generate a merge request summary for the current branch.

**Base branch**: $ARGUMENTS

## Instructions

1. **Determine base branch**:
   - If argument provided, use it
   - Else if current branch ends with `-fork`, use branch name without `-fork`
     (e.g., `feature/abc-def-fork` → `feature/abc-def`)
   - Else default to `master`

2. **Analyze changes**:
   ```bash
   git log <base_branch>..HEAD --oneline
   git diff <base_branch>...HEAD --stat
   git diff <base_branch>...HEAD
   ```

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
