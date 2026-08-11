/**
 * Salience patterns for trim-tool-output.
 *
 * When a tool result is over budget we keep head + tail, then splice in any
 * "salient" middle lines that match these patterns (root-cause stack frames,
 * test failures, build errors) so they survive in-context rather than only on
 * disk.
 *
 * Tuned for /proj/nerv_sg: Rails (Ruby) + Go + Clojure/ClojureScript, run inside
 * a dockerized dev environment.
 *
 * Matching is UNANCHORED (substring) so docker-compose log prefixes like
 * "web-1  | Failure/Error:" and `docker exec` wrappers don't defeat detection.
 *
 * Edit freely — this is data, not logic. `test.mjs` exercises real samples.
 */

/** Grouped, commented source patterns (case-insensitivity handled at compile). */
export const PATTERN_GROUPS: Record<string, string[]> = {
	// Language-agnostic signals + any "file.ext:line" location reference.
	generic: [
		String.raw`\b(errors?|failed|failures?|fatal|panic|exceptions?|timeout|refused|undefined|unable to|not found|cannot|denied)\b`,
		String.raw`\.[a-zA-Z]{1,5}:\d+`, // foo.rb:42, main.go:10, core.cljs:7
	],

	// Ruby / Rails: RSpec, Minitest, ActiveRecord, rake.
	ruby: [
		String.raw`Failure/Error:`,
		String.raw`\d+ examples?, \d+ failures?`, // rspec summary
		String.raw`\d+ runs?, .*\d+ (failures?|errors?)`, // minitest summary
		String.raw`\.(rb|rake|erb):\d+(:in )?`,
		String.raw`\b(ActiveRecord|ActionController|ActionView|PG|Mysql2|Redis)::`,
		String.raw`\b\w*Error\b`, // NoMethodError, ArgumentError, ...
		String.raw`(rails|rake) aborted!`,
		String.raw`expected( .*)? (to|but)`, // rspec expectations
	],

	// Go: go test, panics, build/vet errors.
	go: [
		String.raw`--- FAIL`,
		String.raw`\bFAIL\b`,
		String.raw`panic:`,
		String.raw`goroutine \d+`,
		String.raw`\.go:\d+`,
		String.raw`\b(cannot use|undefined|declared( and)? not used|missing return)\b`,
		String.raw`build (failed|constraints exclude)`,
		String.raw`^go: `,
	],

	// Clojure / ClojureScript: clojure.test, compiler, shadow-cljs.
	clojure: [
		String.raw`FAIL in`,
		String.raw`ERROR in`,
		String.raw`^\s*(expected|actual):`, // clojure.test diff
		String.raw`Syntax error`,
		String.raw`CompilerException`,
		String.raw`Execution error`,
		String.raw`\.clj[csx]?:\d+`,
		String.raw`at [\w.$/-]+\([^)]*:\d+\)`, // stack frame: at ns$fn (file.clj:12)
		String.raw`------ (WARNING|ERROR)`, // shadow-cljs
		String.raw`Closure compilation failed`,
		String.raw`The required namespace .* is not available`,
		String.raw`\d+ failures, \d+ errors`, // clojure.test summary
	],

	// Docker / docker-compose.
	docker: [
		String.raw`Error response from daemon`,
		String.raw`Cannot connect to the Docker daemon`,
		String.raw`exited with code \d+`,
		String.raw`failed to solve`,
		String.raw`ERROR \[`, // buildkit stage error
		String.raw`service .* failed to build`,
		String.raw`no such (file or directory|host)`,
	],
};

/** Compile all groups (+ optional extras) into one case-insensitive matcher. */
export function buildSalienceRegex(extra: string[] = []): RegExp {
	const sources = [
		...Object.values(PATTERN_GROUPS).flat(),
		...extra.filter((s) => s.trim() !== ""),
	];
	// `m` so ^-anchored group patterns work per-line even on a joined scan.
	return new RegExp(sources.map((s) => `(?:${s})`).join("|"), "im");
}

/** Parse PI_TRIM_EXTRA_PATTERNS ("||"- or newline-separated regex strings). */
export function parseExtraPatterns(env: string | undefined): string[] {
	if (!env) return [];
	return env
		.split(/\r?\n|\|\|/)
		.map((s) => s.trim())
		.filter(Boolean);
}
