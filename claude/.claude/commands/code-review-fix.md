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
2. Parse all items across all priority sections (Blocking, Important, Nit, Suggestions)
3. Categorize items by their Decision field

### Step 1.5: Check Issue Relationships

If `## 🔗 Issue Relationships` section exists:

1. **Read Recommended Fix Order** - process items in this order instead of default priority order
2. **Note Cascading Fixes** - after fixing #X, if it resolves #Y, mark #Y as `[x]` with note "Resolved by #X"
3. **Note Conflicts** - before implementing conflicting items, follow the recommended resolution

### Step 2: Process Accepted Items

For each item where **Decision** is "Accept" and **Status** is `[ ]` (unchecked):

1. **Check Approach field:**
   - If "AI suggestion" → implement the suggestion from the **Suggestion** field
   - If "Alternative" → implement the approach described in **Notes**

2. **Check Notes field for questions:**
   - If Notes contain questions (indicated by `?`) → answer the question first, explain your reasoning, then proceed with implementation
   - If Notes describe an alternative approach → implement that instead of the original suggestion

3. **Implement and commit the fix:**
   - Make the code change
   - Verify the change compiles/passes syntax check
   - Mark the item Status as `[x]` in `.claude/code-review.md`
   - Stage the changed files (including updated `.claude/code-review.md`)
   - Commit with a message describing the changes made

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
- 🤖 AI: <count> items
- 👤 Reviewer: <count> items
- 🤖 AI + 👤 Reviewer: <count> items

**Details:**
- `<file_path:line>` - <title> (AI suggestion) [🤖 AI]
- `<file_path:line>` - <title> (Alternative) [👤 Reviewer]

### Resolved by Cascading Fix (<count>)
- `<file_path:line>` - <title> (resolved by #X) [<source>]

### Skipped - Drop (<count>)
- `<file_path:line>` - <title> [<source>]

### Skipped - Won't Fix (<count>)
- `<file_path:line>` - <title> [<source>]

### Already Done (<count>)
- `<file_path:line>` - <title> [<source>]

### Remaining (<count>)
- `<file_path:line>` - <title> (no decision yet) [<source>]
```

## Important Notes

- **Fix order priority**: Use "Recommended Fix Order" from Issue Relationships if present, otherwise default to 🔴 Blocking → 🟡 Important → 🟢 Nit → 💡 Suggestions
- If an alternative approach in Notes is unclear, ask for clarification before implementing
- **Conflicts**: Check Issue Relationships for conflict guidance before implementing; if not documented, flag and ask how to proceed
- **Cascading fixes**: After each fix, check if it resolves other items per Issue Relationships
- Run project tests after all fixes if a test command is available
