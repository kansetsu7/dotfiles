---
name: code-review
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

### Step 1.5: Read Reviewer Feedback (if exists)

1. Check for `.claude/reviewer-feedback.md`
2. If exists:
   - Parse all reviewer items (they have structured format from `/process-reviewer-feedback`)
   - Store items for merging in Step 3
   - Reviewer items take priority for overlapping concerns
3. If not exists:
   - Continue with AI-only review (no reviewer feedback to merge)

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

### Step 3: Code Review & Merge

Apply the review criteria defined in `~/.claude/skills/code-review-criteria.md`.

**Merging with reviewer feedback** (if `.claude/reviewer-feedback.md` exists):

1. Start with all reviewer items (preserve exactly, mark as `👤 Reviewer`)
2. Perform AI review and add AI items (mark as `🤖 AI`)
3. For overlapping concerns (same file/area, similar issue):
   - Keep reviewer's version as primary
   - Add AI's additional context if valuable
   - Mark as `🤖 AI + 👤 Reviewer`
4. Number items sequentially within each priority section

Write the review directly to `.claude/code-review.md` using this structure:

```markdown
# Code Review Summary

**Branch:** <current-branch>
**Base:** <base-branch>
**Files Changed:** <count>
**Lines:** +<additions> / -<deletions>

## Taste Rating

🟢/🟡/🔴 **<Rating>** - <One line explanation>

## Decision Options

- **Accept**: Will fix this issue
- **Drop**: Issue is incorrect or not applicable (explain why)
- **Won't Fix**: Valid issue but intentionally not addressing (explain why)

## Approach Options

- **AI suggestion**: Use the recommended fix as-is
- **Alternative**: Your different approach (describe in Notes)

---

## Findings

### 🔴 Blocking (Must Fix)

#### 1. `<file_path:line>` - <brief title>
- **Source:** 🤖 AI / 👤 Reviewer / 🤖 AI + 👤 Reviewer
- **Issue:** <description of the problem>
- **Suggestion:** <recommended fix>
- **Status:** [ ] Pending
- **Decision:** _Accept / Drop / Won't Fix_
- **Approach:** _AI suggestion / Alternative_
- **Notes:** _[Your response, alternative approach details, or discussion points]_

---

### 🟡 Important (Should Fix)

#### 1. `<file_path:line>` - <brief title>
- **Source:** 🤖 AI / 👤 Reviewer / 🤖 AI + 👤 Reviewer
- **Issue:** <description>
- **Suggestion:** <recommended fix>
- **Status:** [ ] Pending
- **Decision:** _Accept / Drop / Won't Fix_
- **Approach:** _AI suggestion / Alternative_
- **Notes:** _[Your response, alternative approach details, or discussion points]_

---

### 🟢 Nit (Nice to Have)

#### 1. `<file_path:line>` - <brief title>
- **Source:** 🤖 AI / 👤 Reviewer / 🤖 AI + 👤 Reviewer
- **Issue:** <description>
- **Suggestion:** <recommended fix>
- **Status:** [ ] Pending
- **Decision:** _Accept / Drop / Won't Fix_
- **Approach:** _AI suggestion / Alternative_
- **Notes:** _[Your response, alternative approach details, or discussion points]_

---

### 💡 Suggestions

#### 1. `<file_path:line>` - <brief title>
- **Source:** 🤖 AI / 👤 Reviewer / 🤖 AI + 👤 Reviewer
- **Issue:** <description>
- **Suggestion:** <recommended fix>
- **Status:** [ ] Pending
- **Decision:** _Accept / Drop / Won't Fix_
- **Approach:** _AI suggestion / Alternative_
- **Notes:** _[Your response, alternative approach details, or discussion points]_

---

## Verdict

✅/❌ **<Verdict>** - <Summary explanation>

## Key Insight

<One sentence summary of the most important observation>
```

### Step 4: Commit Review

1. Stage the review file:
   ```
   git add .claude/code-review.md
   ```

2. Commit with message:
   ```
   Add code review for <current-branch>
   ```

## Output Files

- `.claude/code-review.md` - Code review with actionable findings
