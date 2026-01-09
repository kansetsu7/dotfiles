---
triggers:
- /code-review
context: fork
agent: general-purpose
---

Perform a comprehensive code review workflow on the current branch changes.

## Arguments

- `$ARGUMENTS`: Base branch to compare against (default: `master`)
  - Example: `/code-review main` or `/code-review develop`

## Workflow Steps

### Step 1: Gather Business Context

1. **Read context file** (if exists):
   - Check for `.claude/context.md` in the project root
   - This file contains business logic, specs, and system design prepared by the developer
   - Use this context to verify implementation alignment

2. **Scan CLAUDE.md for relevant docs**:
   - Read the project's `CLAUDE.md` (documentation TOC)
   - Based on the changed files/features, identify relevant docs mentioned
   - Read those docs to understand related requirements and design decisions

3. **Keep this context in mind** for subsequent review steps to verify:
   - Implementation aligns with business requirements
   - Edge cases from specs are handled
   - Design decisions are followed

### Step 2: Get the Diff

1. Determine base branch: Use `$ARGUMENTS` if provided, otherwise `master`
2. Run `git diff <base-branch>...HEAD` to get all changes on this branch
3. If empty, try `git diff HEAD~1` for the latest commit
4. **If still no diff found, STOP and report error:**
   ```
   Error: No changes found to review.
   - No diff between current branch and <base-branch>
   - No changes in the latest commit
   Please ensure you have uncommitted or committed changes to review.
   ```

### Step 3: Standard Code Review

Apply the review criteria and output format defined in `~/.claude/skills/code-review-standard.md`.

Write the complete review to `.claude/code-review-standard.md` in the project root.

### Step 4: Roasted Code Review (Linus-style)

Apply the review criteria and output format defined in `~/.claude/skills/code-review-roasted.md`.

Write the complete review to `.claude/code-review-roasted.md` in the project root.

### Step 5: Combined Summary

Create `.claude/code-review.md` combining both reviews with this structure:

```markdown
# Code Review Summary

**Branch:** <current-branch>
**Base:** <base-branch>
**Files Changed:** <count>
**Lines:** +<additions> / -<deletions>

## Priority Level Definitions

| Priority | Criteria |
|----------|----------|
| **Critical** | Security vulnerabilities, data loss risk, breaking changes, crashes |
| **High** | Bugs, significant complexity, poor data structures, >3 nesting levels |
| **Medium** | Readability issues, missing error handling, code smells |
| **Low** | Style inconsistencies, minor optimizations, documentation gaps |

## Decision Options

- **Accept**: Will fix this issue
- **Drop**: Issue is incorrect or not applicable (explain why)
- **Won't Fix**: Valid issue but intentionally not addressing (explain why)

## Approach Options

- **AI suggestion**: Use the recommended fix as-is
- **Alternative**: Your different approach (describe in Notes)

---

## Priority Summary

### Critical (Must Fix)

#### 1. `<file_path:line>` - <brief title>
- **Issue:** <description of the problem>
- **Suggestion:** <recommended fix>
- **Status:** [ ] Pending
- **Decision:** _Accept / Drop / Won't Fix_
- **Approach:** _AI suggestion / Alternative_
- **Notes:** _[Your response, alternative approach details, or discussion points]_

---

### High (Should Fix)

#### 1. `<file_path:line>` - <brief title>
- **Issue:** <description>
- **Suggestion:** <recommended fix>
- **Status:** [ ] Pending
- **Decision:** _Accept / Drop / Won't Fix_
- **Approach:** _AI suggestion / Alternative_
- **Notes:** _[Your response, alternative approach details, or discussion points]_

---

### Medium (Consider Fixing)

#### 1. `<file_path:line>` - <brief title>
- **Issue:** <description>
- **Suggestion:** <recommended fix>
- **Status:** [ ] Pending
- **Decision:** _Accept / Drop / Won't Fix_
- **Approach:** _AI suggestion / Alternative_
- **Notes:** _[Your response, alternative approach details, or discussion points]_

---

### Low (Nice to Have)

#### 1. `<file_path:line>` - <brief title>
- **Issue:** <description>
- **Suggestion:** <recommended fix>
- **Status:** [ ] Pending
- **Decision:** _Accept / Drop / Won't Fix_
- **Approach:** _AI suggestion / Alternative_
- **Notes:** _[Your response, alternative approach details, or discussion points]_

---

## Standard Review

[Full content from code-review-standard.md]

---

## Critical Review (Linus-style)

[Full content from code-review-roasted.md]

---

## Action Items

Deduplicated, prioritized checklist combining both reviews:

### Must Address Before Merge
- [ ] Critical security issues
- [ ] Breaking changes
- [ ] Data structure problems

### Recommended Improvements
- [ ] Complexity reductions
- [ ] Readability improvements

### Optional Enhancements
- [ ] Style consistency
- [ ] Minor optimizations
```

### Step 6: Commit Review Summary

Commit only the combined summary and clean up intermediate files:

1. Remove intermediate files:
   ```
   rm -f .claude/code-review-standard.md .claude/code-review-roasted.md
   ```

2. Stage the summary file:
   ```
   git add .claude/code-review.md
   ```

3. Commit with message:
   ```
   Add code review for <current-branch>
   ```

## Output Files

All output files go in the **project's** `.claude/` folder (not global):
- `.claude/code-review-standard.md` - Standard review
- `.claude/code-review-roasted.md` - Critical review
- `.claude/code-review.md` - Combined summary with action items
