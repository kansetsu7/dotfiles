# /knowledge-status - View Captured Knowledge

Display the status of all captured knowledge organized by domain.

## Instructions

Run the knowledge CLI status command:

```bash
python3 ~/.claude/skills/knowledge-capture/scripts/knowledge-cli.py status
```

Present the output to the user, highlighting:
- Total knowledge items per domain
- Items with low confidence (< 0.5) that need verification
- Stale items (> 90 days since last validation) that need review
- Any pending signals waiting to be processed

## Additional Commands

If user wants more details:

```bash
# Search for specific knowledge
python3 ~/.claude/skills/knowledge-capture/scripts/knowledge-cli.py search "query"

# Show items needing review
python3 ~/.claude/skills/knowledge-capture/scripts/knowledge-cli.py review

# Show pending signals
python3 ~/.claude/skills/knowledge-capture/scripts/knowledge-cli.py signals
```
