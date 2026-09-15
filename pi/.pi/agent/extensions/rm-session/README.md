# rm-session

Throws away the current session's history. By default it does that *without*
leaving the session: `/rm-session` confirms, starts a fresh empty session under
the same name, and deletes the old history file.

```
› /rm-session

  ┌ Clear this session's history? ────────────────────────────┐
  │ "Fix need_credit_card_charge? logic"                      │
  │ ~/.pi/agent/sessions/--proj-nerv--/2026-…-01a057b5.jsonl   │
  │                                                           │
  │ History is cleared and a fresh session continues as        │
  │ "Fix need_credit_card_charge? logic".                     │
  │ The old history file is removed.                          │
  └───────────────────────── [ Yes ]  [ No ] ─────────────────┘

  ✓ History cleared — continuing as "Fix need_credit_card_charge? logic"
```

## Why

Two ways a session outlives its usefulness:

- **The context is stale, the work is not.** The thread is long, half of it is
  about a detour, and you want a clean slate under the same heading. Doing that
  by hand means `/rm-session`, quitting, relaunching pi, and retyping the same
  session name — every time. `/rm-session` now *is* that sequence.
- **The session is dead weight.** Once the work is merged it keeps showing up
  in `/resume` and `pi -r`, indistinguishable from the sessions that still
  matter. That is `/rm-session --quit`.

## Behaviour

| Situation | What happens |
|---|---|
| `/rm-session` | Confirm → new empty session, same name → old history file removed |
| `/rm-session --quit` | Confirm → pi quits → history file removed (also `-q`, `--exit`) |
| `/rm-session --force` | Same as either, without the dialog (also `-f`, `-y`, `--yes`) |
| Dialog declined | Nothing at all: no switch, no quit, no delete |
| Unnamed session | Resets anyway; there is simply no name to carry over |
| Ephemeral session (`--no-session`) | Reset still clears the in-memory history; `--quit` warns and no-ops |
| Switch cancelled or failed | History kept, notice shown, deletion disarmed |
| `/new`, `/resume`, `/fork` after `--quit` | File survives; those reload the extension, which disarms it |
| Quitting normally | No-op — deletion only happens for a session that armed it |
| Delete fails | One line on stderr; pi carries on |

`PI_RM_SESSION_MODE=quit` swaps the default round: `/rm-session` quits, and
`--reset` (also `-r`, `--keep-open`) asks for the reset explicitly.

The unlink deliberately happens in `session_shutdown` rather than in the
command. `SessionManager` appends with `appendFileSync`, so deleting the file
while the session is still alive just gets it recreated as a stub by the next
entry. `session_shutdown` is the last thing pi emits for the outgoing session,
and it carries the `reason`, so the two paths can each wait for their own
teardown: `quit` for a real quit (no `targetSessionFile`), `reset` for the
`new` teardown its own `ctx.newSession()` triggers.

Deletion prefers the [`trash`](https://github.com/sindresorhus/trash-cli) CLI
and falls back to `unlink`, the same order pi's own session picker uses for
Ctrl+D. Install `trash` if you want the file to be recoverable.

### Keeping the name

The name is carried into the replacement session twice, on purpose:

- `newSession({ setup })` writes it straight into the new session — the path
  taken when [force-session-name](../force-session-name/) is off, absent, or
  the run is headless.
- force-session-name prompts for a name on every `/new`, and a reset *is* a
  `/new` under the hood. Being asked for a name pi already knows is noise, so
  the name is also published on `globalThis.__piPendingSessionName` before the
  switch; force-session-name consumes it in `session_before_switch` in place of
  its prompt. `setup()` then sees the name already applied and skips.

## Config (environment variables)

| Variable | Default | Meaning |
|---|---|---|
| `PI_RM_SESSION` | on | `off`/`0`/`false`/`no` disables entirely |
| `PI_RM_SESSION_COMMAND` | `rm-session` | Command name, e.g. `burn` for `/burn` |
| `PI_RM_SESSION_MODE` | `reset` | `quit` restores the delete-and-exit default |
| `PI_RM_SESSION_CONFIRM` | on | `off` skips the confirmation dialog |
| `PI_RM_SESSION_TRASH` | on | `off` always unlinks, never tries `trash` |

Without a UI to answer the dialog (print/json mode), the command refuses unless
`--force` is passed, rather than deleting unasked.

## Tests

```bash
node test.mjs
```

Mocks `ExtensionAPI`/`ExtensionCommandContext` — including a `newSession()`
that reproduces pi's teardown → `setup` → `withSession` order — but deletes
*real* throwaway session files in a temp dir, so the arming, the shutdown
reason guards, the name handoff, and the unlink itself are all exercised.
