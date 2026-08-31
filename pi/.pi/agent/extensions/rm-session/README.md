# rm-session

Retires the session you are sitting in: `/rm-session` confirms, quits pi, and
deletes the session's history file on the way out.

```
› /rm-session

  ┌ Delete this session? ─────────────────────────────────┐
  │ "Fix need_credit_card_charge? logic"                  │
  │ ~/.pi/agent/sessions/--proj-nerv--/2026-…-01a057b5.jsonl │
  │                                                       │
  │ pi will quit and the history file will be removed.    │
  └───────────────────────── [ Yes ]  [ No ] ─────────────┘
```

## Why

Once the work is merged, the session is dead weight — but it keeps showing up
in `/resume` and `pi -r`, indistinguishable from the sessions that still
matter. Deleting it from the picker means quitting, running `/resume`, finding
the row you were *just* in, and pressing Ctrl+D. This does it from inside the
session being retired, at the moment you know it is obsolete.

## Behaviour

| Situation | What happens |
|---|---|
| `/rm-session` | Confirm → shutdown is requested → file removed as pi exits |
| `/rm-session --force` | Same, without the dialog (also `-f`, `-y`, `--yes`) |
| Dialog declined | Nothing at all: no quit, no delete |
| Ephemeral session (`--no-session`) | Warning, no-op — there is no file |
| `/new`, `/resume`, `/fork` after arming | File survives; those reload the extension, which disarms it |
| Quitting normally | No-op — deletion only happens for a session that armed it |
| Delete fails | One line on stderr; pi still exits |

The unlink deliberately happens in `session_shutdown` rather than in the
command. `SessionManager` appends with `appendFileSync`, so deleting the file
while the session is still alive just gets it recreated as a stub by the next
entry — and `ctx.shutdown()` is *deferred until the agent is idle*, which
widens that window further. `session_shutdown` is the last thing pi emits
before tearing the runtime down, and it carries the `reason`, so `quit` can be
told apart from the `new` / `resume` / `fork` teardowns that must leave the
file alone.

Deletion prefers the [`trash`](https://github.com/sindresorhus/trash-cli) CLI
and falls back to `unlink`, the same order pi's own session picker uses for
Ctrl+D. Install `trash` if you want the file to be recoverable.

## Config (environment variables)

| Variable | Default | Meaning |
|---|---|---|
| `PI_RM_SESSION` | on | `off`/`0`/`false`/`no` disables entirely |
| `PI_RM_SESSION_COMMAND` | `rm-session` | Command name, e.g. `burn` for `/burn` |
| `PI_RM_SESSION_CONFIRM` | on | `off` skips the confirmation dialog |
| `PI_RM_SESSION_TRASH` | on | `off` always unlinks, never tries `trash` |

Without a UI to answer the dialog (print/json mode), the command refuses unless
`--force` is passed, rather than deleting unasked.

## Tests

```bash
node test.mjs
```

Mocks `ExtensionAPI`/`ExtensionCommandContext` but deletes *real* throwaway
session files in a temp dir, so the arming, the shutdown reason guard, and the
unlink itself are all exercised.
