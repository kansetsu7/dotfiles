/**
 * Test harness for force-session-name. Loads the extension via jiti (the same
 * loader pi uses) with a mock ExtensionAPI/ExtensionContext and drives the
 * session_before_switch / session_before_fork / session_start / input /
 * session_info_changed flows.
 *
 *   node test.mjs
 */
import { mkdtempSync, writeFileSync } from "node:fs";
import { createRequire } from "node:module";
import { tmpdir } from "node:os";
import { join } from "node:path";

const PIROOT =
	"/root/npm-global/lib/node_modules/@earendil-works/pi-coding-agent";
const require = createRequire(`${PIROOT}/`);
const { createJiti } = require("jiti");
// moduleCache off: config is read at module scope, so each setup() must
// re-evaluate the module to pick up env changes made by a test.
const jiti = createJiti(import.meta.url, {
	alias: { "@earendil-works/pi-coding-agent": PIROOT },
	moduleCache: false,
});

const ENTRY = new URL("./index.ts", import.meta.url).pathname;

let pass = 0;
let fail = 0;
const check = (name, cond) => {
	console.log(`${cond ? "PASS" : "FAIL"}  ${name}`);
	cond ? pass++ : fail++;
};

// SessionManager.list() is called for real, so point it at throwaway dirs.
// Empty dir => nothing to resume; writeSession() makes one resumable.
const EMPTY_SESSION_DIR = mkdtempSync(join(tmpdir(), "fsn-empty-"));
const DEFAULT_CWD = mkdtempSync(join(tmpdir(), "fsn-cwd-"));

/**
 * Write a session jsonl that SessionManager.list() reports as resumable.
 * `cwd` must match the context cwd: list() filters by it for custom dirs.
 */
function writeSession(dir, cwd, id = "11111111-2222-3333-4444-555555555555") {
	const file = join(dir, `2026-01-01T00-00-00-000Z_${id}.jsonl`);
	const lines = [
		{ type: "session", version: 3, id, timestamp: "2026-01-01T00:00:00.000Z", cwd },
		{
			type: "message",
			id: "m1",
			parentId: null,
			timestamp: "2026-01-01T00:00:01.000Z",
			message: {
				role: "user",
				content: [{ type: "text", text: "previous work" }],
				timestamp: 1,
			},
		},
	];
	writeFileSync(file, `${lines.map((l) => JSON.stringify(l)).join("\n")}\n`);
	return file;
}

/** Fresh extension instance + mocks. `answers` are consumed per ui.input(). */
async function setup({
	answers = [],
	entries = [],
	name,
	hasUI = true,
	choices = [],
	cwd = DEFAULT_CWD,
	sessionDir = EMPTY_SESSION_DIR,
} = {}) {
	const mod = await jiti.import(ENTRY, { default: true });
	const h = {};
	const state = {
		name,
		prompts: [],
		notices: [],
		status: undefined,
		selects: [],
		editorText: "",
	};
	const pi = {
		on: (event, fn) => {
			h[event] = fn;
		},
		getSessionName: () => state.name,
		setSessionName: (n) => {
			state.name = n;
		},
	};
	mod(pi);
	const ctx = {
		hasUI,
		cwd,
		sessionManager: {
			getEntries: () => entries,
			getSessionDir: () => sessionDir,
			getSessionId: () => "current-session-id",
			getSessionFile: () => join(sessionDir, "current.jsonl"),
		},
		ui: {
			input: async (title, placeholder) => {
				state.prompts.push({ title, placeholder });
				return answers.shift();
			},
			select: async (title, options) => {
				state.selects.push({ title, options });
				return choices.shift();
			},
			setEditorText: (text) => {
				state.editorText = text;
			},
			notify: (msg, type) => state.notices.push({ msg, type }),
			setStatus: (_key, text) => {
				state.status = text;
			},
		},
	};
	return { h, ctx, state };
}

// 1. /new asks before the switch, and the name lands on the new session
{
	const { h, ctx, state } = await setup({ answers: ["Refactor auth"] });
	const res = await h.session_before_switch(
		{ type: "session_before_switch", reason: "new" },
		ctx,
	);
	check("new: prompts once", state.prompts.length === 1);
	check("new: switch not cancelled", res?.cancel !== true);
	check("new: name not set before the switch", state.name === undefined);

	await h.session_start({ type: "session_start", reason: "new" }, ctx);
	check("new: name applied on session_start", state.name === "Refactor auth");
	check("new: no second prompt", state.prompts.length === 1);
	check("new: no warning status", state.status === undefined);
}

