# Development Guidelines

## Process

### 1. Planning & Staging

Break complex work into stages tracked in `.claude/plan.md` (goal, success
criteria, tests, status per stage). Update status as you progress; remove the
file when all stages are done.

### 2. When Stuck (After 3 Attempts)

**CRITICAL**: Maximum 3 attempts per issue, then STOP.
Use `/unstuck` skill for structured problem-solving workflow.

## Shell Tool Usage

When Bash is needed for shell-only ops, prefer `fd`, `rg`, `ast-grep`, `jq`, `yq`.

## Testing

Use agents to run tests.

## Knowledge Capture

Use the `knowledge-capture` skill when domain knowledge surfaces (or on
`/learn`); captured to `~/.claude/knowledge/` organized by domain.

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

- **Background** — current behavior/setup, prior changes (MRs) that led here,
  business context or references (Trello, Slack).
- **Problem** — the specific issue, bug, or inconsistency; user reports, cases,
  or plan numbers; gaps, logic flaws, redundancies.
- **Approach** — the technical changes (bullets), refactoring rationale, test
  updates, future TODOs; when multiple problems, tie each change to its problem.

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
