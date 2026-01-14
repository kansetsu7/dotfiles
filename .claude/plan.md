# CLAUDE.md Improvement Plan

## Stage 1: Extract Commit Guide Skill
**Goal**: Create `/commit-guide` skill from commit style section
**Success Criteria**: Skill loads and provides commit template on invocation
**Tests**: Run `/commit-guide` and verify output matches current template
**Status**: Done

## Stage 2: Extract Unstuck Skill
**Goal**: Create `/unstuck` skill from "When Stuck" workflow
**Success Criteria**: Skill guides through structured debugging process
**Tests**: Invoke skill and verify it prompts through all 4 steps
**Status**: Done

## Stage 3: Move Shell Tools to Reference
**Goal**: Extract shell tool table to `.claude/tooling.md`
**Success Criteria**: CLAUDE.md references external file, tooling.md contains table
**Tests**: Verify both files are correctly linked
**Status**: Done

## Stage 4: Add Learning Capture Mechanism
**Goal**: Implement automatic knowledge capture with isolated agent workflow
**Success Criteria**:
- Learning agent detects and captures new knowledge
- Compares against existing docs before confirming
- Updates `.claude/learning.md` without polluting main context
**Tests**:
- Provide prompt with new business logic, verify agent triggers
- Verify agent compares with existing docs
- Verify learning.md is updated after confirmation
**Status**: Not Started

### Stage 4 Sub-tasks

#### 4.1: Create Learning Agent
- File: `agents/learning-capture.md`
- Responsibilities:
  - Read existing project docs (CLAUDE.md, any referenced docs)
  - Read existing `.claude/learning.md`
  - Compare incoming knowledge against existing
  - Identify what's truly new
  - Confirm with user (show diff of what will be added)
  - Update learning.md with confirmed knowledge

#### 4.2: Add Detection Rules to CLAUDE.md
- Triggers for spawning learning agent:
  - User prompt contains "Background:" or similar context sections
  - User explains business logic not found in existing docs
  - User corrects AI's understanding of domain concepts
  - User says "remember this" / "note this" (explicit trigger)
  - **AI discovers patterns/logic while studying codebase** (e.g., after exploration tasks)
- Main agent spawns learning agent with:
  - The new knowledge context
  - Reference to which docs to compare against

#### 4.5: Knowledge Sources for Comparison
Learning agent must read these before determining what's new:
- Project `CLAUDE.md`
- `.claude/learning.md` (existing learnings)
- `.claude/context.md` (user-prepared context for code review, if exists)
- Any docs referenced in CLAUDE.md that are relevant to the topic

#### 4.3: Define learning.md Structure
```markdown
# Project Learnings

## Business Logic
### [Topic]
- **Learned**: [date]
- **Context**: [what prompted this]
- **Key Points**: ...
- **Related**: `file:line` references
- **Source**: [conversation reference]

## Architecture
### [Topic]
...

## Domain Terms
### [Term]
- **Definition**: ...
- **Usage**: ...

## Data Model
### [Entity/Relationship]
- **Learned**: [date]
- **Key Points**: ...

## External Services
### [Service Name]
- **Learned**: [date]
- **Behavior**: ...
- **Gotchas**: ...

## Gotchas
### [Topic]
- **Learned**: [date]
- **Issue**: ...
- **Why**: ...
- **Workaround**: ...
```

#### 4.4: Confirmation UX
Show full proposed entry for user review:
```
I found new knowledge to capture:

## Business Logic
### Payment Arrangement Refunds
- **Learned**: 2024-01-14
- **Context**: User explained PA refund calculation
- **Key Points**:
  - base_expected_payment_amount calculated via SurrenderRefundInfo
  - need_credit_card_charge? depends on created_at
- **Related**: `app/models/payment_arrangement.rb:45`
- **Source**: Session abc123 @ 2024-01-14 10:30

Add this to learning.md? [Y/n]
```

#### 4.6: Conflict Resolution UX
When topic already exists in learning.md:
```
Found existing entry for "Payment Arrangement Refunds" in learning.md.

Existing entry (learned 2024-01-10):
- base_expected_payment_amount from SurrenderRefundInfo

New knowledge:
- need_credit_card_charge? depends on created_at

How to proceed?
1. Append as new entry (keeps both versions)
2. Update existing entry (merge new points)
3. Skip (already documented)
```

