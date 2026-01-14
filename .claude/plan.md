# Code Review with Reviewer Feedback Integration

## Overview

Enhance the code review workflow to incorporate human reviewer feedback before AI review, allowing AI to discuss, structure, and merge human insights with its own analysis.

## Workflow

```
┌─────────────────────┐     ┌──────────────────────────┐     ┌─────────────────┐
│  Human writes       │     │  AI discusses &          │     │  AI reviews &   │
│  free-form notes    │ ──▶ │  structures              │ ──▶ │  combines       │
└─────────────────────┘     └──────────────────────────┘     └─────────────────┘
         │                            │                              │
         ▼                            ▼                              ▼
  reviewer-notes.md          reviewer-feedback.md            code-review.md
  (free-form input)          (structured, intermediate)      (final merged)
```

## Stage 1: `/init-reviewer-notes` Skill
**Goal**: Create template file for human reviewer
**Status**: Not Started

### Deliverable
- New skill file: `.claude/skills/init-reviewer-notes/SKILL.md`
- Creates `.claude/reviewer-notes.md` with template

### Template Content
```markdown
# Reviewer Notes

Write your feedback in any format. AI will convert to structured review items.

## Concerns

- [Add your concerns here - reference files/lines if known]

## Questions

- [Questions for the code author or for discussion]

## Context

- [Any background context that might help AI understand your feedback]
```

---

## Stage 2: `/process-reviewer-feedback` Skill
**Goal**: Convert free-form notes to structured feedback
**Status**: Not Started

### Deliverable
- New skill file: `.claude/skills/process-reviewer-feedback/SKILL.md`

### Workflow Steps

1. **Read Input**
   - Read `.claude/reviewer-notes.md`
   - If not found, error with helpful message

2. **Analyze & Identify Issues**
   - Parse free-form text into distinct concerns
   - Identify referenced files/lines (or mark as `TBD`)
   - Categorize by apparent priority

3. **Discussion Phase** (see Open Question below)
   - For unclear items, discuss with reviewer
   - Clarify file locations, severity, expected behavior

4. **Structure Output**
   - Convert each concern to structured format
   - Write to `.claude/reviewer-feedback.md`
   - Do NOT commit (intermediate output)

### Output Format
```markdown
# Reviewer Feedback

Processed from: reviewer-notes.md
Date: <timestamp>

## Items

### 🔴 Blocking

#### 1. `<file:line>` - <title>
- **Issue:** <description>
- **Suggestion:** <recommendation or "Reviewer to advise">

### 🟡 Important
...

### 🟢 Nit
...

### 💡 Suggestions
...

## Unresolved Questions

- [Any questions that couldn't be clarified]
```

---

## Stage 3: Update `/code-review` Skill
**Goal**: Merge reviewer feedback with AI review
**Status**: Not Started

### Changes to Existing Skill

#### Add Step 1.5: Read Reviewer Feedback

```markdown
### Step 1.5: Read Reviewer Feedback (if exists)

1. Check for `.claude/reviewer-feedback.md`
2. If exists:
   - Parse all reviewer items
   - Store for merging in Step 3
   - Reviewer items take priority for overlapping concerns
3. If not exists:
   - Continue with AI-only review
```

#### Update Step 3: Code Review Output

Add `Source:` field to each finding:

```markdown
#### 1. `app/controllers/api_controller.rb:45` - Missing nil check
- **Source:** 🤖 AI
- **Issue:** ...

#### 2. `app/services/authentication_service.rb:12` - Aggressive retry logic
- **Source:** 👤 Reviewer
- **Issue:** ...

#### 3. `app/models/user.rb:88` - SQL injection risk
- **Source:** 🤖 AI + 👤 Reviewer
- **Issue:** [Merged description noting both perspectives]
```

#### Merging Logic

1. Start with all reviewer items (preserve exactly)
2. Add AI items that don't overlap
3. For overlapping concerns (same file/area, similar issue):
   - Keep reviewer's version as primary
   - Add AI's additional context if valuable
   - Mark as `🤖 AI + 👤 Reviewer`

---

## Stage 4: Update `/code-review-fix` Skill
**Goal**: Handle source distinction in fix processing
**Status**: Not Started

### Changes

1. Summary report shows counts by source:
   ```markdown
   ### Fixed (5)
   - 🤖 AI: 3 items
   - 👤 Reviewer: 2 items
   ```

2. No other logic changes needed (Decision/Approach flow unchanged)

---

## Discussion Phase Design

**Decision**: Use inline interactive mode with `AskUserQuestion`.

### Behavior

1. **First pass**: AI attempts to resolve from context (read related files, infer locations)
2. **Unclear items**: Use `AskUserQuestion` to clarify with reviewer
3. **Custom answers**: Reviewer can select provided options OR enter custom response via "Other"

### Example Flow

```
AI: "You mentioned 'auth issue' - which file is this about?"
    Options:
    1. app/controllers/sessions_controller.rb
    2. app/controllers/concerns/authenticatable.rb
    3. app/services/jwt_service.rb
    [Other - type custom answer]

Reviewer: [selects option 2]
   - or -
Reviewer: [selects Other] → "It's in the new app/services/auth_service.rb I added"
```

### Question Types

| Clarification Need | Example Question |
|--------------------|------------------|
| File location | "Which file is this concern about?" |
| Severity | "How critical is this? (Blocking/Important/Nit)" |
| Expected behavior | "What should happen instead?" |
| Scope | "Should this apply to all endpoints or just public ones?" |

---

## Files Summary

| File | Purpose | Created By | Committed |
|------|---------|------------|-----------|
| `.claude/reviewer-notes.md` | Free-form input | Human (via template) | Optional |
| `.claude/reviewer-feedback.md` | Structured feedback | `/process-reviewer-feedback` | No |
| `.claude/code-review.md` | Final merged review | `/code-review` | Yes |

---

## Next Steps

1. ~~Decide on Discussion Phase design~~ → **Option A (Interactive)**
2. Implement Stage 1: `/init-reviewer-notes`
3. Implement Stage 2: `/process-reviewer-feedback`
4. Implement Stage 3: Update `/code-review`
5. Implement Stage 4: Update `/code-review-fix`
