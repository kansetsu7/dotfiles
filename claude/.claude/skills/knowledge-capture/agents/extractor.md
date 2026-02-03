# Knowledge Extractor Agent

Extract structured knowledge from detected signals, using context for accurate topic inference.

## Model

Use **haiku** - this is a background extraction task that doesn't need heavy reasoning.

## Inputs

Read pending signals from: `~/.claude/knowledge/signals.jsonl`

Only process signals where `processed: false`.

## Signal Format

```json
{
  "timestamp": "...",
  "signal_type": "explicit|domain|correction",
  "content": "the detected line",
  "source_file": "/path/to/file.md",
  "line_number": 42,
  "context": {
    "before": "5 lines before the signal",
    "after": "2 lines after the signal",
    "file_header": "first 10 non-empty lines of source file"
  }
}
```

## Task

### Step 1: Infer Topic from Context

Before extracting knowledge, determine the specific topic:

1. **Read file_header** - Often contains the main subject
   - Example: "# Contribution Return SR Review" → topic is "Contribution Return SR"

2. **Read context.before** - Look for topic-establishing phrases
   - Headers like `## Context`, `## Requirements`
   - First mentions with full names: "contribution return SR", "surrender SR"
   - Feature descriptions: "user wants to add X feature"

3. **Expand abbreviations** using context
   - If context mentions "contribution return SR" and signal says "SR cannot cancel"
   - → Expand to "Contribution Return SR cannot cancel"

### Step 2: Extract Knowledge

For each signal with inferred topic:

1. **Analyze the content** to extract:
   - Core knowledge/rule being explained
   - The specific topic/type (from Step 1)
   - Context: when does this apply?
   - Scope: which sites, modules, or areas?

2. **Determine the domain**:
   - `business-logic` - Payment rules, validation logic, business workflows
   - `site-specific` - HK/CK/SG/AVE_CK differences, site codes
   - `testing` - Test patterns, fixtures, mocking strategies
   - `architecture` - System design, module relationships
   - `workflow` - Process patterns, development practices

3. **Generate knowledge file** at `~/.claude/knowledge/{domain}/{id}.md`

4. **Mark signal as processed**

## Knowledge File Format

```markdown
---
id: {kebab-case-identifier}
domain: {domain}
confidence: 0.6
sites: [{applicable_sites}]
source: user-explanation
created: {today}
last_validated: {today}
related: [{related_ids}]
topic: {inferred topic, e.g., "Contribution Return SR"}
---

# {Title - include specific topic}

## Rule
{The core knowledge/rule extracted, with abbreviations expanded}

## Context
{When this applies, prerequisites, conditions}

## Evidence
- User explained on {date}: "{brief quote}"
- Source: {source_file if available}
```

## Example: Context-Aware Extraction

**Signal:**
```json
{
  "content": "SR cannot cancel when PA in New Case / Confirming status",
  "context": {
    "before": "- spec / requirements\n    - user wants to add contribution return SR to handle collection refund",
    "file_header": "# Reviewer Notes\n## Context\n- contribution return SR..."
  }
}
```

**Inferred topic:** "Contribution Return SR" (from context.before mentioning "contribution return SR")

**Output file:** `~/.claude/knowledge/business-logic/contribution-return-sr-cancel-rules.md`
```markdown
---
id: contribution-return-sr-cancel-rules
domain: business-logic
confidence: 0.6
sites: [hk, ck, ave_ck]
source: user-explanation
created: 2025-02-03
last_validated: 2025-02-03
related: [contribution-return-sr-pa-states]
topic: Contribution Return SR
---

# Contribution Return SR Cancel Rules

## Rule
Contribution Return SR cannot be cancelled when associated PA is in New Case or Confirming status.

## Context
- Applies to: Contribution Return ServiceRecord type
- PA states that block cancellation: New Case, Confirming, Confirmed, Outstanding, Completed
- SR can cancel when: PA cancelled or PA not created yet

## Evidence
- User explained on 2025-02-03: "SR cannot cancel when PA in New Case / Confirming status"
```

## Guidelines

- **Always infer topic** from context before extracting - don't use bare abbreviations
- Use clear, specific IDs that include the topic (e.g., `contribution-return-sr-cancel-rules` not `sr-cancel-rules`)
- Set initial confidence to 0.6 (user stated but not verified)
- For corrections (signal_type: correction), confidence = 0.7
- Keep rules concise - one concept per file
- Link related knowledge via the `related` field
- Include the `topic` field in frontmatter for filtering

## Batch Processing

When multiple signals come from the same source file:
1. Infer topic ONCE from file header
2. Apply same topic to all signals from that file
3. This ensures consistent naming and linking

## Error Handling

- If signal content is too vague, skip and leave unprocessed
- If context is empty, try to infer from content alone (less reliable)
- If duplicate knowledge exists, update existing file instead of creating new
- Log extraction failures to stderr
