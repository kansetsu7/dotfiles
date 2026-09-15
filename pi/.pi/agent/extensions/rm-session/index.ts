/**
 * rm-session — throw away the current session's history.
 *
 * Two shapes of the same idea, because a session outlives its usefulness in
 * two different ways:
 *
 *  - **reset** (default): the *work* is done, the *context* is not. Start a
 *    fresh, empty session that keeps the name you were already using, and
 *    delete the old history file. This is the "clear the board, same desk"
 *    move — no quitting, no `/resume`, no retyping the name.
 *  - **quit** (`--quit`): the session is dead weight. Delete the history file
 *    and exit, so it stops showing up in `/resume` and `pi -r`.
 *
 * How:
 *  - Neither path deletes the file inside the command handler.
 *    `SessionManager` appends with `appendFileSync`, so anything written
 *    between the unlink and the teardown would recreate the file as a stub.
 *    The unlink rides along in `session_shutdown`, the last event pi emits for
 *    the outgoing session, where nothing can re-append afterwards.
 *  - `reason` tells the two paths apart: `quit` deletes only on a real quit
 *    (`targetSessionFile` unset — `new`/`resume`/`fork` must leave the file
 *    alone), `reset` deletes only on the `new` teardown its own
 *    `ctx.newSession()` triggers.
 *  - The name is carried over twice, deliberately. `setup()` writes it into
 *    the replacement session directly, which is what happens when
 *    force-session-name is disabled or absent. When it *is* loaded, its
 *    `session_before_switch` prompt would fire first and ask for a name pi
 *    already knows — so the name is also handed off through a module-global
 *    (`globalThis[NAME_HANDOFF]`) that force-session-name consumes in place of
 *    prompting. `setup()` then sees the name already applied and skips.
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
 *   PI_RM_SESSION_MODE         "reset" (default) or "quit"
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

type Mode = "reset" | "quit";

const ENABLED = !isOff(process.env.PI_RM_SESSION);
const COMMAND = process.env.PI_RM_SESSION_COMMAND?.trim() || "rm-session";
const CONFIRM = !isOff(process.env.PI_RM_SESSION_CONFIRM);
const USE_TRASH = !isOff(process.env.PI_RM_SESSION_TRASH);
const MODE: Mode =
	process.env.PI_RM_SESSION_MODE?.trim().toLowerCase() === "quit" ? "quit" : "reset";

const FORCE_FLAGS = new Set(["-f", "--force", "-y", "--yes"]);
const QUIT_FLAGS = new Set(["-q", "--quit", "--exit"]);
const RESET_FLAGS = new Set(["-r", "--reset", "--keep-open"]);

/**
 * Shared with force-session-name: a name pi already knows, so its pre-switch
 * prompt can be skipped for this one switch instead of asking for something
 * that is being carried over verbatim.
 */
const NAME_HANDOFF = "__piPendingSessionName";

