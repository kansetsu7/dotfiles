# knowledge-capture

Hook-based knowledge capture system that automatically detects when users explain domain knowledge and extracts it into structured knowledge files.

## Overview

Unlike `continuous-learning-v2` which captures behavioral patterns from tool usage, this skill captures **explicit knowledge** - business rules, site-specific logic, and domain concepts that users explain during conversations.

## How It Works

```
User message with knowledge signal
        │
        ▼ detect-knowledge.sh hook
┌─────────────────────────────────┐
│      signals.jsonl              │
│  (detected explanations)        │
└─────────────────────────────────┘
        │
        ▼ Haiku extractor (background)
┌─────────────────────────────────┐
│      ~/.claude/knowledge/       │
│  ├── business-logic/            │
│  ├── site-specific/             │
│  └── ...                        │
└─────────────────────────────────┘
```

## Detection Signals

The hook detects three types of knowledge signals:

### Explicit
- `Background:` or `Context:` headers
- "remember this/that", "note this/that"
- `/learn` command

### Domain
- "in our system", "in the codebase"
- "business rule", "domain logic"
- Site-specific mentions (HK, CK, SG, AVE_CK)
- "in Nerv"

### Corrections
- "no, actually..."
- "that's not right/correct"
- "it should be..."
- "you're wrong"

## Knowledge Domains

- **business-logic** - Payment rules, validation, workflows
- **site-specific** - HK/CK/SG differences, site codes
- **testing** - Test patterns, fixtures, mocking
- **architecture** - System design, module relationships
- **workflow** - Development processes, patterns

## Commands

- `/learn` - Manually trigger knowledge capture from current context
- `/knowledge-status` - View all captured knowledge by domain

## CLI

```bash
# View knowledge status
python3 ~/.claude/skills/knowledge-capture/scripts/knowledge-cli.py status

# Search knowledge
python3 ~/.claude/skills/knowledge-capture/scripts/knowledge-cli.py search "payment"

# Show items needing review
python3 ~/.claude/skills/knowledge-capture/scripts/knowledge-cli.py review

# Validate an item (bump confidence)
python3 ~/.claude/skills/knowledge-capture/scripts/knowledge-cli.py validate hk-payment-rules

# Show pending signals
python3 ~/.claude/skills/knowledge-capture/scripts/knowledge-cli.py signals
```

## Knowledge File Format

```yaml
---
id: hk-payment-rules
domain: business-logic
confidence: 0.7
sites: [hk]
source: user-explanation
created: 2025-02-03
last_validated: 2025-02-03
related: [ck-payment-rules]
---

# HK Payment Rules

## Rule
[Extracted rule]

## Context
[When this applies]

## Evidence
- User explained on 2025-02-03
```

## Confidence Levels

- **0.6** - Initial extraction from user explanation
- **0.7** - User correction (higher trust)
- **+0.1** - Each validation via CLI
- **< 0.5** - Needs review
- **> 90 days** - Marked stale, needs revalidation

## Configuration

See `config.json` for:
- Detection patterns
- Domain definitions
- Confidence thresholds
- Stale period

## Comparison with continuous-learning-v2

| Aspect | continuous-learning-v2 | knowledge-capture |
|--------|------------------------|---------------------|
| Focus | Behavioral patterns | Explicit knowledge |
| Trigger | Every tool call | Knowledge signals only |
| Output | Atomic instincts | Knowledge documents |
| Volume | High | Low |
| Use case | Learn preferences | Capture domain rules |