## Stage 5: Trim Redundant Content
**Goal**: Remove generic principles that are Claude's default behavior
**Success Criteria**: CLAUDE.md reduced from ~240 to ~100 lines
**Tests**: Verify Claude still follows expected behavior without explicit rules
**Status**: Not Started

---

## Decisions Made

### Learning Capture Mechanism

**Chosen: Option B - Automatic + Explicit with Subagent Isolation**

**Rationale:**
- User prompts contain background knowledge that should be captured
- New knowledge emerges during discussions
- Learning workflow needs back-and-forth conversation
- Isolation via subagent prevents context pollution in main task

**Architecture:**
```
Main Agent ──detects──> Learning Agent ──confirms──> learning.md
                              │
                              ├── Reads project CLAUDE.md
                              ├── Reads .claude/learning.md
                              ├── Reads .claude/context.md (if exists)
                              ├── Identifies what's new
                              └── Shows diff, gets confirmation
```

**Trigger Patterns:**
- Background sections in user prompts
- Business logic explanations
- Domain concept corrections
- Explicit: "remember this" / "note this"
- AI discovers patterns while studying codebase

**Resolved Questions:**
1. Trigger: Automatic detection + explicit command ✓
2. Structure: Categorized (Business Logic, Architecture, Domain Terms) ✓
3. Scope: Per-project (`.claude/learning.md`) ✓
4. Deduplication: Agent compares against existing docs before confirming ✓
5. Integration: Subagent for isolation ✓

### Resolved (2024-01-14)

1. **Confirmation UX**: Full proposed entry ✓
2. **Categories**: Expanded to 6 categories ✓
   - Business Logic
   - Architecture
   - Domain Terms
   - Data Model
   - External Services
   - Gotchas
3. **Cross-reference**: Yes, include conversation reference in **Source** field ✓
4. **AI-discovered knowledge**: Yes, trigger after AI studies codebase ✓
5. **Knowledge sources**: Include `.claude/context.md` in comparison ✓

---

## Documentation Verification (2024-01-14)

### Subagent Approach - VALID ✓

Verified against: https://code.claude.com/docs/en/sub-agents.md

**Confirmed capabilities:**
- Custom subagents defined as markdown files in `.claude/agents/` ✓
- Subagents run in isolated context windows ✓
- Tool access can be restricted via `tools` field ✓
- `AskUserQuestion` tool available for user confirmation ✓
- Description field determines when Claude auto-delegates ✓
- Include "use proactively" in description for automatic triggering ✓

**Key constraint:**
- "Subagents cannot spawn other subagents" - learning agent is terminal

**Recommended agent configuration:**
```yaml
---
name: learning-capture
description: Captures new knowledge to learning.md. Use proactively when user provides background context, explains business logic, or after exploring unfamiliar code.
tools: Read, Glob, Grep, Write, Edit, AskUserQuestion
model: sonnet
---
```

### Memory System Integration

Verified against: https://code.claude.com/docs/en/memory.md

**Decision: Standalone `.claude/learning.md`** ✓

**Rationale:**
- learning.md is an **intermediate working file**, not persistent storage
- Used to capture knowledge during development
- Knowledge gets transferred to proper docs before merge
- File is removed before branch merges to master
- Not committed to git

**Workflow:**
```
During development:
  User explains logic → Learning agent captures to learning.md

Before merge:
  User reviews learning.md → Creates/updates proper documentation
  User deletes learning.md → Branch merges clean
```

### Detection Mechanism

**How main agent triggers learning agent:**
1. Explicit: User says "remember this" / "note this" / `/learn`
2. Automatic: Main agent detects potential new knowledge patterns
3. Post-exploration: After Task(Explore) completes with findings

**Implementation in CLAUDE.md:**
```markdown
## Knowledge Capture

When you detect new knowledge (background context, business logic explanations,
patterns discovered during exploration), delegate to the learning-capture agent.

Trigger patterns:
- User prompt contains "Background:" or context sections
- User explains domain concepts or business rules
- User corrects your understanding
- After exploring code and discovering undocumented patterns
- Explicit: user says "remember this" or runs /learn
```

### Gaps Resolved

1. **Session reference format**: `Session abc123 @ 2024-01-14 10:30` ✓
   - Technical format with session ID and timestamp
   - Enables tracing back to original conversation

2. **Conflict resolution**: Option C - Ask user each time ✓
   - When topic already exists, present options:
     - "Append as new entry"
     - "Update existing entry"
     - "Skip (already documented)"