const setNameHandoff = (name: string | undefined): void => {
	(globalThis as Record<string, unknown>)[NAME_HANDOFF] = name;
};

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

	// The file to delete once the outgoing session is torn down, and which
	// teardown is allowed to do it.
	let armed: { file: string; mode: Mode } | undefined;

	async function confirmed(
		ctx: ExtensionCommandContext,
		file: string | undefined,
		mode: Mode,
		forced: boolean,
	): Promise<boolean> {
		if (forced || !CONFIRM) return true;
		// Non-interactive runs (print/json) cannot answer a dialog, so require
		// the explicit flag there rather than deleting unasked.
		if (!ctx.hasUI) {
			ctx.ui.notify(`No UI to confirm in — rerun as /${COMMAND} --force`, "error");
			return false;
		}
		const name = ctx.sessionManager.getSessionName();
		const subject = name ? `"${name}"` : "This session";
		const lines =
			mode === "quit"
				? [subject, file ?? "", "", "pi will quit and the history file will be removed."]
				: [
						subject,
						file ?? "(ephemeral session — nothing on disk)",
						"",
						name
							? `History is cleared and a fresh session continues as "${name}".`
							: "History is cleared and a fresh session continues.",
						...(file ? ["The old history file is removed."] : []),
					];
		return await ctx.ui.confirm(
			mode === "quit" ? "Delete this session?" : "Clear this session's history?",
			lines.join("\n"),
		);
	}

	/** Delete the history file and exit — the session is retired for good. */
	async function quitAndDelete(ctx: ExtensionCommandContext, file: string): Promise<void> {
		armed = { file, mode: "quit" };
		ctx.ui.notify("Session will be deleted on exit — quitting…", "info");
		// Deferred until the agent is idle; the unlink rides along in
		// session_shutdown so nothing can re-append afterwards.
		ctx.shutdown();
	}

	/** Swap in an empty session under the same name, dropping the old history. */
	async function resetHistory(
		ctx: ExtensionCommandContext,
		file: string | undefined,
	): Promise<void> {
		const name = ctx.sessionManager.getSessionName();
		if (file) armed = { file, mode: "reset" };
		setNameHandoff(name);
		try {
			const { cancelled } = await ctx.newSession({
				setup: async (sessionManager) => {
					// A no-op when force-session-name already applied the handoff;
					// the source of truth when it is off, absent, or headless.
					if (name && sessionManager.getSessionName() !== name) {
						sessionManager.appendSessionInfo(name);
					}
				},
				withSession: async (next) => {
					next.ui.notify(
						name ? `History cleared — continuing as "${name}"` : "History cleared",
						"info",
					);
				},
			});
			if (cancelled) {
				// Nothing was torn down, so nothing will fire session_shutdown.
				armed = undefined;
				ctx.ui.notify("Session reset cancelled — history kept", "warning");
			}
		} catch (err) {
			armed = undefined;
			ctx.ui.notify(
				`Could not reset the session: ${err instanceof Error ? err.message : String(err)}`,
				"error",
			);
		} finally {
			// Never leave a stale name behind for an unrelated later switch.
			setNameHandoff(undefined);
		}
	}

	pi.registerCommand(COMMAND, {
		description:
			MODE === "quit"
				? "Delete this session's history file and quit pi (--reset to stay)"
				: "Clear this session's history, keeping its name (--quit to exit instead)",
		handler: async (args, ctx) => {
			const flags = args.trim().split(/\s+/).filter(Boolean);
			const forced = flags.some((flag) => FORCE_FLAGS.has(flag));
			const mode: Mode = flags.some((flag) => QUIT_FLAGS.has(flag))
				? "quit"
				: flags.some((flag) => RESET_FLAGS.has(flag))
					? "reset"
					: MODE;

			const file = ctx.sessionManager.getSessionFile();
			// Quitting is only about the file; resetting is about the history,
			// which an ephemeral session has in memory just the same.
			if (!file && mode === "quit") {
				ctx.ui.notify("Ephemeral session — there is no file to delete", "warning");
				return;
			}
			if (!(await confirmed(ctx, file, mode, forced))) return;

			if (mode === "quit") await quitAndDelete(ctx, file as string);
			else await resetHistory(ctx, file);
		},
	});

	pi.on("session_shutdown", (event) => {
		const pending = armed;
		armed = undefined;
		if (!pending) return;
		// `targetSessionFile` marks a session *replacement* (new/resume/fork).
		// A retiring session may only be taken by a real quit; a reset may only
		// be taken by the `new` teardown it asked for itself.
		if (pending.mode === "quit") {
			if (event.reason !== "quit" || event.targetSessionFile) return;
		} else if (event.reason !== "new") {
			return;
		}

		const result = remove(pending.file);
		if (!result.ok) {
			// On quit the TUI is already tearing down, so notify() is swallowed.
			process.stderr.write(
				`rm-session: could not delete ${pending.file}: ${result.error}\n`,
			);
		}
	});
}
