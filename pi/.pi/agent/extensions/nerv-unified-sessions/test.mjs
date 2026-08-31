/**
 * Test harness for nerv-unified-sessions. Loads the extension via jiti (the
 * same loader pi uses) against a throwaway session tree under /tmp, so the
 * real ~/.pi/agent/sessions is never touched.
 *
 *   node test.mjs
 */
import { createRequire } from "node:module";
import {
	existsSync,
	lstatSync,
	mkdirSync,
	mkdtempSync,
	readFileSync,
	readdirSync,
	readlinkSync,
	rmSync,
	statSync,
	symlinkSync,
	writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const PIROOT = "/root/npm-global/lib/node_modules/@earendil-works/pi-coding-agent";
const require = createRequire(`${PIROOT}/`);
const { createJiti } = require("jiti");

// moduleCache off: the unified dir name and match pattern are read at module
// scope, so each setup() must re-evaluate the module to see env changes.
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

const roots = [];

/**
 * Build a fake `<base>/sessions` tree. `layout` maps a directory name to either
 * an object of {filename: contents} or the string "symlink" to pre-link it.
 */
function setup(layout, env = {}) {
	const root = mkdtempSync(join(tmpdir(), "nerv-test-"));
	roots.push(root);
	const base = join(root, "sessions");
	mkdirSync(base, { recursive: true });

	const unified = join(base, env.PI_NERV_UNIFIED_SESSIONS_DIR || "--proj-nerv--");
	for (const [dir, contents] of Object.entries(layout)) {
		const full = join(base, dir);
		if (contents === "symlink") {
			mkdirSync(unified, { recursive: true });
			symlinkSync(unified, full);
			continue;
		}
		mkdirSync(full, { recursive: true });
		for (const [file, body] of Object.entries(contents)) {
			if (typeof body === "object") {
				mkdirSync(join(full, file), { recursive: true });
				continue;
			}
			writeFileSync(join(full, file), body);
		}
	}
	return { root, base, unified, env: { PI_SESSION_BASE: root, ...env } };
}

async function run({ base, env }) {
	const saved = {};
	for (const k of Object.keys(env)) {
		saved[k] = process.env[k];
		process.env[k] = env[k];
	}
	const mod = await jiti.import(ENTRY, { default: true });
	mod();
	for (const [k, v] of Object.entries(saved)) {
		if (v === undefined) delete process.env[k];
		else process.env[k] = v;
	}
	return base;
}

const isLink = (p) => existsSync(p) && lstatSync(p).isSymbolicLink();
const ls = (p) => (existsSync(p) ? readdirSync(p).sort() : []);
const read = (p) => readFileSync(p, "utf8");

// --- consolidation -------------------------------------------------------

{
	const t = setup({
		"--proj-nerv_hk--": { "a.jsonl": "A" },
		"--proj-nerv_ck--": { "b.jsonl": "B" },
		"--proj-amoeba--": { "keep.jsonl": "K" },
	});
	await run(t);

	check("consolidate: sessions moved into unified", ls(t.unified).join(",") === "a.jsonl,b.jsonl");
	check("consolidate: contents preserved", read(join(t.unified, "a.jsonl")) === "A");
	check("consolidate: hk replaced by a symlink", isLink(join(t.base, "--proj-nerv_hk--")));
	check("consolidate: ck replaced by a symlink", isLink(join(t.base, "--proj-nerv_ck--")));
	check(
		"consolidate: symlink points at unified",
		readlinkSync(join(t.base, "--proj-nerv_hk--")) === t.unified,
	);
	check(
		"consolidate: link resolves to the session list",
		ls(join(t.base, "--proj-nerv_hk--")).join(",") === "a.jsonl,b.jsonl",
	);
	check("consolidate: unrelated project untouched", !isLink(join(t.base, "--proj-amoeba--")));
	check(
		"consolidate: unrelated sessions stay put",
		ls(join(t.base, "--proj-amoeba--")).join(",") === "keep.jsonl",
	);
}

// --- bug 1: lstat, so a second run is a no-op ----------------------------

{
	const t = setup({ "--proj-nerv_hk--": { "a.jsonl": "A" } });
	await run(t);

	const link = join(t.base, "--proj-nerv_hk--");
	const before = lstatSync(link).mtimeMs;
	const unifiedBefore = statSync(t.unified).mtimeMs;
	await new Promise((r) => setTimeout(r, 12));
	await run(t);

	check("idempotent: symlink not recreated", lstatSync(link).mtimeMs === before);
	check("idempotent: unified dir not rewritten", statSync(t.unified).mtimeMs === unifiedBefore);
	check("idempotent: still exactly one session", ls(t.unified).join(",") === "a.jsonl");
}

{
	// A pre-existing symlink (the steady state) must survive untouched.
	const t = setup({ "--proj-nerv_hk--": "symlink" });
	writeFileSync(join(t.unified, "a.jsonl"), "A");
	await run(t);
	check("idempotent: pre-linked dir left alone", isLink(join(t.base, "--proj-nerv_hk--")));
	check("idempotent: pre-linked sessions intact", ls(t.unified).join(",") === "a.jsonl");
}

// --- bug 2: one documented matcher ---------------------------------------

{
	const t = setup({
		"--proj-nerv_hk-lilith--": { "a.jsonl": "A" },
		"--proj-nervous--": { "b.jsonl": "B" },
		"--proj-nerv_sg--": { "c.jsonl": "C" },
	});
	await run(t);
	check("match: suffixed worktree unified", isLink(join(t.base, "--proj-nerv_hk-lilith--")));
	check("match: nerv_sg unified", isLink(join(t.base, "--proj-nerv_sg--")));
	check("match: 'nervous' is not a nerv worktree", !isLink(join(t.base, "--proj-nervous--")));
}

{
	const t = setup(
		{ "--proj-nerv_hk--": { "a.jsonl": "A" }, "--proj-nerv_sg--": { "b.jsonl": "B" } },
		{ PI_NERV_UNIFIED_SESSIONS_PATTERN: "^--proj-nerv_hk--$" },
	);
	await run(t);
	check("match: custom pattern includes hk", isLink(join(t.base, "--proj-nerv_hk--")));
	check("match: custom pattern excludes sg", !isLink(join(t.base, "--proj-nerv_sg--")));
}

{
	const t = setup(
		{ "--proj-nerv_hk--": { "a.jsonl": "A" } },
		{ PI_NERV_UNIFIED_SESSIONS_DIR: "--nerv-all--" },
	);
	await run(t);
	check("config: custom unified dir used", ls(join(t.base, "--nerv-all--")).join(",") === "a.jsonl");
}

// --- bug 5: subdirectories must not throw or be destroyed ----------------

{
	const t = setup({ "--proj-nerv_hk--": { "a.jsonl": "A", nested: {} } });
	await run(t);
	const src = join(t.base, "--proj-nerv_hk--");
	check("subdir: source dir kept (not symlinked)", !isLink(src));
	check("subdir: subdirectory preserved", existsSync(join(src, "nested")));
	check("subdir: sessions still moved", ls(t.unified).join(",") === "a.jsonl");
}

// --- bug 6: collisions are preserved, never dropped ----------------------

{
	const t = setup({ "--proj-nerv_hk--": { "a.jsonl": "DIFFERENT CONTENT" } });
	mkdirSync(t.unified, { recursive: true });
	writeFileSync(join(t.unified, "a.jsonl"), "A");
	await run(t);

	const names = ls(t.unified);
	check("collision: original kept", read(join(t.unified, "a.jsonl")) === "A");
	check("collision: colliding file preserved", names.some((n) => n.includes(".conflict-")));
	check(
		"collision: colliding content intact",
		names.some((n) => n.includes(".conflict-") && read(join(t.unified, n)) === "DIFFERENT CONTENT"),
	);
	check("collision: source still symlinked", isLink(join(t.base, "--proj-nerv_hk--")));
}

{
	// Same size => the duplicate left behind by the old copy-based version.
	const t = setup({ "--proj-nerv_hk--": { "a.jsonl": "A" } });
	mkdirSync(t.unified, { recursive: true });
	writeFileSync(join(t.unified, "a.jsonl"), "A");
	await run(t);
	check("duplicate: not duplicated as a conflict", ls(t.unified).join(",") === "a.jsonl");
	check("duplicate: source symlinked", isLink(join(t.base, "--proj-nerv_hk--")));
}

// --- bug 7: never delete a directory we could not empty ------------------

{
	const t = setup({ "--proj-nerv_hk--": { "a.jsonl": "A", nested: {} } });
	await run(t);
	check(
		"safety: undrained dir survives with its data",
		existsSync(join(t.base, "--proj-nerv_hk--", "nested")),
	);
}

// --- disabled ------------------------------------------------------------

{
	const t = setup({ "--proj-nerv_hk--": { "a.jsonl": "A" } }, { PI_NERV_UNIFIED_SESSIONS: "off" });
	await run(t);
	check("disabled: nothing consolidated", !isLink(join(t.base, "--proj-nerv_hk--")));
	check("disabled: sessions left in place", ls(join(t.base, "--proj-nerv_hk--")).join(",") === "a.jsonl");
}

// --- missing base --------------------------------------------------------

{
	const root = mkdtempSync(join(tmpdir(), "nerv-test-"));
	roots.push(root);
	let threw = false;
	try {
		await run({ base: join(root, "sessions"), env: { PI_SESSION_BASE: root } });
	} catch {
		threw = true;
	}
	check("missing base: does not throw", !threw);
}

for (const r of roots) rmSync(r, { recursive: true, force: true });

console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail === 0 ? 0 : 1);
