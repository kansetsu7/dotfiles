# Agent Guidelines

Global instructions for the pi coding agent. pi's harness is deliberately
thin (tools: `read`, `bash`, `edit`, `write`, `glob`, `grep`; no subagents,
no built-in task tracker), so behaviors are stated explicitly here rather
than assumed.

## Process

### 1. Planning & staging

For non-trivial work, track stages in a `plan.md` (goal, success criteria,
tests, status per stage). Update status as you progress; delete the file when
all stages are done. This file IS the task list — pi has no built-in tracker.

### 2. When stuck (after 3 attempts)

**CRITICAL**: Maximum 3 attempts per issue, then STOP. Load the `unstuck`
skill for a structured problem-solving workflow instead of retrying blindly.

## Working defaults

- **Never commit or push unless explicitly asked.** Make the edits and stop.
- **Match surrounding conventions** — mimic existing style, naming, and
  structure over imposing your own.
- **Verify before declaring done** — run the relevant tests / lint / build via
  `bash` and confirm they pass.
- **No unsolicited comments** — don't add explanatory code comments unless
  asked or the code is genuinely non-obvious.
- **Prefer `fd`, `rg`, `ast-grep`, `jq`, `yq`** for shell-only operations.
- **In the dockerized dev env only**, use `--prefix=/root/npm-global` for npm
  global installs so they persist on the `/root` volume across container
  restarts (e.g. `npm install -g --prefix=/root/npm-global <pkg>`). On macOS
  the default npm prefix is fine — no override needed.

## Commit style

Only applies once the user asks for a commit.

**Scope**: The message must describe ONLY what is actually staged. Before
writing it, check `git diff --cached --stat` and never mention files or changes
excluded from the commit.

Default to the 'Background', 'Problem', 'Approach' structure. Use a concise
subject line only for truly trivial changes (typos, formatting, dependency
bumps) where there is no meaningful context to explain. If there is a *reason*
behind the change — a bug, a prior commit that set up the situation, a subtlety
in how the code works — use the structural style regardless of diff size.

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
