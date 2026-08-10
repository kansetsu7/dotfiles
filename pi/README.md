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
| Global memory   | `CLAUDE.md`               | `CLAUDE.md` or `AGENTS.md`          | Auto-discovered from cwd/repo. |
| System prompt   | (n/a)                     | `SYSTEM.md` / `APPEND_SYSTEM.md`   | Optional override/append. |
| Settings        | `settings.json`           | `settings.json`                    | Different schema (this file). |

Rather than copy/rename, `settings.json` points the `skills` and
`prompts` keys at the existing `~/.claude/` dirs, so there is one
source of truth.

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
