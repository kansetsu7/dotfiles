/**
 * Test harness for session-header. Loads the extension via jiti (the same
 * loader pi uses) with a mock ExtensionAPI/ExtensionContext, captures the
 * header/widget component factory and renders it at various widths.
 *
 *   node test.mjs
 */
import { createRequire } from "node:module";

const PIROOT =
	"/root/npm-global/lib/node_modules/@earendil-works/pi-coding-agent";
const require = createRequire(`${PIROOT}/`);
const { createJiti } = require("jiti");
// truncateToWidth() emits ANSI resets around the ellipsis, so column counts
// have to come from the same helper pi uses, not String.length.
const { visibleWidth } = require(
	`${PIROOT}/node_modules/@earendil-works/pi-tui/dist/index.js`,
);
// moduleCache off: placement is read at module scope, so each setup() must
// re-evaluate the module to pick up env changes made by a test.
const jiti = createJiti(import.meta.url, {
	alias: {
		"@earendil-works/pi-coding-agent": PIROOT,
		"@earendil-works/pi-tui": `${PIROOT}/node_modules/@earendil-works/pi-tui`,
	},
	moduleCache: false,
});

const ENTRY = new URL("./index.ts", import.meta.url).pathname;

let pass = 0;
let fail = 0;
const check = (name, cond) => {
	console.log(`${cond ? "PASS" : "FAIL"}  ${name}`);
	cond ? pass++ : fail++;
};

/** Fresh extension instance + mocks. Theme colours are tagged, not ANSI. */
async function setup({ name, mode = "tui" } = {}) {
	const mod = await jiti.import(ENTRY, { default: true });
	const h = {};
	const state = { name, renders: 0, header: undefined, widgets: [] };
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

	const tui = { requestRender: () => state.renders++ };
	const theme = { fg: (color, text) => `<${color}>${text}</${color}>` };
	const ctx = {
		hasUI: true,
		mode,
		ui: {
			setHeader: (factory) => {
				state.header = factory?.(tui, theme);
			},
			setWidget: (key, factory, options) => {
				state.widgets.push({ key, options, component: factory?.(tui, theme) });
			},
		},
	};
	return { h, ctx, state };
}

/** Rendered line with the mock colour tags and real ANSI stripped. */
// biome-ignore lint/suspicious/noControlCharactersInRegex: matching ANSI resets
const plain = (line) => line.replace(/<\/?\w+>/g, "").replace(/\u001b\[[0-9;]*m/g, "");

// 1. the header renders the name, right-aligned
{
	const { h, ctx, state } = await setup({ name: "Refactor auth" });
	h.session_start({ type: "session_start", reason: "startup" }, ctx);
	check("header: component installed", state.header !== undefined);

	const [line] = state.header.render(40);
	check("header: single line", state.header.render(40).length === 1);
	check("header: shows the name", line.includes("Session: Refactor auth"));
	check("header: keeps the π marker", line.includes("π"));
	check("header: name is accent-coloured", /<accent>Session: Refactor auth<\/accent>/.test(line));
	check("header: marker is muted", /<muted> π<\/muted>/.test(line));
	// one trailing column is reserved so the name never touches the edge
	check("header: right-aligned within the width", visibleWidth(plain(line)) === 39);
}

// 2. the name is read at render time, so /name shows up without a reinstall
{
	const { h, ctx, state } = await setup({ name: "Before" });
	h.session_start({ type: "session_start", reason: "startup" }, ctx);
	check("live: initial name", plain(state.header.render(40)[0]).includes("Before"));

	state.name = "After";
	check("live: updated name", plain(state.header.render(40)[0]).includes("After"));
}

// 3. session_info_changed asks the TUI to repaint
{
	const { h, ctx, state } = await setup({ name: "Something" });
	h.session_start({ type: "session_start", reason: "startup" }, ctx);
	check("repaint: no render requested yet", state.renders === 0);
	h.session_info_changed({ type: "session_info_changed", name: "Renamed" }, ctx);
	check("repaint: render requested on rename", state.renders === 1);
}

// 4. unnamed sessions still say something
{
	const { h, ctx, state } = await setup({});
	h.session_start({ type: "session_start", reason: "startup" }, ctx);
	check("unnamed: falls back to a placeholder", plain(state.header.render(40)[0]).includes("Session: Unnamed"));
}

// 5. narrow terminals keep the name and drop the decoration
{
	const { h, ctx, state } = await setup({ name: "A very long session name indeed" });
	h.session_start({ type: "session_start", reason: "startup" }, ctx);

	const narrow = plain(state.header.render(20)[0]);
	check("narrow: fits the width", visibleWidth(narrow) <= 20);
	check("narrow: keeps the name, not the marker", narrow.startsWith("Session:") && !narrow.includes("π"));
	check("narrow: marks the truncation", narrow.endsWith("…"));

	// widths around the exact fit must not overflow either
	const widest = "Session: A very long session name indeed".length + 3;
	for (const width of [widest - 1, widest, widest + 1]) {
		check(
			`tight: no overflow at width ${width}`,
			visibleWidth(plain(state.header.render(width)[0])) <= width,
		);
	}
}

// 6. placement can be pinned to the editor instead
{
	process.env.PI_SESSION_HEADER = "widget";
	const { h, ctx, state } = await setup({ name: "Pinned" });
	h.session_start({ type: "session_start", reason: "startup" }, ctx);
	check("widget: header untouched", state.header === undefined);
	check("widget: pinned above the editor", state.widgets[0]?.options.placement === "aboveEditor");
	check("widget: renders the name", plain(state.widgets[0].component.render(40)[0]).includes("Pinned"));

	process.env.PI_SESSION_HEADER = "below";
	const { h: h2, ctx: c2, state: s2 } = await setup({ name: "Below" });
	h2.session_start({ type: "session_start", reason: "startup" }, c2);
	check("widget: pinned below the editor", s2.widgets[0]?.options.placement === "belowEditor");
	delete process.env.PI_SESSION_HEADER;
}

// 7. custom label
{
	process.env.PI_SESSION_HEADER_LABEL = "▸ ";
	const { h, ctx, state } = await setup({ name: "Custom" });
	h.session_start({ type: "session_start", reason: "startup" }, ctx);
	check("label: override applied", plain(state.header.render(40)[0]).includes("▸ Custom"));
	delete process.env.PI_SESSION_HEADER_LABEL;
}

// 8. skipped where it cannot render
{
	const { h, ctx, state } = await setup({ name: "x", mode: "rpc" });
	h.session_start({ type: "session_start", reason: "startup" }, ctx);
	check("non-tui: no header installed", state.header === undefined && state.widgets.length === 0);

	process.env.PI_SESSION_HEADER = "off";
	const { h: h2 } = await setup({ name: "x" });
	check("disabled: registers no handlers", Object.keys(h2).length === 0);
	delete process.env.PI_SESSION_HEADER;
}

console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail === 0 ? 0 : 1);