// 2. fork prompts even though the name is inherited, and suggests a variant
{
	const { h, ctx, state } = await setup({
		name: "Parent task",
		answers: ["Try redis cache"],
	});
	const res = await h.session_before_fork(
		{ type: "session_before_fork", entryId: "e1", position: "at" },
		ctx,
	);
	check("fork: prompts despite inherited name", state.prompts.length === 1);
	check(
		"fork: suggests parent-derived name",
		state.prompts[0].placeholder === "Parent task (fork)",
	);
	check("fork: not cancelled", res?.cancel !== true);
	check("fork: parent keeps its name", state.name === "Parent task");

	await h.session_start({ type: "session_start", reason: "fork" }, ctx);
	check("fork: name replaced on the fork", state.name === "Try redis cache");
}

// 2b. a pending name never leaks into an unrelated later switch
{
	const { h, ctx, state } = await setup({ answers: ["Abandoned", "Real name"] });
	await h.session_before_switch({ type: "session_before_switch", reason: "new" }, ctx);
	// the switch never completes; a resume happens instead
	await h.session_before_switch(
		{ type: "session_before_switch", reason: "resume" },
		ctx,
	);
	await h.session_start({ type: "session_start", reason: "resume" }, ctx);
	check("leak: abandoned name not applied to the resumed session", state.name === undefined);
	check("leak: resume is not prompted by default", state.prompts.length === 1);
}

// 3. too-short names are rejected and re-prompted
{
	const { h, ctx, state } = await setup({ answers: ["ab", "  ", "Fix CI"] });
	await h.session_before_switch({ type: "session_before_switch", reason: "new" }, ctx);
	await h.session_start({ type: "session_start", reason: "new" }, ctx);
	check("short: re-prompts until valid", state.prompts.length === 3);
	check("short: final name accepted", state.name === "Fix CI");
	check(
		"short: warned about minimum length",
		state.notices.some((n) => n.type === "warning"),
	);
}

// 3b. escaping cancels the switch/fork instead of stranding an unnamed session
{
	const { h, ctx, state } = await setup({ answers: [undefined] });
	const res = await h.session_before_switch(
		{ type: "session_before_switch", reason: "new" },
		ctx,
	);
	check("cancel: /new escape cancels the switch", res?.cancel === true);
	check("cancel: no block armed (we never left)", state.status === undefined);

	const { h: h2, ctx: c2 } = await setup({ answers: [undefined], name: "Parent" });
	const res2 = await h2.session_before_fork(
		{ type: "session_before_fork", entryId: "e1", position: "at" },
		c2,
	);
	check("cancel: fork escape cancels the fork", res2?.cancel === true);

	// BLOCK=off means never obstruct: proceed unnamed instead of cancelling
	process.env.PI_FORCE_SESSION_NAME_BLOCK = "off";
	const { h: h3, ctx: c3, state: s3 } = await setup({ answers: [undefined] });
	const res3 = await h3.session_before_switch(
		{ type: "session_before_switch", reason: "new" },
		c3,
	);
	check("cancel: BLOCK=off lets the switch through", res3?.cancel !== true);
	check(
		"cancel: BLOCK=off still warns",
		s3.notices.some((n) => n.type === "warning"),
	);
	await h3.session_start({ type: "session_start", reason: "new" }, c3);
	check("cancel: BLOCK=off does not re-ask in the new session", s3.prompts.length === 1);
	delete process.env.PI_FORCE_SESSION_NAME_BLOCK;
}

// 4. escaping the startup prompt defers, then input is blocked until named
//    (startup has no `before` event to cancel, so the gate still applies)
{
	const { h, ctx, state } = await setup({ answers: [undefined] });
	await h.session_start({ type: "session_start", reason: "startup" }, ctx);
	check("escape: marked unnamed in status", /unnamed/.test(state.status ?? ""));

	// slash commands still pass through
	const slash = await h.input(
		{ type: "input", text: "/name Something", source: "interactive" },
		ctx,
	);
	check("escape: slash commands not blocked", slash === undefined);

	// a normal message re-prompts; escaping again blocks it
	const before = state.prompts.length;
	const blocked = await h.input(
		{ type: "input", text: "do the thing", source: "interactive" },
		ctx,
	);
	check("escape: re-prompts on message", state.prompts.length > before);
	check("escape: message blocked", blocked?.action === "handled");

	// answering the gate prompt lets the next message through
	const { h: h2, ctx: ctx2, state: s2 } = await setup({
		answers: [undefined, "Named later"],
	});
	await h2.session_start({ type: "session_start", reason: "startup" }, ctx2);
	const allowed = await h2.input(
		{ type: "input", text: "go", source: "interactive" },
		ctx2,
	);
	check("gate: naming unblocks message", allowed === undefined);
	check("gate: name persisted", s2.name === "Named later");
	check("gate: status cleared", s2.status === undefined);
}

