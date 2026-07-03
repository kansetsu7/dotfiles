---
name: cr-2-feedback
description: Convert free-form reviewer notes to structured feedback format with interactive clarification.
---

# Process Reviewer Feedback

Convert human reviewer's free-form notes into structured feedback format, clarifying unclear items through discussion.

## Prerequisites

- `.claude/reviewer-notes.md` must exist with reviewer's feedback

## Workflow

### Step 1: Read Input

1. Read `.claude/reviewer-notes.md`
2. If not found, display error:
   ```
   Error: `.claude/reviewer-notes.md` not found.

   Run `/cr-1-notes` to create the template, then fill in your feedback.
   ```

### Step 2: Analyze & Identify Issues

1. Parse free-form text into distinct concerns
2. For each concern, identify:
   - Referenced file/line (or mark as "TBD" if not specified)
   - Apparent severity (infer from language: "critical", "should", "might", etc.)
   - Core issue description
   - Any suggested fix mentioned

### Step 3: Clarify Unclear Items

For each concern that lacks clarity, use `AskUserQuestion` to clarify.

**When to ask:**
- File location unknown or ambiguous
- Severity unclear
- Expected behavior not specified
- Scope of concern unclear

**Question types:**

1. **File location** (when file not specified):
   ```
   Question: "Which file is this concern about: '<concern summary>'?"
   Options: [List 2-4 likely files from codebase, based on concern context]
   ```

2. **Severity** (when unclear):
   ```
   Question: "How critical is: '<concern summary>'?"
   Options:
   - "Blocking - must fix before merge"
   - "Important - should fix soon"
   - "Nit - nice to have"
   - "Suggestion - consider for future"
   ```

3. **Expected behavior** (when fix unclear):
   ```
   Question: "What should happen instead for: '<concern summary>'?"
   Options: [2-4 reasonable alternatives based on context]
   ```

4. **Questions requiring investigation** (when reviewer asks a question):
   ```
   Question: "Reviewer asked: '<question>'. What would you like to do?"
   Options:
   - "Investigate now - search codebase and report findings"
   - "Skip - leave as open question"
   - "I know the answer" (use Other to provide)
   ```

**Important:**
- Reviewer can always select "Other" to provide custom answer
- Try to infer from context first before asking
- Batch related questions when possible (up to 4 per AskUserQuestion)

### Step 3a: Handle Investigation Requests

When user selects "Investigate now":

1. **Perform investigation:**
   - Search codebase for relevant code using Grep/Glob
   - Read related files to understand current behavior
   - Check for existing tests, comments, or documentation

2. **Report findings:**
   ```
   Investigation: <original question>

   Findings:
   - <key finding 1>
   - <key finding 2>
   - ...

   Relevant files:
   - `<file:line>` - <what it shows>
   ```

3. **Ask follow-up:**
   ```
   Question: "Based on findings, how should we handle: '<concern>'?"
   Options:
   - "Add as blocking issue"
   - "Add as important issue"
   - "Not an issue - remove from list"
   - "Need more investigation" (specify in Other)
   ```

4. **Record outcome** in structured feedback based on user's decision

### Step 4: Structure Output

Write structured feedback to `.claude/reviewer-feedback.md`:

```markdown
# Reviewer Feedback

Processed from: reviewer-notes.md
Date: <current date>

## Items

### 🔴 Blocking

#### 1. `<file:line>` - <title>
- **Issue:** <description>
- **Suggestion:** <recommendation or "Reviewer to advise">

### 🟡 Important

#### 1. `<file:line>` - <title>
- **Issue:** <description>
- **Suggestion:** <recommendation or "Reviewer to advise">

### 🟢 Nit

#### 1. `<file:line>` - <title>
- **Issue:** <description>
- **Suggestion:** <recommendation or "Reviewer to advise">

### 💡 Suggestions

#### 1. `<file:line>` - <title>
- **Issue:** <description>
- **Suggestion:** <recommendation or "Reviewer to advise">
```

**Notes:**
- Use `TBD` for file/line if still unknown after clarification
- Omit empty priority sections
- Do NOT commit this file (intermediate output)

### Step 5: Summary

Display summary to reviewer:

```markdown
## Processed Reviewer Feedback

**Items identified:** <count>
- 🔴 Blocking: <count>
- 🟡 Important: <count>
- 🟢 Nit: <count>
- 💡 Suggestions: <count>

**Output:** `.claude/reviewer-feedback.md`

**Next step:** Run `/cr-3-review` to generate AI review and merge with your feedback.
```

## Output Files

- `.claude/reviewer-feedback.md` - Structured feedback (NOT committed)
