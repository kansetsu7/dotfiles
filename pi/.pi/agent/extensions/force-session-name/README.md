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
| `/fork`, `/clone` | Same, default `<parent name> (fork)` |
| cwd is under a configured work root | The dialog offers the current git branch — press Enter to take it |
| └ escaped either dialog | The switch/fork is **cancelled** — you stay in the current session |
| Name too short | Re-prompts (up to `MAX_PROMPTS` times) |
| `/name foo` typed manually | Block clears immediately |
| `Esc`, then `/resume` | Allowed — the block belongs to the session you left, so the resumed one starts clean |
| Print/JSON mode (`-p`), no UI | Skipped (nothing to prompt with) |
| `/new` with a name already decided (see below) | Prompt skipped — the supplied name is applied |

Slash commands always pass through while blocked, so `/name`, `/resume`,
`/quit` remain usable.

### Branch name as the default

Work projects are almost always named after the branch, so inside a configured
root the dialog offers it:

```
Name this new session
> feature/ABC-123-payment-arrangement — press Enter to accept
```

Submitting an empty input takes that name; typing anything overrides it. It has
to work that way round because `ctx.ui.input(title, placeholder)` only accepts a
*placeholder* — pi's `ExtensionUIDialogOptions` exposes `signal` and `timeout`
only, and `showExtensionInput()` never forwards an `initialValue` to the input
component, so an extension cannot literally prefill the box. "Prefilled" is
therefore spelled "Enter accepts it".

The branch is read from `.git/HEAD` directly — no `git` subprocess, and linked
worktrees resolve through their `gitdir:` pointer. Nothing is offered when:

- the cwd is outside every root in `PI_FORCE_SESSION_NAME_BRANCH_DIRS` (personal
  projects keep the generic `e.g. Refactor auth module` hint),
- there is no repo above the cwd,
- `HEAD` is detached (a bare sha is not a session name), or
- the branch is shorter than `PI_FORCE_SESSION_NAME_MIN_LEN`.

Roots match on path boundaries, so `/proj` covers `/proj/foo` but not
`/project/foo`. `~` is expanded.

Forks keep the `<parent name> (fork)` default instead: a fork of a branch's
session is still about that branch, so the branch name alone would just collide
with the session it was forked from.

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

### Name handoff from other extensions

A `/new` whose name is already settled should not be prompted for. Another
extension can publish it on `globalThis.__piPendingSessionName` immediately
before triggering the switch; `session_before_switch` consumes it (read-once)
and applies it in `session_start` exactly as if it had been typed.

[rm-session](../rm-session/) uses this: its reset starts a fresh session that
deliberately keeps the current name, so prompting would be asking about
something that is not in question. The handoff is consumed even without a UI
and on non-`new` switches, so a stale value cannot leak into a later,
unrelated switch.

Applying the name is idempotent: `pi.setSessionName()` appends a `session_info`
entry with no dedupe, and rm-session's `newSession({ setup })` callback has
already written the name by the time `session_start` fires. Re-applying it
would leave two identical `session_info` entries in the transcript, so the
current name is compared first.

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
| `PI_FORCE_SESSION_NAME_BRANCH` | on | `off` = never offer the git branch as the default |
| `PI_FORCE_SESSION_NAME_BRANCH_DIRS` | `/proj,/project/playbooks,/project/vm` | Comma list of roots where the branch default applies |

To stop prompting on a bare `pi` launch and only prompt for `/new` and forks:

```sh
export PI_FORCE_SESSION_NAME_REASONS=new,fork
```

To use branch names in another checkout tree as well:

```sh
export PI_FORCE_SESSION_NAME_BRANCH_DIRS=/proj,/project/playbooks,/project/vm,~/work
```

## Install

Nothing to do — `~/.pi/agent/extensions` is stowed from
`pi/.pi/agent/extensions`, and `*/index.ts` there is auto-discovered.


## See also

[`session-header`](../session-header) displays the resulting name while you
work — this extension only makes sure one exists.
