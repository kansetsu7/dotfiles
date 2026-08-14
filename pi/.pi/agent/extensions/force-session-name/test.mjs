/**
 * Test harness for force-session-name. Loads the extension via jiti (the same
 * loader pi uses) with a mock ExtensionAPI/ExtensionContext and drives the
 * session_start / input / session_info_changed flows.
 *
 *   node test.mjs
 */
import { createRequire } from "node:module";

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

/** Fresh extension instance + mocks. `answers` are consumed per ui.input(). */
async function setup({ answers = [], entries = [], name, hasUI = true } = {}) {
	const mod = await jiti.import(ENTRY, { default: true });
	const h = {};
	const state = { name, prompts: [], notices: [], status: undefined };
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
		sessionManager: { getEntries: () => entries },
		ui: {
			input: async (title, placeholder) => {
				state.prompts.push({ title, placeholder });
				return answers.shift();
			},
			notify: (msg, type) => state.notices.push({ msg, type }),
			setStatus: (_key, text) => {
				state.status = text;
			},
		},
	};
	return { h, ctx, state };
}

// 1. /new prompts and sets the name
{
	const { h, ctx, state } = await setup({ answers: ["Refactor auth"] });
	await h.session_start({ type: "session_start", reason: "new" }, ctx);
	check("new: prompts once", state.prompts.length === 1);
	check("new: name is set", state.name === "Refactor auth");
	check("new: no warning status", state.status === undefined);
}

// 2. fork prompts even though the name is inherited, and suggests a variant
{
	const { h, ctx, state } = await setup({
		name: "Parent task",
		answers: ["Try redis cache"],
	});
	await h.session_start({ type: "session_start", reason: "fork" }, ctx);
	check("fork: prompts despite inherited name", state.prompts.length === 1);
	check(
		"fork: suggests parent-derived name",
		state.prompts[0].placeholder === "Parent task (fork)",
	);
	check("fork: name replaced", state.name === "Try redis cache");
}

// 3. too-short names are rejected and re-prompted
{
	const { h, ctx, state } = await setup({ answers: ["ab", "  ", "Fix CI"] });
	await h.session_start({ type: "session_start", reason: "new" }, ctx);
	check("short: re-prompts until valid", state.prompts.length === 3);
	check("short: final name accepted", state.name === "Fix CI");
	check(
		"short: warned about minimum length",
		state.notices.some((n) => n.type === "warning"),
	);
}

// 4. escaping defers, then interactive input is blocked until named
{
	const { h, ctx, state } = await setup({ answers: [undefined] });
	await h.session_start({ type: "session_start", reason: "new" }, ctx);
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
	await h2.session_start({ type: "session_start", reason: "new" }, ctx2);
	const allowed = await h2.input(
		{ type: "input", text: "go", source: "interactive" },
		ctx2,
	);
	check("gate: naming unblocks message", allowed === undefined);
	check("gate: name persisted", s2.name === "Named later");
	check("gate: status cleared", s2.status === undefined);
}

// 5. /name via session_info_changed clears the block
{
	const { h, ctx, state } = await setup({ answers: [undefined] });
	await h.session_start({ type: "session_start", reason: "new" }, ctx);
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
	await h.session_start({ type: "session_start", reason: "new" }, ctx);
	check("no UI: never prompts", state.prompts.length === 0);

	const { h: h2, ctx: c2, state: s2 } = await setup({ answers: ["x"] });
	await h2.session_start({ type: "session_start", reason: "resume" }, c2);
	check("resume: not in default reasons", s2.prompts.length === 0);

	const { h: h3, ctx: c3, state: s3 } = await setup({ answers: ["x"], name: "Kept" });
	await h3.session_start({ type: "session_start", reason: "new" }, c3);
	check("already named: no prompt", s3.prompts.length === 0 && s3.name === "Kept");
}

// 7. startup opt-in: only for an empty session
{
	process.env.PI_FORCE_SESSION_NAME_REASONS = "startup,new,fork";
	const { h, ctx, state } = await setup({ answers: ["Fresh start"], entries: [] });
	await h.session_start({ type: "session_start", reason: "startup" }, ctx);
	check("startup opt-in: prompts on empty session", state.name === "Fresh start");

	const { h: h2, ctx: c2, state: s2 } = await setup({
		answers: ["nope"],
		entries: [{ type: "message" }],
	});
	await h2.session_start({ type: "session_start", reason: "startup" }, c2);
	check("startup opt-in: skips continued session", s2.prompts.length === 0);
	delete process.env.PI_FORCE_SESSION_NAME_REASONS;
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