// 4b. escaping, then switching session, drops the block (it belonged to the
//     session we left) — `/resume` must not inherit it.
{
	const { h, ctx, state } = await setup({ answers: [undefined] });
	await h.session_start({ type: "session_start", reason: "startup" }, ctx);
	check("switch: blocked before resuming", /unnamed/.test(state.status ?? ""));

	state.name = "Yesterday's work";
	await h.session_start({ type: "session_start", reason: "resume" }, ctx);
	check("switch: status cleared on resume", state.status === undefined);

	const res = await h.input(
		{ type: "input", text: "carry on", source: "interactive" },
		ctx,
	);
	check("switch: resumed session not blocked", res === undefined);

	// but a reload re-enters the same unnamed session, so the block stays
	const { h: h2, ctx: c2, state: s2 } = await setup({ answers: [undefined, undefined] });
	await h2.session_start({ type: "session_start", reason: "startup" }, c2);
	await h2.session_start(
		{ type: "session_start", reason: "reload" },
		c2,
	);
	check("switch: reload keeps the block", /unnamed/.test(s2.status ?? ""));
}

// 5. /name via session_info_changed clears the block
{
	const { h, ctx, state } = await setup({ answers: [undefined] });
	await h.session_start({ type: "session_start", reason: "startup" }, ctx);
	h.session_info_changed({ type: "session_info_changed", name: "Manual name" }, ctx);
	check("session_info_changed: status cleared", state.status === undefined);
	const res = await h.input(
		{ type: "input", text: "go", source: "interactive" },
		ctx,
	);
	check("session_info_changed: input unblocked", res === undefined);
}

// 6. skipped where it cannot work / is not wanted
{
	const { h, ctx, state } = await setup({ answers: ["x"], hasUI: false });
	const res = await h.session_before_switch(
		{ type: "session_before_switch", reason: "new" },
		ctx,
	);
	await h.session_start({ type: "session_start", reason: "new" }, ctx);
	check("no UI: never prompts", state.prompts.length === 0);
	check("no UI: never cancels", res?.cancel !== true);

	const { h: h2, ctx: c2, state: s2 } = await setup({ answers: ["x"] });
	await h2.session_start({ type: "session_start", reason: "resume" }, c2);
	check("resume: not in default reasons", s2.prompts.length === 0);

	// REASONS opt-out must skip the pre-switch prompt too
	process.env.PI_FORCE_SESSION_NAME_REASONS = "startup";
	const { h: h3, ctx: c3, state: s3 } = await setup({ answers: ["x"] });
	const res3 = await h3.session_before_switch(
		{ type: "session_before_switch", reason: "new" },
		c3,
	);
	const res4 = await h3.session_before_fork(
		{ type: "session_before_fork", entryId: "e1", position: "at" },
		c3,
	);
	check(
		"REASONS opt-out: no pre-switch prompt or cancel",
		s3.prompts.length === 0 && res3?.cancel !== true && res4?.cancel !== true,
	);
	delete process.env.PI_FORCE_SESSION_NAME_REASONS;

	const { h: h5, ctx: c5, state: s5 } = await setup({ answers: ["x"], name: "Kept" });
	await h5.session_start({ type: "session_start", reason: "startup" }, c5);
	check("already named: no prompt", s5.prompts.length === 0 && s5.name === "Kept");
}

