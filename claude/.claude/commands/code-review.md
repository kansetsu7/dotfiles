---
triggers:
- /code-review
---

Perform a comprehensive code review workflow on the current branch changes.

## Arguments

- `$ARGUMENTS`: Base branch to compare against (default: `master`)
  - Example: `/code-review main` or `/code-review develop`

## Workflow Steps

### Step 1: Get the Diff

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

### Step 2: Standard Code Review

Apply the standard code review perspective. Analyze the diff for:

**Security (Critical)**
- Injection vulnerabilities, authentication/authorization flaws
- Data exposure, input validation issues

**Correctness**
- Logic errors, race conditions, resource leaks, error handling

**Performance**
- N+1 queries, memory issues, blocking operations, inefficient algorithms

**Maintainability**
- Naming, complexity (>50 lines, >3 nesting), duplication, dead code

**Testing**
- Coverage, edge cases, mocking, assertions

**Ruby/Rails Patterns**
- N+1 queries, mass assignment, SQL injection via interpolation
- Missing freeze, unsafe send/constantize

**Output Format** using severity labels:
- 🔴 [blocking] - Must fix before merge
- 🟡 [important] - Should fix
- 🟢 [nit] - Nice to have
- 💡 [suggestion] - Alternative approach

Write the complete review to `.claude/code-review-standard.md` in the project root.

### Step 3: Roasted Code Review (Linus-style)

Apply the critical "good taste" review perspective. Analyze the diff for:

**Data Structure Analysis** (Highest Priority)
- Poor data structure choices creating unnecessary complexity
- Data copying/transformation that could be eliminated
- Unclear data ownership and flow
- Missing abstractions that would simplify logic

**Complexity and "Good Taste"**
- Functions with >3 levels of nesting (immediate red flag)
- Special cases that could be eliminated with better design
- Complex conditional logic obscuring the core algorithm
- Code that could be 3 lines instead of 10

**Pragmatic Problem Analysis**
- Is this solving a real problem or imaginary one?
- Does solution complexity match problem severity?
- Over-engineering for theoretical edge cases?

**Breaking Change Risk**
- Changes that could break existing APIs or behavior
- Modifications to public interfaces without deprecation
- Assumptions about backward compatibility

**Output Format:**
- Start with Taste Rating (Good/Acceptable/Needs Improvement)
- Group issues by: CRITICAL ISSUES, IMPROVEMENT OPPORTUNITIES, STYLE NOTES
- End with VERDICT (Worth merging / Needs rework) and KEY INSIGHT

Write the complete review to `.claude/code-review-roasted.md` in the project root.

### Step 4: Combined Summary

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

### Step 5: Commit Review Summary

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
