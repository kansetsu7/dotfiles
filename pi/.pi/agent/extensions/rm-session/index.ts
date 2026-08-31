/**
 * rm-session — delete the current session's history file, then quit pi.
 *
 * Why: once a piece of work is merged, its session is dead weight. It still
 * shows up in `/resume` and `pi -r`, where it is indistinguishable from the
 * sessions that still matter. Deleting it from the picker means quitting,
 * running `/resume`, hunting for the row you were just in, and Ctrl+D — this
 * does the same thing from inside the session that is being retired.
 *
 * How:
 *  - `/rm-session` confirms, arms the deletion, and calls `ctx.shutdown()`.
 *    It does *not* delete the file there: `SessionManager` appends with
 *    `appendFileSync`, so anything written between the unlink and process exit
 *    would recreate the file as a stub. Shutdown is also deferred until the
 *    agent is idle, which widens that window.
 *  - The unlink happens in `session_shutdown`, the last thing pi emits before
 *    tearing the runtime down, and only for `reason: "quit"`. `new`, `resume`
 *    and `fork` also fire it, and those must not take the file with them.
 *  - `armed` is per-session state on purpose. A session switch reloads the
 *    extension, which disarms the deletion — if you asked to retire *this*
 *    session and then navigated away, the safe reading is that you changed
 *    your mind.
 *  - Deletion prefers the `trash` CLI and falls back to `unlink`, matching
 *    what pi's own session picker does on Ctrl+D.
 *
 * Config (env):
 *   PI_RM_SESSION=off          disable entirely
 *   PI_RM_SESSION_COMMAND      default "rm-session"
 *   PI_RM_SESSION_CONFIRM=off  skip the confirmation dialog
 *   PI_RM_SESSION_TRASH=off    always unlink, never try the `trash` CLI
 */

import { spawnSync } from "node:child_process";
import { existsSync, rmSync } from "node:fs";
import type {
	ExtensionAPI,
	ExtensionCommandContext,
} from "@earendil-works/pi-coding-agent";

const OFF = new Set(["0", "off", "false", "no"]);
const isOff = (v: string | undefined): boolean =>
	v !== undefined && OFF.has(v.trim().toLowerCase());

const ENABLED = !isOff(process.env.PI_RM_SESSION);
const COMMAND = process.env.PI_RM_SESSION_COMMAND?.trim() || "rm-session";
const CONFIRM = !isOff(process.env.PI_RM_SESSION_CONFIRM);
const USE_TRASH = !isOff(process.env.PI_RM_SESSION_TRASH);

const FORCE_FLAGS = new Set(["-f", "--force", "-y", "--yes"]);

type Removal = { ok: true; method: "trash" | "unlink" } | { ok: false; error: string };

/**
 * `trash` first so the file is recoverable, then `unlink`. A missing `trash`
 * binary shows up as `result.error` (ENOENT) rather than a non-zero status, so
 * both are treated the same: fall through to the permanent delete.
 */
function remove(file: string): Removal {
	if (USE_TRASH) {
		// A leading "-" would be parsed as an option; "--" ends the flags.
		const args = file.startsWith("-") ? ["--", file] : [file];
		const result = spawnSync("trash", args, { encoding: "utf-8" });
		if (result.status === 0 || !existsSync(file)) {
			return { ok: true, method: "trash" };
		}
	}
	try {
		rmSync(file, { force: true });
		return { ok: true, method: "unlink" };
	} catch (err) {
		return { ok: false, error: err instanceof Error ? err.message : String(err) };
	}
}

export default function rmSession(pi: ExtensionAPI): void {
	if (!ENABLED) return;

	let armed: string | undefined;

	async function confirmed(
		ctx: ExtensionCommandContext,
		file: string,
		args: string,
	): Promise<boolean> {
		const forced = args
			.trim()
			.split(/\s+/)
			.some((arg) => FORCE_FLAGS.has(arg));
		if (forced || !CONFIRM) return true;
		// Non-interactive runs (print/json) cannot answer a dialog, so require
		// the explicit flag there rather than deleting unasked.
		if (!ctx.hasUI) {
			ctx.ui.notify(
				`No UI to confirm in — rerun as /${COMMAND} --force`,
				"error",
			);
			return false;
		}
		const name = ctx.sessionManager.getSessionName();
		return await ctx.ui.confirm(
			"Delete this session?",
			[
				name ? `"${name}"` : "This session",
				`${file}`,
				"",
				"pi will quit and the history file will be removed.",
			].join("\n"),
		);
	}

	pi.registerCommand(COMMAND, {
		description: "Delete this session's history file and quit pi",
		handler: async (args, ctx) => {
			const file = ctx.sessionManager.getSessionFile();
			if (!file) {
				ctx.ui.notify("Ephemeral session — there is no file to delete", "warning");
				return;
			}
			if (!(await confirmed(ctx, file, args))) return;

			armed = file;
			ctx.ui.notify("Session will be deleted on exit — quitting…", "info");
			// Deferred until the agent is idle; the unlink rides along in
			// session_shutdown so nothing can re-append afterwards.
			ctx.shutdown();
		},
	});

	pi.on("session_shutdown", (event) => {
		const file = armed;
		armed = undefined;
		// `targetSessionFile` marks a session *replacement* (new/resume/fork);
		// only a real quit should take the file with it.
		if (!file || event.reason !== "quit" || event.targetSessionFile) return;

		const result = remove(file);
		if (!result.ok) {
			// The TUI is already tearing down, so notify() would be swallowed.
			process.stderr.write(`rm-session: could not delete ${file}: ${result.error}\n`);
		}
	});
}
