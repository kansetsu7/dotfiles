/**
 * Test harness for rm-session. Loads the extension via jiti (the same loader
 * pi uses) with a mock ExtensionAPI/ExtensionCommandContext, and drives the
 * command → shutdown → session_shutdown flow against real throwaway session
 * files, so the deletion itself is exercised rather than mocked.
 *
 *   node test.mjs
 */
import { existsSync, mkdtempSync, writeFileSync } from "node:fs";
import { createRequire } from "node:module";
import { tmpdir } from "node:os";
import { join } from "node:path";

const PIROOT = "/root/npm-global/lib/node_modules/@earendil-works/pi-coding-agent";
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
async function setup({ file, name = "merged work", hasUI = true, answer = true } = {}) {
	const sessionFile = file === undefined ? writeSession() : file;
	const mod = await jiti.import(ENTRY, { default: true });
	const h = {};
	const state = { sessionFile, commands: {}, notices: [], confirms: [], shutdowns: 0 };
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
			getSessionName: () => name,
		},
		ui: {
			notify: (message, type) => state.notices.push({ message, type }),
			confirm: async (title, message) => {
				state.confirms.push({ title, message });
				return answer;
			},
		},
		shutdown: () => state.shutdowns++,
	};
	return { h, ctx, state, sessionFile };
}

const run = (state, ctx, args = "") => state.commands["rm-session"].handler(args, ctx);
const quit = (h, ctx) => h.session_shutdown({ type: "session_shutdown", reason: "quit" }, ctx);

// 1. the happy path: confirm, quit, and the file is gone by shutdown
{
	const { h, ctx, state, sessionFile } = await setup();
	check("command: registered as /rm-session", typeof state.commands["rm-session"]?.handler === "function");
	check("command: described", /delete/i.test(state.commands["rm-session"].description ?? ""));

	await run(state, ctx);
	check("confirm: asked before anything happens", state.confirms.length === 1);
	check("confirm: shows the file path", state.confirms[0].message.includes(sessionFile));
	check("confirm: shows the session name", state.confirms[0].message.includes("merged work"));
	check("armed: shutdown requested", state.shutdowns === 1);
	check("armed: file still present until exit", existsSync(sessionFile));

	quit(h, ctx);
	check("quit: file deleted", !existsSync(sessionFile));
}

// 2. declining the dialog leaves both the file and the session alone
{
	const { h, ctx, state, sessionFile } = await setup({ answer: false });
	await run(state, ctx);
	check("declined: no shutdown", state.shutdowns === 0);
	quit(h, ctx);
	check("declined: file kept", existsSync(sessionFile));
}

// 3. session replacement (/new, /resume, /fork) must not take the file
for (const reason of ["new", "resume", "fork"]) {
	const { h, ctx, state, sessionFile } = await setup();
	await run(state, ctx);
	h.session_shutdown({ type: "session_shutdown", reason, targetSessionFile: "/tmp/other.jsonl" }, ctx);
	check(`${reason}: file survives the switch`, existsSync(sessionFile));
}

// 4. a plain quit that was never armed deletes nothing
{
	const { h, ctx, sessionFile } = await setup();
	quit(h, ctx);
	check("unarmed: quitting normally keeps the file", existsSync(sessionFile));
}

// 5. arming is per-session: a reload disarms rather than deleting later
{
	const { h, ctx, state, sessionFile } = await setup();
	await run(state, ctx);
	h.session_shutdown({ type: "session_shutdown", reason: "reload" }, ctx);
	check("reload: file survives", existsSync(sessionFile));
	quit(h, ctx);
	check("reload: disarmed, later quit is harmless", existsSync(sessionFile));
}

// 6. ephemeral sessions (--no-session) have nothing to delete
{
	const { ctx, state } = await setup({ file: null });
	await run(state, ctx);
	check("ephemeral: warned", state.notices.at(-1)?.type === "warning");
	check("ephemeral: no confirm, no shutdown", state.confirms.length === 0 && state.shutdowns === 0);
}

// 7. without a UI to confirm in, --force is required
{
	const { ctx, state } = await setup({ hasUI: false });
	await run(state, ctx);
	check("no UI: refused with an error", state.notices.at(-1)?.type === "error");
	check("no UI: no shutdown", state.shutdowns === 0);
}
{
	const { h, ctx, state, sessionFile } = await setup({ hasUI: false });
	await run(state, ctx, "--force");
	check("no UI: --force skips the dialog", state.confirms.length === 0 && state.shutdowns === 1);
	quit(h, ctx);
	check("no UI: --force deletes", !existsSync(sessionFile));
}

// 8. config: confirmation can be turned off, the command renamed, and the
//    whole extension disabled
{
	process.env.PI_RM_SESSION_CONFIRM = "off";
	const { h, ctx, state, sessionFile } = await setup();
	await run(state, ctx);
	check("confirm=off: no dialog", state.confirms.length === 0 && state.shutdowns === 1);
	quit(h, ctx);
	check("confirm=off: deleted", !existsSync(sessionFile));
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

// 9. a file that vanished underneath us is not an error
{
	const { h, ctx, state, sessionFile } = await setup();
	await run(state, ctx);
	state.sessionFile = sessionFile;
	quit(h, ctx);
	check("missing file: first quit removes it", !existsSync(sessionFile));
	// second shutdown for the same (now absent) file must not throw
	await run(state, ctx);
	quit(h, ctx);
	check("missing file: deleting again is a no-op", !existsSync(sessionFile));
}

console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail === 0 ? 0 : 1);
