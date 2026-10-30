# pi stow package

Config for the [pi coding agent](https://pi.dev) that reuses the existing
Claude config in `../claude/` where formats are compatible.

## Install

`install/docker.zsh` installs pi and stows this package. Elsewhere:

```bash
curl -fsSL https://pi.dev/install.sh | sh
mkdir -p ~/.pi/agent && cd ~/.dotfiles && stow --verbose pi
```

Create `~/.pi/agent` first so stow links files into it instead of folding it
into a symlink to this repo — pi writes auth, sessions, and its install there.

## How config maps from Claude Code

| Resource       | Claude (`~/.claude/`) | pi (`~/.pi/agent/`)            | Notes |
|----------------|-----------------------|--------------------------------|-------|
| Skills         | `skills/`             | `skills/`                      | Same format; `settings.json` `skills` points at `~/.claude/skills`. |
| Slash commands | `commands/*.md`       | `prompts/*.md`                 | `settings.json` `prompts` points at `~/.claude/commands`. |
| Global memory  | `CLAUDE.md`           | `AGENTS.md`                    | Separate file — see below. |
| Repo memory    | `./CLAUDE.md`         | `./CLAUDE.md` or `./AGENTS.md` | Auto-discovered up the cwd tree. |
| Settings       | `settings.json`       | `settings.json`                | Different schema. |

### Global memory (AGENTS.md)

pi reads global context only from `~/.pi/agent/`, never `~/.claude/CLAUDE.md`.
This package ships its own `AGENTS.md` because the harnesses differ: Claude
Code bakes in subagents, a task tracker, and plan mode; pi is thin
(`read`/`bash`/`edit`/`write` by default). The pi file states those behaviors
explicitly (never commit unless asked, verify with `bash`, `plan.md` as the
task list) and drops Claude-only assumptions.

### MCP credentials (mcp.json)

`mcp.json` runs the Asana V2 MCP server through `mcp-remote` (port 3334 is
forwarded in the edit container for the OAuth callback). Two secrets:

- **client secret** — `ASANA_CLIENT_SECRET` uses pi's `!command` env syntax to
  `gpg -dq` it from `~/.config/credentials/` at spawn time.
- **OAuth tokens** — `mcp-remote` must write `<hash>_tokens.json` to
  `MCP_REMOTE_CONFIG_DIR`, and Asana V2 refuses personal access tokens. So the
  server is launched via `bin/.local/bin/mcp-auth-sealed`, which keeps that
  directory on tmpfs (`/dev/shm`) and persists it as one gpg file
  (`~/.local/state/mcp-auth/asana.tar.gpg`): unsealed on start, re-sealed on
  exit only when the tokens changed. Nothing decrypted reaches the `/root`
  volume, and restarts don't force a re-auth. The vault is under
  `~/.local/state`, not the stowed `~/.config/credentials`, which stow can fold
  into a symlink to this repo — then every token refresh would dirty git.

## NOT ported

- **hooks** (`check-credential-leak.sh`, `check-file-dependencies.sh`) — no
  PreToolUse/PostToolUse hooks.
- **statusLine** (`statusline.sh`) — unsupported.
- **permissions.allow/deny/ask** — pi uses `--tools`/`--exclude-tools` +
  project trust instead.
- **enabledPlugins** — pi uses npm `packages` (extensions) instead.
