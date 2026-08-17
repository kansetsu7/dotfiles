# session-header

Shows the current session name at the top of the chat (or pinned to the editor).

## Why

[`force-session-name`](../force-session-name) makes sure every session *has* a
name, but nothing displays it while you work. After a `/fork` or a `/resume` —
especially with several terminals open — there is no way to tell which branch
the one in front of you belongs to.

```
 π                                            Session: Refactor auth
```

## Behaviour

| Situation | What happens |
|---|---|
| Session starts (TUI) | Header line replaces pi's startup banner |
| `/name foo`, rename by any means | Re-renders immediately (`session_info_changed`) |
| No name set | Shows `Session: Unnamed` |
| Terminal too narrow for both | The ` π` marker is dropped and the name is truncated with `…` — the name is the part worth keeping |
| RPC / print mode | Skipped (no TUI to render into) |

### Header vs. widget

`setHeader()` renders **inside the transcript scroll view**, so the line sits
above the first message and scrolls out of sight as the conversation grows. It
also replaces pi's built-in startup banner (logo, onboarding hints) — there is
no API to render alongside it.

If you would rather have it always visible, `PI_SESSION_HEADER=widget` pins the
same line above the editor instead and leaves the built-in banner alone.

## Config (environment variables)

| Variable | Default | Meaning |
|---|---|---|
| `PI_SESSION_HEADER` | `header` | `off` disables; `widget`/`above` pins above the editor; `below` pins below it |
| `PI_SESSION_HEADER_LABEL` | `Session: ` | Text before the name — set to `▸ ` or `""` for something terser |

## Install

Nothing to do — `~/.pi/agent/extensions` is stowed from
`pi/.pi/agent/extensions`, and `*/index.ts` there is auto-discovered.

## Tests

```sh
node test.mjs
```
