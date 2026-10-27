/**
 * Test harness for rm-session. Loads the extension via jiti (the same loader
 * pi uses) with a mock ExtensionAPI/ExtensionCommandContext, and drives both
 * flows — reset (newSession → session_shutdown "new") and quit (shutdown →
 * session_shutdown "quit") — against real throwaway session files, so the
 * deletion itself is exercised rather than mocked.
 *
 *   node test.mjs
 */
import { existsSync, mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { createRequire } from "node:module";
import { tmpdir } from "node:os";
import { join } from "node:path";

const PI_INSTALL =
	process.env.PI_MANAGED_INSTALL_ROOT ?? `${process.env.HOME}/.pi/agent/install`;
const PIROOT =
	process.env.PI_PKG_ROOT ??
	`${PI_INSTALL}/releases/${readFileSync(`${PI_INSTALL}/current-version`, "utf8").trim()}/node_modules/@earendil-works/pi-coding-agent`;
const require = createRequire(`${PIROOT}/`);
const { createJiti } = require("jiti");
// moduleCache off: config is read at module scope, so each setup() must
// re-evaluate the module to pick up env changes made by a test.
const jiti = createJiti(import.meta.url, {
	alias: { "@earendil-works/pi-coding-agent": PIROOT },
	moduleCache: false,
});

const ENTRY = new URL("./index.ts", import.meta.url).pathname;
const DIR = mkdtempSync(join(tmpdir(), "rm-session-"));
const NAME_HANDOFF = "__piPendingSessionName";

let pass = 0;
let fail = 0;
const check = (name, cond) => {
	console.log(`${cond ? "PASS" : "FAIL"}  ${name}`);
	cond ? pass++ : fail++;
};

let seq = 0;
/** A stand-in session jsonl on disk; contents are irrelevant to the unlink. */
function writeSession() {
	const file = join(DIR, `2026-01-01T00-00-00-000Z_session-${seq++}.jsonl`);
	writeFileSync(file, '{"type":"session"}\n');
	return file;
}

/** Fresh extension instance + mocks. `file: null` models an ephemeral session. */
async function setup({
	file,
	name = "merged work",
	hasUI = true,
	answer = true,
	cancelled = false,
	newSessionThrows = false,
} = {}) {
	globalThis[NAME_HANDOFF] = undefined;
	const sessionFile = file === undefined ? writeSession() : file;
	const mod = await jiti.import(ENTRY, { default: true });
	const h = {};
	const state = {
		sessionFile,
		commands: {},
		notices: [],
		confirms: [],
		shutdowns: 0,
		newSessions: 0,
		// Names appended by setup() into the replacement session, plus the
		// handoff value force-session-name would have seen.
		appliedNames: [],
		handoffDuringSwitch: undefined,
		nextNotices: [],
		newFile: undefined,
	};
	const pi = {
		on: (event, fn) => {
			h[event] = fn;
		},
		registerCommand: (cmd, options) => {
			state.commands[cmd] = options;
		},
	};
	mod(pi);

	const ctx = {
		hasUI,
		mode: hasUI ? "tui" : "print",
		sessionManager: {
			getSessionFile: () => state.sessionFile ?? undefined,
			getSessionName: () => name ?? undefined,
		},
		ui: {
			notify: (message, type) => state.notices.push({ message, type }),
			confirm: async (title, message) => {
				state.confirms.push({ title, message });
				return answer;
			},
		},
		shutdown: () => state.shutdowns++,
		/** Mirrors AgentSessionRuntime.newSession(): teardown → setup → withSession. */
		newSession: async (options) => {
			state.newSessions++;
			state.handoffDuringSwitch = globalThis[NAME_HANDOFF];
			if (newSessionThrows) throw new Error("boom");
			if (cancelled) return { cancelled: true };
			state.newFile = writeSession();
			h.session_shutdown?.(
				{ type: "session_shutdown", reason: "new", targetSessionFile: state.newFile },
				ctx,
			);
			let applied;
			await options?.setup?.({
				getSessionName: () => applied,
				appendSessionInfo: (value) => {
					applied = value;
					state.appliedNames.push(value);
				},
			});
			await options?.withSession?.({
				...ctx,
				ui: {
					...ctx.ui,
					notify: (message, type) => state.nextNotices.push({ message, type }),
				},
			});
			return { cancelled: false };
		},
	};
	return { h, ctx, state, sessionFile };
}

const run = (state, ctx, args = "") => state.commands["rm-session"].handler(args, ctx);
const quit = (h, ctx) => h.session_shutdown({ type: "session_shutdown", reason: "quit" }, ctx);

// 1. the default path: clear the history, keep the name, stay in pi
{
	const { ctx, state, sessionFile } = await setup();
	check("command: registered as /rm-session", typeof state.commands["rm-session"]?.handler === "function");
	check("command: described as clearing history", /clear/i.test(state.commands["rm-session"].description ?? ""));

	await run(state, ctx);
	check("reset: confirmed first", state.confirms.length === 1);
	check("reset: dialog names the session", state.confirms[0].message.includes("merged work"));
	check("reset: dialog shows the file", state.confirms[0].message.includes(sessionFile));
	check("reset: no quit", state.shutdowns === 0);
	check("reset: new session started", state.newSessions === 1);
	check("reset: old history deleted", !existsSync(sessionFile));
	check("reset: replacement session survives", existsSync(state.newFile));
	check("reset: name carried into setup()", state.appliedNames.join() === "merged work");
	check("reset: name handed off before the switch", state.handoffDuringSwitch === "merged work");
	check("reset: handoff cleared afterwards", globalThis[NAME_HANDOFF] === undefined);
	check("reset: confirmed in the new session", /History cleared/.test(state.nextNotices.at(-1)?.message ?? ""));
}

// 2. force-session-name already applied the handoff — do not name it twice
{
	const { ctx, state } = await setup();
	const original = ctx.newSession;
	ctx.newSession = async (options) =>
		original({
			...options,
			setup: (sm) => options.setup({ ...sm, getSessionName: () => "merged work" }),
		});
	await run(state, ctx);
	check("reset: skips a redundant rename", state.appliedNames.length === 0);
}

// 3. declining the dialog changes nothing
{
	const { ctx, state, sessionFile } = await setup({ answer: false });
	await run(state, ctx);
	check("declined: no switch, no quit", state.newSessions === 0 && state.shutdowns === 0);
	check("declined: file kept", existsSync(sessionFile));
}

// 4. a cancelled switch (e.g. force-session-name vetoing) keeps the history
{
	const { h, ctx, state, sessionFile } = await setup({ cancelled: true });
	await run(state, ctx);
	check("cancelled: file kept", existsSync(sessionFile));
	check("cancelled: warned", state.notices.at(-1)?.type === "warning");
	// disarmed, so an unrelated later teardown must not take the file
	h.session_shutdown({ type: "session_shutdown", reason: "new", targetSessionFile: "/tmp/x" }, ctx);
	check("cancelled: disarmed", existsSync(sessionFile));
}

// 5. newSession throwing is reported, not swallowed, and disarms
{
	const { h, ctx, state, sessionFile } = await setup({ newSessionThrows: true });
	await run(state, ctx);
	check("error: reported", state.notices.at(-1)?.type === "error");
	h.session_shutdown({ type: "session_shutdown", reason: "new", targetSessionFile: "/tmp/x" }, ctx);
	check("error: file kept", existsSync(sessionFile));
}

// 6. an ephemeral session has no file, but its history can still be cleared
{
	const { ctx, state } = await setup({ file: null });
	await run(state, ctx);
	check("ephemeral: reset still works", state.newSessions === 1);
	check("ephemeral: nothing to delete, no error", !state.notices.some((n) => n.type === "error"));
}

// 7. --quit keeps the original behaviour: delete the file and exit
{
	const { h, ctx, state, sessionFile } = await setup();
	await run(state, ctx, "--quit");
	check("quit: dialog says pi will quit", /pi will quit/.test(state.confirms[0].message));
	check("quit: shutdown requested", state.shutdowns === 1 && state.newSessions === 0);
	check("quit: file still present until exit", existsSync(sessionFile));
	quit(h, ctx);
	check("quit: file deleted on exit", !existsSync(sessionFile));
}

// 8. session replacement must not take the file from a quit-armed session
for (const reason of ["new", "resume", "fork"]) {
	const { h, ctx, state, sessionFile } = await setup();
	await run(state, ctx, "--quit");
	h.session_shutdown({ type: "session_shutdown", reason, targetSessionFile: "/tmp/other.jsonl" }, ctx);
	check(`quit + ${reason}: file survives the switch`, existsSync(sessionFile));
}

// 9. a plain quit that was never armed deletes nothing
{
	const { h, ctx, sessionFile } = await setup();
	quit(h, ctx);
	check("unarmed: quitting normally keeps the file", existsSync(sessionFile));
}

// 10. arming is per-session: a reload disarms rather than deleting later
{
	const { h, ctx, state, sessionFile } = await setup();
	await run(state, ctx, "--quit");
	h.session_shutdown({ type: "session_shutdown", reason: "reload" }, ctx);
	check("reload: file survives", existsSync(sessionFile));
	quit(h, ctx);
	check("reload: disarmed, later quit is harmless", existsSync(sessionFile));
}

// 11. ephemeral + --quit: nothing on disk to retire
{
	const { ctx, state } = await setup({ file: null });
	await run(state, ctx, "--quit");
	check("ephemeral + --quit: warned", state.notices.at(-1)?.type === "warning");
	check("ephemeral + --quit: no confirm, no shutdown", state.confirms.length === 0 && state.shutdowns === 0);
}

// 12. without a UI to confirm in, --force is required
{
	const { ctx, state } = await setup({ hasUI: false });
	await run(state, ctx);
	check("no UI: refused with an error", state.notices.at(-1)?.type === "error");
	check("no UI: nothing happened", state.newSessions === 0 && state.shutdowns === 0);
}
{
	const { ctx, state, sessionFile } = await setup({ hasUI: false });
	await run(state, ctx, "--force");
	check("no UI: --force skips the dialog", state.confirms.length === 0 && state.newSessions === 1);
	check("no UI: --force clears the history", !existsSync(sessionFile));
	check("no UI: name still carried over", state.appliedNames.join() === "merged work");
}

// 13. config: mode, confirmation, command name, and the kill switch
{
	process.env.PI_RM_SESSION_MODE = "quit";
	const { h, ctx, state, sessionFile } = await setup();
	check("mode=quit: description mentions quitting", /quit/i.test(state.commands["rm-session"].description ?? ""));
	await run(state, ctx);
	check("mode=quit: quits by default", state.shutdowns === 1 && state.newSessions === 0);
	quit(h, ctx);
	check("mode=quit: deleted", !existsSync(sessionFile));

	const second = await setup();
	await run(second.state, second.ctx, "--reset");
	check("mode=quit: --reset overrides back", second.state.newSessions === 1 && second.state.shutdowns === 0);
	delete process.env.PI_RM_SESSION_MODE;
}
{
	process.env.PI_RM_SESSION_CONFIRM = "off";
	const { ctx, state, sessionFile } = await setup();
	await run(state, ctx);
	check("confirm=off: no dialog", state.confirms.length === 0 && state.newSessions === 1);
	check("confirm=off: old history deleted", !existsSync(sessionFile));
	delete process.env.PI_RM_SESSION_CONFIRM;
}
{
	process.env.PI_RM_SESSION_COMMAND = "burn";
	const { state } = await setup();
	check("command name configurable", Object.keys(state.commands).join() === "burn");
	delete process.env.PI_RM_SESSION_COMMAND;
}
{
	process.env.PI_RM_SESSION = "off";
	const { h, state } = await setup();
	check("disabled: registers nothing", Object.keys(state.commands).length === 0 && Object.keys(h).length === 0);
	delete process.env.PI_RM_SESSION;
}

// 14. an unnamed session resets too, with nothing to carry over
{
	const { ctx, state } = await setup({ name: null });
	await run(state, ctx);
	check("unnamed: reset works", state.newSessions === 1);
	check("unnamed: nothing handed off", state.handoffDuringSwitch === undefined);
	check("unnamed: no name applied", state.appliedNames.length === 0);
}

// 15. a file that vanished underneath us is not an error
{
	const { h, ctx, state, sessionFile } = await setup();
	await run(state, ctx, "--quit");
	state.sessionFile = sessionFile;
	quit(h, ctx);
	check("missing file: first quit removes it", !existsSync(sessionFile));
	// second shutdown for the same (now absent) file must not throw
	await run(state, ctx, "--quit");
	quit(h, ctx);
	check("missing file: deleting again is a no-op", !existsSync(sessionFile));
}

console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail === 0 ? 0 : 1);
