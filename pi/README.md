# pi stow package

Config for the [pi coding agent](https://pi.dev) that reuses the existing
Claude config in `../claude/` where formats are compatible.

## Link

```bash
cd ~/.dotfiles
stow --verbose pi          # links ~/.pi/agent/settings.json
# if it conflicts with an existing settings.json:
stow --adopt --verbose pi  # adopt current file, then `git checkout` to restore ours
```

## How config maps from Claude Code

pi resolves user-global config under `~/.pi/agent/` (the "agent dir") and
project-local config under `.pi/`.

| Resource        | Claude (`~/.claude/`)     | pi (`~/.pi/agent/`)                 | Notes |
|-----------------|---------------------------|------------------------------------|-------|
| Skills          | `skills/<n>/SKILL.md`     | `skills/<n>/SKILL.md`              | Same format. Reused via `skillPaths`. |
| Slash commands  | `commands/*.md`           | `prompts/*.md`                      | Reused via `promptTemplatePaths`. |
| Global memory   | `~/.claude/CLAUDE.md`     | `~/.pi/agent/AGENTS.md`             | pi-specific file — see below. |
| Repo memory     | `./CLAUDE.md`             | `./CLAUDE.md` or `./AGENTS.md`      | Auto-discovered up the cwd tree. |
| System prompt   | (n/a)                     | `SYSTEM.md` / `APPEND_SYSTEM.md`   | Optional override/append. |
| Settings        | `settings.json`           | `settings.json`                    | Different schema (this file). |

Rather than copy/rename, `settings.json` points the `skills` and
`prompts` keys at the existing `~/.claude/` dirs, so there is one
source of truth.

### Global memory (AGENTS.md)

pi loads its *global* context file **only** from the agent dir
(`~/.pi/agent/`), trying these names in order:
`AGENTS.override.md`, `AGENTS.md`, `AGENTS.MD`, `CLAUDE.md`, `CLAUDE.MD`.
It does **not** read `~/.claude/CLAUDE.md`.

This package ships its **own** `pi/.pi/agent/AGENTS.md` rather than reusing
Claude's CLAUDE.md. The two harnesses differ: Claude Code bakes in subagents,
a task tracker, plan mode, and many implicit behaviors; pi's harness is thin
(`read`/`bash`/`edit`/`write`/`glob`/`grep`, no subagents, no built-in task
tracker). The pi file therefore states those behaviors explicitly (never
commit unless asked, verify with `bash`, `plan.md` as the task list) and drops
Claude-only assumptions ("use agents to run tests", built-in Plan Mode).

### MCP credentials (mcp.json)

`pi/.pi/agent/mcp.json` runs the Asana V2 MCP server through `mcp-remote`
(port 3334 is forwarded in the edit container for the OAuth callback).
Two secrets are involved, handled differently:

- **client secret** — `ASANA_CLIENT_SECRET` uses pi's `!command` env syntax to
  `gpg -dq` it from `~/.config/credentials/` at spawn time, so it never sits in
  the repo.
- **OAuth tokens** — `mcp-remote` insists on writing `<hash>_tokens.json`
  (refresh + access token, bare strings) to `MCP_REMOTE_CONFIG_DIR`, and Asana
  V2 refuses personal access tokens, so there is nothing to swap for a `!gpg`
  env var. The server is therefore launched via
  `bin/.local/bin/mcp-auth-sealed`, which keeps that directory on tmpfs
  (`/dev/shm`) and persists it as a single gpg file
  (`~/.local/state/mcp-auth/asana.tar.gpg`) — unsealed on start, re-sealed on
  exit only when the tokens changed. Nothing decrypted ever reaches the
  `/root` volume, and a container restart no longer forces a re-auth.
  The vault lives under `~/.local/state` rather than the stowed
  `~/.config/credentials` on purpose: that directory is a symlink into this
  repo, and a file rewritten on every token refresh would dirty git.

## NOT ported (no native pi equivalent)

- **hooks** (`check-credential-leak.sh`, `check-file-dependencies.sh`) — pi has
  no PostToolUse/PreToolUse hook system.
- **MCP servers** (`.mcp.json` gitlab) — no built-in `mcpServers`; needs a pi
  extension.
- **statusLine** (`statusline.sh`) — unsupported.
- **permissions.allow/deny/ask** — pi uses `--tools`/`--exclude-tools` +
  project trust/approve instead of per-command rules.
- **enabledPlugins** (gopls-lsp, code-simplifier) — pi uses npm `packages`
  (extensions) instead.
