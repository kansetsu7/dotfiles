/**
 * Test harness for jump-to-bottom. Loads the extension via jiti (the same
 * loader pi uses) with a mock ExtensionAPI/ExtensionContext and a fake
 * viewport TUI, then renders the widget in both scroll states.
 *
 *   node test.mjs
 */
import { createRequire } from "node:module";

const PIROOT = "/root/npm-global/lib/node_modules/@earendil-works/pi-coding-agent";
const require = createRequire(`${PIROOT}/`);
const { createJiti } = require("jiti");
const { visibleWidth } = require(`${PIROOT}/node_modules/@earendil-works/pi-tui/dist/index.js`);

// moduleCache off: the key/label/placement are read at module scope, so each
// setup() must re-evaluate the module to pick up env changes made by a test.
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

/**
 * Fresh extension instance + mocks. `tuiKind` picks the viewport-owning
 * fullscreen TUI or the main-screen one, which has neither scroll accessor.
 */
async function setup({ mode = "tui", tuiKind = "fullscreen", following = true } = {}) {
	const mod = await jiti.import(ENTRY, { default: true });
	const h = {};
	const state = { widgets: [], shortcuts: [], jumps: 0, following };
	const pi = {
		on: (event, fn) => {
			h[event] = fn;
		},
		registerShortcut: (key, options) => state.shortcuts.push({ key, options }),
	};
	mod(pi);

	const tui =
		tuiKind === "fullscreen"
			? {
					requestRender: () => {},
					get isFollowingOutput() {
						return state.following;
					},
					scrollToBottom: () => {
						state.jumps++;
						state.following = true;
					},
				}
			: { requestRender: () => {} };

	const theme = {
		fg: (color, text) => `<${color}>${text}</${color}>`,
		bg: (color, text) => `[${color}]${text}[/${color}]`,
	};
	const ctx = {
		hasUI: true,
		mode,
		ui: {
			setWidget: (key, factory, options) => {
				state.widgets.push({ key, options, component: factory?.(tui, theme) });
			},
		},
	};
	return { h, ctx, state };
}

/** Rendered line with the mock colour tags stripped. */
const plain = (line) => line.replace(/<\/?\w+>|\[\/?\w+\]/g, "");

const start = (h, ctx) => h.session_start({ type: "session_start", reason: "startup" }, ctx);

// 1. hidden while the transcript is following the end
{
	const { h, ctx, state } = await setup({ following: true });
	start(h, ctx);
	const widget = state.widgets[0];
	check("widget: installed above the editor", widget?.options.placement === "aboveEditor");
	check("at bottom: renders nothing", widget.component.render(80).length === 0);
}

// 2. shown, centred, once scrolled up
{
	const { h, ctx, state } = await setup({ following: false });
	start(h, ctx);
	const [line] = state.widgets[0].component.render(80);
	check("scrolled: one line", state.widgets[0].component.render(80).length === 1);
	check("scrolled: names the action", plain(line).includes("Jump to bottom"));
	check("scrolled: shows the key", plain(line).includes("(ctrl+shift+b)"));
	check("scrolled: points down", plain(line).includes("↓"));
	check("scrolled: highlighted pill", /\[selectedBg\].*\[\/selectedBg\]/.test(line));
	// centred: leading pad within one column of the trailing gap
	const pad = plain(line).length - plain(line).trimStart().length;
	const rest = 80 - visibleWidth(plain(line));
	check("scrolled: centred", Math.abs(pad - rest) <= 1);
	check("scrolled: fits the width", visibleWidth(plain(line)) <= 80);
}

// 3. the shortcut jumps, and the hint clears itself afterwards
{
	const { h, ctx, state } = await setup({ following: false });
	start(h, ctx);
	const shortcut = state.shortcuts[0];
	check("shortcut: registered on the default key", shortcut?.key === "ctrl+shift+b");
	check("shortcut: described", shortcut?.options.description === "Jump to bottom");

	await shortcut.options.handler(ctx);
	check("shortcut: scrolled to the bottom", state.jumps === 1);
	check("shortcut: hint clears once at the bottom", state.widgets[0].component.render(80).length === 0);
}

// 4. narrow terminals drop the hint rather than wrapping
{
	const { h, ctx, state } = await setup({ following: false });
	start(h, ctx);
	check("narrow: hidden when it cannot fit", state.widgets[0].component.render(10).length === 0);
}

// 5. main-screen TUI has no viewport to scroll — stay silent, never throw
{
	const { h, ctx, state } = await setup({ following: false, tuiKind: "mainscreen" });
	start(h, ctx);
	check("mainscreen: renders nothing", state.widgets[0].component.render(80).length === 0);
	await state.shortcuts[0].options.handler(ctx);
	check("mainscreen: shortcut is a no-op", state.jumps === 0);
}

// 6. placement, key and label are configurable
{
	process.env.PI_JUMP_TO_BOTTOM_PLACEMENT = "below";
	process.env.PI_JUMP_TO_BOTTOM_KEY = "alt+j";
	process.env.PI_JUMP_TO_BOTTOM_LABEL = "Back to newest";
	const { h, ctx, state } = await setup({ following: false });
	start(h, ctx);
	check("config: pinned below the editor", state.widgets[0].options.placement === "belowEditor");
	check("config: custom key bound", state.shortcuts[0].key === "alt+j");
	const line = plain(state.widgets[0].component.render(80)[0]);
	check("config: custom label", line.includes("Back to newest"));
	const expectedKey = process.platform === "darwin" ? "option+j" : "alt+j";
	check(`config: key shown as ${expectedKey}`, line.includes(`(${expectedKey})`));
	delete process.env.PI_JUMP_TO_BOTTOM_PLACEMENT;
	delete process.env.PI_JUMP_TO_BOTTOM_KEY;
	delete process.env.PI_JUMP_TO_BOTTOM_LABEL;
}

// 7. skipped where it cannot render
{
	const { h, ctx, state } = await setup({ mode: "rpc", following: false });
	start(h, ctx);
	check("non-tui: no widget installed", state.widgets.length === 0);

	process.env.PI_JUMP_TO_BOTTOM = "off";
	const { h: h2, state: s2 } = await setup({ following: false });
	check("disabled: registers nothing", Object.keys(h2).length === 0 && s2.shortcuts.length === 0);
	delete process.env.PI_JUMP_TO_BOTTOM;
}

console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail === 0 ? 0 : 1);
