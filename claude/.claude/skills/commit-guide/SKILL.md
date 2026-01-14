---
name: commit-guide
description: Provides commit message template using Background/Problem/Approach structure. Use when writing complex commit messages, bug fixes, refactoring, or multi-file changes.
---

# Commit Message Guide

For complex commits, use the 'Background', 'Problem', 'Approach' structure.
Use backticks to quote code and file paths.

## Section Guidelines

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

## Template

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

## Example

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

## When to Use This Format

Use the full Background/Problem/Approach format for:
- Bug fixes that require context
- Refactoring with non-obvious rationale
- Changes related to previous MRs or issues
- Multi-file changes with interconnected logic

For simple changes, a concise subject line is sufficient.
