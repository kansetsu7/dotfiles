# /learn - Capture Knowledge

Manually trigger knowledge capture from the current conversation context.

## Instructions

1. **Identify knowledge to capture** from recent conversation:
   - Look for business rules, domain logic, or system behavior explanations
   - Look for site-specific differences (HK, CK, SG, AVE_CK)
   - Look for corrections to previous understanding
   - If unclear, ask the user what they want to capture

2. **Determine the domain**:
   - `business-logic` - Payment rules, validation, workflows
   - `site-specific` - Site differences, codes
   - `testing` - Test patterns, fixtures
   - `architecture` - System design, modules
   - `workflow` - Development processes

3. **Create knowledge file** at `~/.claude/knowledge/{domain}/{id}.md`:

```markdown
---
id: {kebab-case-id}
domain: {domain}
confidence: 0.7
sites: [{sites if applicable}]
source: user-explanation
created: {YYYY-MM-DD}
last_validated: {YYYY-MM-DD}
related: []
---

# {Title}

## Rule
{Core knowledge extracted}

## Context
{When this applies}

## Evidence
- User explained on {date}
```

4. **Confirm** what was captured and where it was saved.

## Examples

User: "Background: In HK, payments have a 3-day grace period"
User: "/learn"

→ Create `~/.claude/knowledge/business-logic/hk-payment-grace-period.md`

---

User: "The site_code in Nerv determines which payment gateway we use"
User: "/learn"

→ Create `~/.claude/knowledge/site-specific/nerv-site-code-payment-gateway.md`
