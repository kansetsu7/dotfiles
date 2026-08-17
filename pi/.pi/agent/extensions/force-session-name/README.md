# force-session-name

Forces a session display name whenever you launch a fresh `pi`, start a **new**
session (`/new`), or **fork/clone** one (`/fork`, `/clone`).

## Why

Unnamed sessions show their first user message in `/resume` and `pi -r`, which
is usually useless ("fix this", a pasted stack trace). Forks are worse — they
inherit the parent's name, so a tree of experiments shows N identical rows.

## Behaviour

| Situation | What happens |
|---|---|
| `pi` (fresh launch, empty session) | Picker: **New session** or **Resume a previous session** |
| └ nothing resumable in this cwd | Picker skipped — straight to the name dialog |
| └ picked *New session* | Name dialog opens before you can type |
| └ picked *Resume* | Editor is prefilled with `/resume` — press Enter for the built-in picker |
| └ escaped the picker | Treated as *New session*; the name dialog opens |
| └ escaped the name dialog | Footer shows `⚠ unnamed session`; the next non-slash message re-prompts and is **blocked** until named |
| `pi -c` / `--session` (has history) | Skipped — continuing work is not interrupted |
| `/new` | Name dialog opens **before** the current session is torn down |
| `/fork`, `/clone` | Same, pre-filled hint `<parent name> (fork)` |
| └ escaped either dialog | The switch/fork is **cancelled** — you stay in the current session |
| Name too short | Re-prompts (up to `MAX_PROMPTS` times) |
| `/name foo` typed manually | Block clears immediately |
| `Esc`, then `/resume` | Allowed — the block belongs to the session you left, so the resumed one starts clean |
| Print/JSON mode (`-p`), no UI | Skipped (nothing to prompt with) |

Slash commands always pass through while blocked, so `/name`, `/resume`,
`/quit` remain usable.

Picking *Resume* still arms the name gate: if you abandon the resume and type a
normal message instead, the session is unnamed and gets prompted. Actually
resuming clears it, since switching sessions resets the block.

### Why `/new` and `/fork` cancel, but startup blocks

`/new` and `/fork` have pre-events (`session_before_switch`,
`session_before_fork`) that accept `{ cancel: true }`, so the prompt runs while
the current session is still alive and escaping simply leaves you there — no
unnamed session is ever created. The accepted name is held at module scope and
applied in `session_start`, because the replacement session runtime does not
exist until then (pi caches the extension factory per cwd, so module scope
survives the switch).

A bare `pi` launch has no such pre-event — the session already exists by the
time any extension is asked. That path therefore falls back to prompting in
`session_start` and gating input until a name exists.

`PI_FORCE_SESSION_NAME_BLOCK=off` turns off both forms of obstruction: escaping
no longer cancels the switch or blocks messages, it only warns.

### Why resume only prefills `/resume`

Event handlers receive an `ExtensionContext`, but `switchSession()` is only on
`ExtensionCommandContext` (pi's extension runner builds the plain context for
`emit()`). An extension therefore cannot switch sessions from `session_start`,
so the picker hands off to the built-in command rather than reimplementing the
session list. Switching sessions (`startup`, `/new`, `/resume`,
`/fork`) clears any outstanding block; a `reload` re-enters the same session and
keeps it.

The *Resume* option is only offered when `SessionManager.list()` finds another
session in this cwd with at least one message — otherwise it would open an empty
picker.

## Config (environment variables)

| Variable | Default | Meaning |
|---|---|---|
| `PI_FORCE_SESSION_NAME` | on | `off`/`0`/`false` disables the extension |
| `PI_FORCE_SESSION_NAME_REASONS` | `startup,new,fork` | Comma list from `startup,reload,new,resume,fork` |
| `PI_FORCE_SESSION_NAME_MIN_LEN` | `3` | Minimum accepted name length |
| `PI_FORCE_SESSION_NAME_MAX_PROMPTS` | `3` | Re-asks per trigger before cancelling or deferring to the input gate |
| `PI_FORCE_SESSION_NAME_BLOCK` | on | `off` = warn only: never cancel a switch, never block input |
| `PI_FORCE_SESSION_NAME_PICKER` | on | `off` = skip the new/resume choice and ask for a name directly |

To stop prompting on a bare `pi` launch and only prompt for `/new` and forks:

```sh
export PI_FORCE_SESSION_NAME_REASONS=new,fork
```

## Install

Nothing to do — `~/.pi/agent/extensions` is stowed from
`pi/.pi/agent/extensions`, and `*/index.ts` there is auto-discovered.


## See also

[`session-header`](../session-header) displays the resulting name while you
work — this extension only makes sure one exists.