// 7. startup (default reason): only for an empty session
{
	const { h, ctx, state } = await setup({ answers: ["Fresh start"], entries: [] });
	await h.session_start({ type: "session_start", reason: "startup" }, ctx);
	check("startup: prompts on empty session", state.name === "Fresh start");

	// pi writes model_change / thinking_level_change before extensions bind,
	// so a fresh session is never entry-free — it is still "empty".
	const { h: hb, ctx: cb, state: sb } = await setup({
		answers: ["Fresh again"],
		entries: [{ type: "model_change" }, { type: "thinking_level_change" }],
	});
	await hb.session_start({ type: "session_start", reason: "startup" }, cb);
	check("startup: bookkeeping entries still count as empty", sb.name === "Fresh again");

	const { h: h2, ctx: c2, state: s2 } = await setup({
		answers: ["nope"],
		entries: [{ type: "model_change" }, { type: "message" }],
	});
	await h2.session_start({ type: "session_start", reason: "startup" }, c2);
	check("startup: skips continued session", s2.prompts.length === 0);

	process.env.PI_FORCE_SESSION_NAME_REASONS = "new,fork";
	const { h: h3, ctx: c3, state: s3 } = await setup({ answers: ["x"], entries: [] });
	await h3.session_start({ type: "session_start", reason: "startup" }, c3);
	check("startup: opt-out via REASONS", s3.prompts.length === 0);
	delete process.env.PI_FORCE_SESSION_NAME_REASONS;
}

// 7b. startup picker: new vs resume — only when there is something to resume
{
	// nothing on disk: a one-option menu is noise, so go straight to naming
	const { h: h0, ctx: c0, state: s0 } = await setup({
		answers: ["Nothing to resume"],
	});
	await h0.session_start({ type: "session_start", reason: "startup" }, c0);
	check("picker: skipped when no resumable session exists", s0.selects.length === 0);
	check("picker: still names the session", s0.name === "Nothing to resume");

	const RESUMABLE = mkdtempSync(join(tmpdir(), "fsn-sessions-"));
	const RESUMABLE_CWD = mkdtempSync(join(tmpdir(), "fsn-cwd-"));
	writeSession(RESUMABLE, RESUMABLE_CWD);
	const withHistory = (opts) =>
		setup({ ...opts, cwd: RESUMABLE_CWD, sessionDir: RESUMABLE });

	const { h, ctx, state } = await withHistory({
		choices: ["New session"],
		answers: ["Named after picking"],
	});
	await h.session_start({ type: "session_start", reason: "startup" }, ctx);
	check("picker: offers both options", state.selects[0]?.options.length === 2);
	check("picker: new leads to the name prompt", state.name === "Named after picking");

	// resume hands off to the built-in /resume; extensions cannot switch
	// sessions from an event handler.
	const { h: h2, ctx: c2, state: s2 } = await withHistory({
		choices: ["Resume a previous session"],
		answers: [undefined], // escapes the later gate prompt
	});
	await h2.session_start({ type: "session_start", reason: "startup" }, c2);
	check("picker: resume prefills /resume", s2.editorText === "/resume");
	check("picker: resume skips the name prompt", s2.prompts.length === 0);
	check("picker: resume passes the slash command", 
		(await h2.input({ type: "input", text: "/resume", source: "interactive" }, c2)) ===
			undefined);

	// abandoning the resume and typing instead still demands a name
	const blocked = await h2.input(
		{ type: "input", text: "actually, do this", source: "interactive" },
		c2,
	);
	check(
		"picker: abandoned resume re-prompts and blocks",
		s2.prompts.length === 1 && blocked?.action === "handled",
	);

	// escaping the picker is not an opt-out
	const { h: h3, ctx: c3, state: s3 } = await withHistory({
		choices: [undefined],
		answers: ["Escaped picker"],
	});
	await h3.session_start({ type: "session_start", reason: "startup" }, c3);
	check("picker: escape falls through to naming", s3.name === "Escaped picker");

	// /new already states the intent, so no picker there
	const { h: h4, ctx: c4, state: s4 } = await withHistory({
		answers: ["Straight to name"],
	});
	await h4.session_before_switch({ type: "session_before_switch", reason: "new" }, c4);
	await h4.session_start({ type: "session_start", reason: "new" }, c4);
	check(
		"picker: /new skips the picker",
		s4.selects.length === 0 && s4.name === "Straight to name",
	);

	process.env.PI_FORCE_SESSION_NAME_PICKER = "off";
	const { h: h5, ctx: c5, state: s5 } = await withHistory({ answers: ["No picker"] });
	await h5.session_start({ type: "session_start", reason: "startup" }, c5);
	check(
		"picker: opt-out asks for a name directly",
		s5.selects.length === 0 && s5.name === "No picker",
	);
	delete process.env.PI_FORCE_SESSION_NAME_PICKER;
}

// 8. kill switch
{
	process.env.PI_FORCE_SESSION_NAME = "off";
	const { h, ctx } = await setup({ answers: ["x"] });
	check("disabled: registers no handlers", Object.keys(h).length === 0);
	delete process.env.PI_FORCE_SESSION_NAME;
	void ctx;
}

console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail === 0 ? 0 : 1);
