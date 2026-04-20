# Development Guidelines

## Process

### 1. Planning & Staging

Break complex work into 3-5 stages. Document in `.claude/plan.md`:

```markdown
## Stage N: [Name]
**Goal**: [Specific deliverable]
**Success Criteria**: [Testable outcomes]
**Tests**: [Specific test cases]
**Status**: [Not Started|In Progress|Complete]
```
- Update status as you progress
- Remove file when all stages are done

### 2. When Stuck (After 3 Attempts)

**CRITICAL**: Maximum 3 attempts per issue, then STOP.
Use `/unstuck` skill for structured problem-solving workflow.

## Shell Tool Usage

When Bash is genuinely needed (shell-only operations), prefer `fd`, `rg`,
`ast-grep`, `jq`, `yq`. Use built-in Glob/Grep/Read tools otherwise.

## Testing

Use agents to run tests.

## Knowledge Capture

Use the `knowledge-capture` skill when detecting domain knowledge:
- User prompt contains "Background:" or context sections
- User explains domain concepts or business rules
- User corrects your understanding of the system
- After exploring code and discovering undocumented patterns
- Explicit: user says "remember this", "note this", or `/learn`

Knowledge is captured to `~/.claude/knowledge/` organized by domain.

## Plan Mode
- Make the plan extremely concise. Sacrifice grammar for the sake of concision.
- At the end of each plan, give me a list of unresolved questions to answer, if any.

## Commit Style

Default to the 'Background', 'Problem', 'Approach' structure.
Use a concise subject line only for truly trivial changes (typos, formatting,
dependency bumps) where there is no meaningful context to explain.

If there is a *reason* behind the change — a bug, a prior commit that set up
the situation, a subtlety in how the code works — use the structural style,
regardless of diff size.

Use backticks to quote code and file paths.

### Background
- Describes current system behavior, business logic, and technical context
- Explains previous changes or MRs that led to the current state
- Provides setup information about how existing code works
- May include references to external resources (Trello cards, Slack discussions)

### Problem
- Clearly states specific issues, bugs, or inconsistencies discovered
- Includes user reports, specific cases, or plan numbers when relevant
- Describes gaps in implementation, missing validations, or logic flaws
- Points out redundancies, scattered logic, or maintenance concerns

### Approach
- Lists specific technical changes being made (use bullet points for multiple items)
- Explains refactoring decisions and their rationale
- Documents test updates and validation changes
- May include future TODOs or follow-up work when relevant
- When multiple problems exist, clearly indicate which problem each change addresses

### Template

```
Subject line (imperative mood, 50 chars max)

Background
==========
- Current system behavior/setup
- Previous changes that led to this
- Business context or references

Problem
==========
- Specific issue discovered
- User reports or cases
- What's broken or inconsistent

Approach
==========
- Technical changes made
- Test updates
- Future TODOs if needed
```

### Example

```
Fix need_credit_card_charge? logic

Background
==========
- When create PA, we use PaymentArrangement::SurrenderRefundInfo to
  calculate base_expected_payment_amount and save into PA
- MR!10554 refactored the `need_credit_card_charge?` method

Problem
==========
MR!10554 doesn't handle scenario on new PA which has nil `created_at`,
resulting in `need_credit_card_charge?` always returning false in HK/CK.
This causes different 'expected payment amount' calculations between
index and show pages.

Approach
==========
- Update condition to make nil `created_at` return true
- Add test for this scenario
- Ensures consistent payment amount display across pages
```
