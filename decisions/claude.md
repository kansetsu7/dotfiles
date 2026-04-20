# Claude Code Decisions

Lightweight log of decisions about Claude Code setup and workflow in
this repo — especially "considered X, decided to keep doing Y" outcomes
that are easy to forget and re-litigate.

For decisions that should shape Claude's future behavior automatically,
also save as a feedback memory in
`/root/.claude/projects/-root--dotfiles/memory/`. This file is the
human-readable backup / audit trail.

---

## 2026-04-20 — Commit messages stay in main agent

**Context:** CLAUDE.md defines a Background/Problem/Approach commit
style. Considered delegating commit writing to a subagent to reduce
main-agent context (only an agent-invocation + short result would
remain in history, instead of full `git diff` + `git log` output).

**Decision:** Keep commit writing in the main agent.

**Reasoning:**
- The Background/Problem/Approach template depends on knowing *why*
  the change was made. That "why" lives in the conversation, not the
  diff. A subagent re-derives intent blindly from the diff alone.
- Amend flows break down: after a subagent writes the message, the
  main agent has no memory of producing it, so user feedback on the
  message has to start from zero.
- The one-time cost of `git diff` + `git log` in main context is
  worth the quality gain.

**Revisit if:** diffs get so large that context pressure outweighs the
quality benefit, or for bulk/mechanical commits (e.g. splitting many
unrelated cleanups) where intent is self-evident from the diff.

**Also saved as:** feedback memory at
`memory/feedback_commit_writing.md` so it shapes Claude's default
behavior automatically.
