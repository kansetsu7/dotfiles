/**
 * Test harness for trim-tool-output. Loads the extension via jiti (the same
 * loader pi uses) with a mock ExtensionAPI, and checks that buried root-cause
 * lines from Rails / Go / Clojure / Docker survive capping in-context.
 *
 *   node test.mjs
 */
import { createRequire } from "node:module";

const PIROOT =
	"/root/npm-global/lib/node_modules/@earendil-works/pi-coding-agent";
// Resolve jiti + the pi package from pi's own install — no local node_modules.
const require = createRequire(`${PIROOT}/`);
const { createJiti } = require("jiti");
const jiti = createJiti(import.meta.url, {
	alias: { "@earendil-works/pi-coding-agent": PIROOT },
});

process.env.PI_TRIM_PERSIST_DIR = "/tmp/trim-salience-store";
process.env.PI_TRIM_MAX_BYTES = "8192";

const mod = await jiti.import(
	new URL("./index.ts", import.meta.url).pathname,
	{ default: true },
);
const h = {};
mod({ on: (e, fn) => (h[e] = fn) });

let pass = 0;
let fail = 0;
const check = (name, cond) => {
	console.log(`${cond ? "PASS" : "FAIL"}  ${name}`);
	cond ? pass++ : fail++;
};

/** Build a big output with `rootCause` buried in the middle of noise. */
function buried(rootCause, toolName, prefix = "") {
	const noise = (tag, n) =>
		Array.from({ length: n }, (_, i) => `${prefix}${tag} line ${i} ${"x".repeat(40)}`);
	const text = [
		...noise("head", 120),
		...noise("mid-before", 120),
		`${prefix}${rootCause}`,
		...noise("mid-after", 120),
		...noise("tail", 120),
	].join("\n");
	return { toolName, toolCallId: `${toolName}-${Math.random()}`, input: {}, isError: true,
		content: [{ type: "text", text }] };
}

const cases = [
	// [name, toolName, buried root-cause line, dockercompose prefix]
	["rails/rspec", "bash", "Failure/Error: expect(user.name).to eq('Rei')  # app/models/user.rb:42:in `name'", "web-1  | "],
	["rails/AR",    "bash", "ActiveRecord::RecordNotFound: Couldn't find Pilot with 'id'=3", "web-1  | "],
	["go/test",     "bash", "--- FAIL: TestEvaGuard (0.01s)   controller_test.go:88: expected 200 got 500", ""],
	["go/panic",    "bash", "panic: runtime error: invalid memory address   main.go:23", ""],
	["clojure/test","bash", "FAIL in (guard-spec) (core.clj:57)  expected: (= 3 (count units))", ""],
	["cljs/shadow", "bash", "------ WARNING - Closure compilation failed: core.cljs:12 undefined var", ""],
	["docker",      "bash", "Error response from daemon: service web failed to build: exited with code 1", ""],
];

for (const [name, tool, rootCause, prefix] of cases) {
	const ev = buried(rootCause, tool, prefix);
	const orig = ev.content[0].text;
	const r = await h.tool_result(ev);
	const out = r.content[0].text;
	check(`${name}: capped smaller`, out.length < orig.length);
	check(`${name}: root cause survived in-context`, out.includes(rootCause.slice(0, 30)));
	check(`${name}: has head`, out.includes("head line 0"));
	check(`${name}: has tail`, /tail line 11\d/.test(out));
	check(`${name}: notice + disk path`, /trim-tool-output/.test(out) && /Full output on disk/.test(out));
}

// no-op on small output
const small = await h.tool_result({ toolName: "read", toolCallId: "s", input: {}, isError: false,
	content: [{ type: "text", text: "ok" }] });
check("small output is no-op", small === undefined);

// non-error large output with no salient lines → still head+tail, no salient block
const plain = Array.from({ length: 400 }, (_, i) => `data row ${i} ${"y".repeat(30)}`).join("\n");
const pr = await h.tool_result({ toolName: "read", toolCallId: "p", input: {}, isError: false,
	content: [{ type: "text", text: plain }] });
check("plain large: capped", pr.content[0].text.length < plain.length);
check("plain large: no false salient block", !/salient line\(s\) shown/.test(pr.content[0].text));

console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
