---
description: Audit local pi extensions after a pi coding agent upgrade
---

Audit the local pi extensions in `pi/.pi/agent/extensions/` against the
currently installed pi coding agent.

Load and follow `~/.claude/skills/pi-extension-audit/SKILL.md`.

Run the whole workflow, including the changelog review in step 3 — a green
typecheck only proves the extensions still compile, not that behaviour held.

Report findings split into: broken by the upgrade / pre-existing latent /
optional adoption. Then record the audited version. Do not commit unless asked.
