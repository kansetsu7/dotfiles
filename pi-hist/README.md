# pi-hist

Interactive search across pi session transcripts, spanning every Nerv worktree.

## Why

pi keys session storage off `pwd`. Work started in `/proj/nerv_hk` lands in
`~/.pi/agent/sessions/--proj-nerv_hk--/`, and `/resume` from `nerv_ck` will
never list it. The four Nerv worktrees are subsidiaries of one codebase sharing
most features, so *"which worktree was I in when I solved this?"* is usually the
wrong question to have to answer.

An earlier attempt consolidated the storage directories with symlinks. That was
the wrong fix. A transcript records **absolute paths** in every tool call, so
resuming a `nerv_ck` session with cwd `/proj/nerv_hk` fills the context with
paths that contradict the working directory, and the model goes on editing the
original worktree. No error is raised, so the damage is silent.

Searching itself carries no such hazard: it is read-only, and the transcript
never becomes the working context.

`Enter` then closes the loop safely. Instead of resuming in whatever directory
you happen to be standing in, it **chdirs to the cwd recorded in the
transcript and execs pi there**, so the working directory and the paths inside
the session always agree — exactly the invariant the symlink approach broke.
Search from any worktree; resume lands you in the right one.

## Usage

```sh
pi-hist                 # browse every Nerv session, newest first
pi-hist -q payment      # start with a query
pi-hist -a              # all sessions, not just Nerv worktrees
```

### Keys

| Key | Action |
|---|---|
| *(type)* | filter transcripts live |
| `↑` `↓` / `^p` `^n` | move selection |
| `pgup` `pgdn` | scroll the preview pane |
| `tab` | toggle scope: Nerv worktrees ↔ all sessions |
| `⏎` | chdir to the session's worktree and resume it in pi |
| `esc` `^c` | quit |

Only **user and assistant** messages are searched. Tool output is discarded at
parse time: it is the bulk of a transcript (file dumps, diffs, grep results)
and searching it buries the conversation you are looking for.

### What `Enter` does, precisely

```
os.Chdir(session.cwd)  →  syscall.Exec(pi, "--session", transcript)
```

Replacing the process rather than spawning one means pi owns the terminal
outright and inherits the exit status, with no idle parent holding the tty.

The chdir binds to *this process*, so it reaches pi but **cannot move the
calling shell** — a child process can never do that. Quitting pi therefore
returns you to the directory you started in. If you would rather the shell
itself follow, that needs a wrapper function in `.zshrc` rather than a binary.

Two failure cases exit non-zero with a clear message: the recorded worktree no
longer exists (it may have been removed long after the transcript was
written), or `pi` is not on `PATH`.

## How sessions are found

By the `cwd` recorded in each transcript's header line — **not** by the
directory name pi derives from it:

```json
{"type":"session","version":3,"timestamp":"…","cwd":"/proj/nerv_hk"}
```

That keeps working across the consolidated archive directory, the per-worktree
directories stock pi recreates, sessions started at `$PROJECT_PATH`, and any
worktree added later.

Worktree roots are built from the environment rather than hardcoded, because
the layout differs per machine:

| | `PROJECT_PATH` | `NERV_PREFIX` | Worktree |
|---|---|---|---|
| docker | `/proj` | `nerv_` | `/proj/nerv_hk` |
| mac | `$HOME/proj` | *(empty)* | `~/proj/hk` |

A literal `nerv` match would silently find nothing on mac. Matching is
boundary-aware, so `/proj/nerv_hk/lilith` is in scope (shown as
`nerv_hk/lilith`) while `/proj/nervcop` and `/proj/nerv_hk_scratch` are not.

| Variable | Default | Meaning |
|---|---|---|
| `PI_SESSION_ROOT` | `~/.pi/agent/sessions` | Where transcripts live |
| `PROJECT_PATH` | `/proj` | Parent of the worktrees |
| `NERV_PREFIX` | `nerv_` | Per-machine worktree prefix; may be empty |
| `NERV_WORKTREES` | `hk ck sg ave_ck` | Space-separated worktree names |

## Build

Not stowed — `~/.local/bin` holds the compiled binary, the repo holds source:

```sh
go build -C ~/.dotfiles/pi-hist -o ~/.local/bin/pi-hist .
```

## Tests

```sh
cd ~/.dotfiles/pi-hist && go test ./...
```

Covers worktree boundary matching (including the mac layout), transcript
parsing, the exclusion of tool output, and model behaviour driven through
`Update` — filtering, scope toggling, selection, and the empty-result path.
Selection is asserted to carry the recorded **cwd**, not just the transcript
path, since resuming in the wrong worktree is the failure this tool exists to
avoid.

Two further tests pin bugs found during development: list rows must clip rather
than wrap (a wrapped row shears the two-pane layout), and the counter
denominator must be the in-scope count, since `8/72` under scope `nerv` implies
64 Nerv sessions failed to match when 34 were never in scope.

Loading the full corpus (72 sessions, 16 MB) takes well under a second, so
everything is read eagerly at startup.

The `Enter` path is not unit-tested — `syscall.Exec` replaces the test binary.
It was verified manually by putting a fake `pi` on `PATH` under a pty and
confirming it received the right cwd and `--session` argument, along with both
error paths.
