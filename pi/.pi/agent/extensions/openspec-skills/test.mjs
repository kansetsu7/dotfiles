/**
 * Test harness for openspec-skills. Loads the extension via jiti (the same
 * loader pi uses) with a mock ExtensionAPI/ExtensionContext and drives the
 * session_start → resources_discover sequence pi runs in `bindExtensions()`.
 *
 *   node test.mjs
 */
import { createRequire } from "node:module";
import { existsSync, readFileSync } from "node:fs";

const PI_INSTALL =
	process.env.PI_MANAGED_INSTALL_ROOT ?? `${process.env.HOME}/.pi/agent/install`;
const PIROOT =
	process.env.PI_PKG_ROOT ??
	`${PI_INSTALL}/releases/${readFileSync(`${PI_INSTALL}/current-version`, "utf8").trim()}/node_modules/@earendil-works/pi-coding-agent`;
const require = createRequire(`${PIROOT}/`);
const { createJiti } = require("jiti");
// moduleCache off: PI_OPENSPEC* are read at module scope, so each setup() must
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

/**
 * Fresh extension instance + mocks.
 * `entries` seeds the session, as a resumed session would arrive.
 */
async function setup({ entries = [], tokens = 0 } = {}) {
	const mod = await jiti.import(ENTRY, { default: true });
	const h = {};
	const state = {
		entries: [...entries],
		notices: [],
		reloads: 0,
		commands: {},
	};
	const pi = {
		on: (event, fn) => {
			h[event] = fn;
		},
		registerCommand: (name, options) => {
			state.commands[name] = options;
		},
		appendEntry: (customType, data) => {
			state.entries.push({ type: "custom", customType, data });
		},
	};
	mod(pi);

	const ctx = {
		mode: "tui",
		hasUI: true,
		sessionManager: { getEntries: () => state.entries },
		getContextUsage: () => ({ tokens, contextWindow: 200000, percent: 0 }),
		ui: { notify: (message, type) => state.notices.push({ message, type }) },
		reload: async () => {
			state.reloads++;
		},
	};

	/** What pi does in bindExtensions(): session_start, then resources_discover. */
	const start = async (reason = "startup") => {
		await h.session_start?.({ type: "session_start", reason }, ctx);
		return (
			(await h.resources_discover?.({ type: "resources_discover", cwd: "/tmp", reason }, ctx)) ??
			undefined
		);
	};
	const run = (args = "") => state.commands.openspec?.handler(args, ctx);

	return { h, ctx, state, start, run };
}

const on = { type: "custom", customType: "openspec", data: { enabled: true } };
const off = { type: "custom", customType: "openspec", data: { enabled: false } };
const last = (arr) => arr[arr.length - 1];

// 0. the skills directory the extension points at actually exists
{
	const { start } = await setup({ entries: [on] });
	const result = await start();
	check("layout: skills directory resolved", !!result?.skillPaths?.[0]);
	check("layout: directory exists on disk", existsSync(result.skillPaths[0]));
	check(
		"layout: lives outside every discovery path",
		result.skillPaths[0].includes("skills-optional"),
	);
}

// 1. a session with no flag contributes nothing (the default is off)
{
	const { start } = await setup();
	check("default: no skills contributed", (await start()) === undefined);
}

// 2. a session that recorded "on" gets them back — on resume, with no reload
{
	const { start, state } = await setup({ entries: [on] });
	const result = await start("resume");
	check("resume on: skills contributed", result?.skillPaths?.length === 1);
	check("resume on: no reload needed", state.reloads === 0);
}

// 3. a session that recorded "off" stays off even after an earlier "on"
{
	const { start } = await setup({ entries: [on, off] });
	check("resume off: last flag wins", (await start("resume")) === undefined);
}

// 4. /openspec on records the flag, reloads, and survives the reload
{
	const { start, run, state } = await setup();
	await start();
	await run("on");
	check("toggle on: flag persisted", last(state.entries).data.enabled === true);
	check("toggle on: entry is custom (never LLM context)", last(state.entries).type === "custom");
	check("toggle on: reloaded once", state.reloads === 1);

	// the reload re-instantiates the extension against the same session
	const reloaded = await setup({ entries: state.entries });
	check(
		"toggle on: skills load after reload",
		(await reloaded.start("reload"))?.skillPaths?.length === 1,
	);
}

// 5. /openspec off reloads too — extendResources() merges and never prunes
{
	const { start, run, state } = await setup({ entries: [on] });
	await start();
	await run("off");
	check("toggle off: flag persisted", last(state.entries).data.enabled === false);
	check("toggle off: reload required to unload", state.reloads === 1);

	const reloaded = await setup({ entries: state.entries });
	check("toggle off: skills gone after reload", (await reloaded.start("reload")) === undefined);
}

// 6. no-op toggles do not reload (a reload would re-cache for nothing)
{
	const { start, run, state } = await setup();
	await start();
	await run("off");
	check("no-op: off when already off does not reload", state.reloads === 0);
	check("no-op: nothing written to the session", state.entries.length === 0);
	check("no-op: says so", /already off/.test(last(state.notices).message));
}

// 7. status and bad input report without touching anything
{
	const { start, run, state } = await setup({ entries: [on] });
	await start();
	await run("status");
	check("status: reports on", /openspec skills: on/.test(last(state.notices).message));
	await run("");
	check("status: bare command is status", /openspec skills: on/.test(last(state.notices).message));
	await run("sideways");
	check("usage: rejects junk", last(state.notices).type === "error");
	check("status: never reloads", state.reloads === 0);
}

// 8. toggle flips whatever the session currently says
{
	const { start, run, state } = await setup({ entries: [on] });
	await start();
	await run("toggle");
	check("toggle: flips on → off", last(state.entries).data.enabled === false);
}

// 9. a large session is warned about the re-cache before it happens
{
	const { start, run, state } = await setup({ tokens: 42_000 });
	await start();
	await run("on");
	const notice = state.notices.find((n) => n.type === "warning");
	check("cache: warns on a large session", !!notice && /re-caches ~42k/.test(notice.message));

	const small = await setup({ tokens: 500 });
	await small.start();
	await small.run("on");
	check("cache: quiet on a small session", !small.state.notices.some((n) => n.type === "warning"));
}

// 10. env overrides
{
	process.env.PI_OPENSPEC = "on";
	const { start } = await setup();
	check("env: PI_OPENSPEC=on defaults new sessions to on", (await start())?.skillPaths?.length === 1);

	const recorded = await setup({ entries: [off] });
	check(
		"env: a session that said off still wins",
		(await recorded.start("resume")) === undefined,
	);

	process.env.PI_OPENSPEC = "off";
	const disabled = await setup();
	check("env: PI_OPENSPEC=off registers nothing", Object.keys(disabled.h).length === 0);
	check("env: PI_OPENSPEC=off registers no command", disabled.state.commands.openspec === undefined);
	delete process.env.PI_OPENSPEC;

	process.env.PI_OPENSPEC_SKILLS = "/nonexistent/openspec";
	const missing = await setup({ entries: [on] });
	check("env: missing skills dir contributes nothing", (await missing.start()) === undefined);
	await missing.run("on");
	check("env: missing skills dir reports an error", last(missing.state.notices).type === "error");
	check("env: missing skills dir never reloads", missing.state.reloads === 0);
	delete process.env.PI_OPENSPEC_SKILLS;
}

console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail === 0 ? 0 : 1);
