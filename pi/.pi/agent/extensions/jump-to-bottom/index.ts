/**
 * jump-to-bottom — show a "Jump to bottom" hint while the transcript is
 * scrolled up, and bind a key that takes you back.
 *
 * Why: in fullscreen mode pi owns the viewport, so scrolling up leaves you
 * looking at old output with no indication that newer messages exist below.
 * Claude Code pins a `Jump to bottom (ctrl+End)` pill above the input box; pi
 * has the machinery (`tui.isFollowingOutput` / `tui.scrollToBottom()`) but no
 * affordance.
 *
 * How:
 *  - A widget pinned above the editor renders a centred pill, but only while
 *    the primary scroll view is *not* following the end of the transcript.
 *    Scrolling back down makes it disappear on its own, because the widget is
 *    re-rendered on every TUI repaint and scrolling requests one.
 *  - `registerShortcut` binds the jump itself. The default is `ctrl+shift+b`
 *    ("bottom") rather than pi's built-in `end` / Claude's `ctrl+End`, since
 *    Apple Magic Keyboards have no End key.
 *
 * Only works in fullscreen `tuiMode`; with the default main-screen TUI the
 * terminal owns the scrollback and pi cannot see or change the scroll offset,
 * so the extension stays quiet.
 *
 * Config (env):
 *   PI_JUMP_TO_BOTTOM=off        disable entirely
 *   PI_JUMP_TO_BOTTOM_KEY        default "ctrl+shift+b"
 *   PI_JUMP_TO_BOTTOM_LABEL      default "Jump to bottom"
 *   PI_JUMP_TO_BOTTOM_PLACEMENT  "above" (default) or "below" the editor
 */

import type { ExtensionAPI, Theme } from "@earendil-works/pi-coding-agent";
import { type KeyId, type TUI, visibleWidth } from "@earendil-works/pi-tui";

const WIDGET_KEY = "jump-to-bottom";
const OFF = new Set(["0", "off", "false", "no"]);

const ENABLED = !OFF.has((process.env.PI_JUMP_TO_BOTTOM ?? "").trim().toLowerCase());
const KEY = (process.env.PI_JUMP_TO_BOTTOM_KEY?.trim() || "ctrl+shift+b") as KeyId;
const LABEL = process.env.PI_JUMP_TO_BOTTOM_LABEL ?? "Jump to bottom";
const PLACEMENT =
	(process.env.PI_JUMP_TO_BOTTOM_PLACEMENT ?? "").trim().toLowerCase() === "below"
		? "belowEditor"
		: "aboveEditor";

/**
 * The viewport-owning TUI. Only `TuiAltScreen` (fullscreen mode) has these;
 * the main-screen TUI scrolls through the terminal's own scrollback.
 */
interface ScrollableTUI extends TUI {
	readonly isFollowingOutput: boolean;
	scrollToBottom(): void;
}

function asScrollable(tui: TUI | undefined): ScrollableTUI | undefined {
	const candidate = tui as ScrollableTUI | undefined;
	if (!candidate) return undefined;
	if (typeof candidate.scrollToBottom !== "function") return undefined;
	if (typeof candidate.isFollowingOutput !== "boolean") return undefined;
	return candidate;
}

/** `alt` is labelled `option` on macOS keyboards; everything else is literal. */
function keyLabel(key: string): string {
	return key
		.split("+")
		.map((part) => (process.platform === "darwin" && part.toLowerCase() === "alt" ? "option" : part))
		.join("+");
}

export default function jumpToBottom(pi: ExtensionAPI): void {
	if (!ENABLED) return;

	let tui: TUI | undefined;

	/** Centred pill, or nothing at all when we are already at the bottom. */
	function line(theme: Theme, width: number): string[] {
		const scrollable = asScrollable(tui);
		if (!scrollable || scrollable.isFollowingOutput) return [];

		const text = ` ${LABEL} (${keyLabel(KEY)}) ↓ `;
		const textWidth = visibleWidth(text);
		if (textWidth > width) return [];

		const pad = Math.max(0, Math.floor((width - textWidth) / 2));
		return [" ".repeat(pad) + theme.bg("selectedBg", theme.fg("text", text))];
	}

	pi.on("session_start", (_event, ctx) => {
		// Widgets are terminal-only; RPC and print mode have no TUI to render to.
		if (ctx.mode !== "tui") return;

		ctx.ui.setWidget(
			WIDGET_KEY,
			(hostTui: TUI, theme: Theme) => {
				tui = hostTui;
				return {
					render: (width: number) => line(theme, width),
					invalidate: () => {},
				};
			},
			{ placement: PLACEMENT },
		);
	});

	pi.registerShortcut(KEY, {
		description: LABEL,
		handler: () => {
			asScrollable(tui)?.scrollToBottom();
		},
	});
}
