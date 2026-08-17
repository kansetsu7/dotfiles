/**
 * session-header — show the current session name at the top of the chat.
 *
 * Why: `force-session-name` makes sure every session *has* a name, but nothing
 * shows it once you are working. After a `/fork` or a `/resume` there is no way
 * to tell which branch the terminal in front of you belongs to.
 *
 * How:
 *  - `ctx.ui.setHeader()` replaces pi's startup banner with a one-liner:
 *    ` π` on the left, `Session: <name>` on the right.
 *  - `session_info_changed` re-renders it, so `/name` shows up immediately.
 *  - The header lives inside the transcript scroll view, so it scrolls away as
 *    the conversation grows. Set `PI_SESSION_HEADER=widget` to pin the same
 *    line above the editor instead, where it is always visible.
 *
 * Config (env):
 *   PI_SESSION_HEADER=off      disable entirely
 *   PI_SESSION_HEADER=widget   pin above the editor instead of the chat header
 *   PI_SESSION_HEADER=below    pin below the editor
 *   PI_SESSION_HEADER_LABEL    default "Session: "
 */

import type { ExtensionAPI, Theme } from "@earendil-works/pi-coding-agent";
import { type TUI, truncateToWidth, visibleWidth } from "@earendil-works/pi-tui";

const WIDGET_KEY = "session-header";
const LEFT = " π";
const UNNAMED = "Unnamed";

const PLACEMENT = (process.env.PI_SESSION_HEADER ?? "").trim().toLowerCase();
const OFF = new Set(["0", "off", "false", "no"]);
const LABEL = process.env.PI_SESSION_HEADER_LABEL ?? "Session: ";

type Mode = "header" | "aboveEditor" | "belowEditor";

const MODE: Mode | undefined = OFF.has(PLACEMENT)
	? undefined
	: PLACEMENT === "widget" || PLACEMENT === "above"
		? "aboveEditor"
		: PLACEMENT === "below"
			? "belowEditor"
			: "header";

export default function sessionHeader(pi: ExtensionAPI): void {
	if (!MODE) return;

	let tui: TUI | undefined;

	/**
	 * Right-aligned name, with the ` π` marker filling the left. When the
	 * terminal is too narrow for both, the marker goes first: the name is the
	 * part worth keeping.
	 */
	function line(theme: Theme, width: number): string[] {
		const name = `${LABEL}${pi.getSessionName() ?? UNNAMED}`;
		const gap = width - visibleWidth(LEFT) - visibleWidth(name) - 1;
		if (gap >= 1) {
			return [
				theme.fg("muted", LEFT) + " ".repeat(gap) + theme.fg("accent", name),
			];
		}
		return [theme.fg("accent", truncateToWidth(name, Math.max(0, width), "…"))];
	}

	pi.on("session_start", (_event, ctx) => {
		// Header/widget components are terminal-only; RPC has no TUI to render to.
		if (ctx.mode !== "tui") return;

		const factory = (hostTui: TUI, theme: Theme) => {
			tui = hostTui;
			return {
				render: (width: number) => line(theme, width),
				invalidate: () => {},
			};
		};

		if (MODE === "header") {
			ctx.ui.setHeader(factory);
			return;
		}
		ctx.ui.setWidget(WIDGET_KEY, factory, { placement: MODE });
	});

	pi.on("session_info_changed", () => {
		tui?.requestRender();
	});
}
