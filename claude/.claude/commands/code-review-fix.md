---
triggers:
- /code-review-fix
---

Process the code review summary and implement fixes for accepted items.

## Prerequisites

- `.claude/code-review.md` must exist with human decisions filled in

## Workflow

### Step 1: Read and Parse Review

1. Read `.claude/code-review.md`
2. Parse all items across all priority sections (Critical, High, Medium, Low)
3. Categorize items by their Decision field

### Step 2: Process Accepted Items

For each item where **Decision** is "Accept" and **Status** is `[ ]` (unchecked):

1. **Check Approach field:**
   - If "AI suggestion" → implement the suggestion from the **Suggestion** field
   - If "Alternative" → implement the approach described in **Notes**

2. **Check Notes field for questions:**
   - If Notes contain questions (indicated by `?`) → answer the question first, explain your reasoning, then proceed with implementation
   - If Notes describe an alternative approach → implement that instead of the original suggestion

3. **Implement the fix:**
   - Make the code change
   - Verify the change compiles/passes syntax check
   - Mark the item Status as `[x]` in `.claude/code-review.md`

4. **Report what was done:**
   ```
   Fixed: `<file_path:line>` - <brief title>
   Approach: <AI suggestion | Alternative: brief description>
   ```

### Step 3: Skip Non-Accepted Items

- **Drop**: Skip silently (issue was incorrect or not applicable)
- **Won't Fix**: Skip silently (intentionally not addressing)
- Already checked `[x]`: Skip (already fixed)

### Step 4: Summary Report

After processing all items, provide a summary:

```markdown
## Code Review Fix Summary

### Fixed (<count>)
- `<file_path:line>` - <title> (AI suggestion)
- `<file_path:line>` - <title> (Alternative)

### Skipped - Drop (<count>)
- `<file_path:line>` - <title>

### Skipped - Won't Fix (<count>)
- `<file_path:line>` - <title>

### Already Done (<count>)
- `<file_path:line>` - <title>

### Remaining (<count>)
- `<file_path:line>` - <title> (no decision yet)
```

## Important Notes

- Process items in priority order: Critical → High → Medium → Low
- If an alternative approach in Notes is unclear, ask for clarification before implementing
- If a fix would conflict with another accepted item, flag it and ask how to proceed
- Run project tests after all fixes if a test command is available
