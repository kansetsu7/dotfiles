# jump-to-bottom

Pins a `Jump to bottom` pill above the input box while the transcript is
scrolled up, and binds a key that takes you back.

```
                       Jump to bottom (ctrl+shift+b) ↓

› ▊
```

## Why

In fullscreen `tuiMode` pi owns the viewport, so scrolling up leaves you
looking at old output with no sign that newer messages exist below — and the
only way back is the `end` key. Claude Code shows a `Jump to bottom (ctrl+End)`
pill for exactly this. pi already has the machinery (`tui.isFollowingOutput`,
`tui.scrollToBottom()`), just no affordance.

The default key is **`ctrl+shift+b`** ("bottom"), not `end` / `ctrl+End`:
Apple Magic Keyboards have no End key. Like pi's own `ctrl+shift+f` (transcript
search), `ctrl+shift+<letter>` needs a terminal that speaks the Kitty keyboard
protocol — see [terminal-setup.md](https://github.com/badlogic/pi-mono/blob/main/docs/terminal-setup.md).
If yours does not, set `PI_JUMP_TO_BOTTOM_KEY=alt+j`.

## Behaviour

| Situation | What happens |
|---|---|
| Transcript scrolled up | Centred pill above the editor |
| Scrolled back to the end | Pill disappears — the widget re-renders on every repaint, and scrolling requests one |
| `ctrl+shift+b` | Scrolls the transcript to the bottom |
| Terminal too narrow for the label | Nothing rendered, rather than a wrapped/truncated pill |
| Main-screen (non-fullscreen) TUI | Silent no-op — the terminal owns the scrollback, pi cannot see the offset |
| RPC / print mode | Skipped (no TUI to render into) |

Requires `"tuiMode": "fullscreen"` in `settings.json`.

## Config (environment variables)

| Variable | Default | Meaning |
|---|---|---|
| `PI_JUMP_TO_BOTTOM` | on | `off`/`0`/`false`/`no` disables entirely |
| `PI_JUMP_TO_BOTTOM_KEY` | `ctrl+shift+b` | Any pi [key id](https://github.com/badlogic/pi-mono/blob/main/docs/keybindings.md), e.g. `alt+j` |
| `PI_JUMP_TO_BOTTOM_LABEL` | `Jump to bottom` | Pill text |
| `PI_JUMP_TO_BOTTOM_PLACEMENT` | `above` | `below` pins it under the editor instead |

`alt` is displayed as `option` on macOS.

## Tests

```bash
node test.mjs
```

Mocks `ExtensionAPI` plus a fake viewport TUI and renders the widget in both
scroll states, so no terminal is needed.
