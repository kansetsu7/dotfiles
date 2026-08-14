# force-session-name

Forces a session display name whenever you start a **new** session (`/new`) or
**fork/clone** one (`/fork`, `/clone`).

## Why

Unnamed sessions show their first user message in `/resume` and `pi -r`, which
is usually useless ("fix this", a pasted stack trace). Forks are worse — they
inherit the parent's name, so a tree of experiments shows N identical rows.

## Behaviour

| Situation | What happens |
|---|---|
| `/new` | Input dialog opens before you can type |
| `/fork`, `/clone` | Always prompts, pre-filled hint `<parent name> (fork)` |
| Name too short | Re-prompts (up to `MAX_PROMPTS` times) |
| You press `Esc` | Footer shows `⚠ unnamed session`; the next non-slash message re-prompts and is **blocked** until named |
| `/name foo` typed manually | Block clears immediately |
| Print/JSON mode (`-p`), no UI | Skipped (nothing to prompt with) |

Slash commands always pass through while blocked, so `/name`, `/resume`,
`/quit` remain usable.

## Config (environment variables)

| Variable | Default | Meaning |
|---|---|---|
| `PI_FORCE_SESSION_NAME` | on | `off`/`0`/`false` disables the extension |
| `PI_FORCE_SESSION_NAME_REASONS` | `new,fork` | Comma list from `startup,reload,new,resume,fork` |
| `PI_FORCE_SESSION_NAME_MIN_LEN` | `3` | Minimum accepted name length |
| `PI_FORCE_SESSION_NAME_MAX_PROMPTS` | `3` | Re-asks per trigger before deferring to the input gate |
| `PI_FORCE_SESSION_NAME_BLOCK` | on | `off` = warn only, never block input |

Also prompt on a fresh `pi` launch (empty session only, so `pi -c` is not
interrupted):

```sh
export PI_FORCE_SESSION_NAME_REASONS=startup,new,fork
```

## Install

Nothing to do — `~/.pi/agent/extensions` is stowed from
`pi/.pi/agent/extensions`, and `*/index.ts` there is auto-discovered.
