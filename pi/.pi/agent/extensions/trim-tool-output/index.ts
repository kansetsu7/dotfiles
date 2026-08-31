/**
 * trim-tool-output — cap tool-result size at ingestion (salience-aware).
 *
 * Solves #2 (minimal tool output in context) while staying:
 *  - cache-SAFE: transforms the result once at production time, before it enters
 *    the cached prefix; the entry is immutable so it replays from cache (no
 *    per-turn invalidation).
 *  - tree-SAFE: the stored entry is capped once and never mutated, so resuming/
 *    branching any node sees identical content; full text is persisted to disk
 *    keyed by toolCallId for lossless recovery via `read`.
 *  - information-aware: instead of blind head/tail, it keeps head + tail AND
 *    splices salient middle lines (errors, test failures, stack frames) so the
 *    root cause survives in-context, not just on disk. See patterns.ts.
 *
 * See DESIGN.md for rationale and the Claude Code / Codex / grok-cli comparison.
 */

import { mkdir, readdir, stat, unlink, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join } from "node:path";
import type { TextContent } from "@earendil-works/pi-ai";
import { formatSize } from "@earendil-works/pi-coding-agent";
import type {
	ExtensionAPI,
	ToolResultEvent,
} from "@earendil-works/pi-coding-agent";
import { buildSalienceRegex, parseExtraPatterns } from "./patterns.ts";

// ---- config (env-overridable; sensible defaults) ----
const num = (v: string | undefined, d: number): number =>
	v !== undefined && v.trim() !== "" && !Number.isNaN(Number(v)) ? Number(v) : d;
const expand = (p: string): string =>
	p.startsWith("~") ? join(homedir(), p.slice(1)) : p;
const csv = (v: string | undefined): string[] =>
	(v ?? "").split(",").map((s) => s.trim()).filter(Boolean);

const MAX_BYTES = num(process.env.PI_TRIM_MAX_BYTES, 8 * 1024);
const MAX_LINES = num(process.env.PI_TRIM_MAX_LINES, 300);
const HEAD_LINES = num(process.env.PI_TRIM_HEAD_LINES, 80);
const TAIL_LINES = num(process.env.PI_TRIM_TAIL_LINES, 40);
const MAX_SALIENT_LINES = num(process.env.PI_TRIM_MAX_SALIENT_LINES, 60);
const SALIENCE_ON = process.env.PI_TRIM_SALIENCE !== "off";
/** "persist" = full output to disk + preview (lossless); "truncate" = drop it. */
const MODE: "persist" | "truncate" =
	process.env.PI_TRIM_MODE === "truncate" ? "truncate" : "persist";
const PERSIST_DIR = expand(
	process.env.PI_TRIM_PERSIST_DIR ?? "~/.pi/agent/tool-results",
);
const NEVER_CAP_TOOLS = new Set(csv(process.env.PI_TRIM_NEVER_CAP_TOOLS));
const GC_MAX_AGE_DAYS = num(process.env.PI_TRIM_GC_MAX_AGE_DAYS, 30);
const GC_MAX_DIR_BYTES = num(process.env.PI_TRIM_GC_MAX_DIR_BYTES, 512 * 1024 * 1024);

const SALIENCE_RE = buildSalienceRegex(
	parseExtraPatterns(process.env.PI_TRIM_EXTRA_PATTERNS),
);

const isText = (c: { type: string }): c is TextContent => c.type === "text";
const bytes = (s: string): number => Buffer.byteLength(s, "utf8");

export default function trimToolOutput(pi: ExtensionAPI): void {
	// #2 ingestion cap — runs after a tool executes; can rewrite the result.
	pi.on("tool_result", async (event: ToolResultEvent) => {
		if (NEVER_CAP_TOOLS.has(event.toolName)) return;

		const texts = event.content.filter(isText);
		if (texts.length === 0) return; // images / empty → untouched

		const fullText = texts.map((t) => t.text).join("\n");
		if (bytes(fullText) <= MAX_BYTES && fullText.split("\n").length <= MAX_LINES) {
			return; // within budget → no-op (true zero information loss)
		}

		const cap = capText(fullText);
		let notice =
			`\n\n[trim-tool-output: kept ${formatSize(cap.keptBytes)} of ` +
			`${formatSize(bytes(fullText))}` +
			(cap.salientShown > 0
				? `, incl. ${cap.salientShown} salient middle line(s)`
				: "") +
			`, ${cap.omittedLines} line(s) omitted`;
		if (MODE === "persist") {
			const path = await persist(event.toolCallId, fullText);
			notice += path
				? `. Full output on disk — read it before concluding if diagnosing an error: ${path}]`
				: `]`;
		} else {
			notice += `]`;
		}

		const nonText = event.content.filter((c) => !isText(c));
		const capped: TextContent = { type: "text", text: cap.text + notice };
		return { content: [capped, ...nonText] };
	});

	// Disk GC — decoupled from rounds so short sessions never orphan files.
	pi.on("session_start", async () => {
		await gc();
	});
}

interface CapResult {
	text: string;
	keptBytes: number;
	omittedLines: number;
	salientShown: number;
}

/** Head + salient-middle + tail, within the byte budget. */
function capText(full: string): CapResult {
	const lines = full.split("\n");
	const n = lines.length;

	// Budget split: head 50%, tail 30%, salient middle gets the rest.
	const headBudget = Math.floor(MAX_BYTES * 0.5);
	const tailBudget = Math.floor(MAX_BYTES * 0.3);

	const head = takeHead(lines, 0, HEAD_LINES, headBudget);
	const tail = takeTail(lines, head.next, TAIL_LINES, tailBudget);
	const midStart = head.next;
	const midEnd = tail.start; // exclusive

	const salient: string[] = [];
	let salientBytes = 0;
	const salientBudget = MAX_BYTES - head.bytes - tail.bytes;
	if (SALIENCE_ON && midEnd > midStart) {
		for (let i = midStart; i < midEnd; i++) {
			if (!SALIENCE_RE.test(lines[i])) continue;
			const rendered = `L${i + 1}| ${lines[i]}`;
			const b = bytes(rendered) + 1;
			if (salient.length >= MAX_SALIENT_LINES || salientBytes + b > salientBudget) {
				break;
			}
			salient.push(rendered);
			salientBytes += b;
		}
	}

	const shownMiddle = salient.length;
	const omittedMiddle = Math.max(0, midEnd - midStart - shownMiddle);

	const parts: string[] = [];
	if (head.lines.length) parts.push(head.lines.join("\n"));
	if (salient.length) {
		parts.push(
			`[… middle: ${shownMiddle} salient line(s) shown, ${omittedMiddle} omitted …]`,
		);
		parts.push(salient.join("\n"));
	} else if (omittedMiddle > 0) {
		parts.push(`[… ${omittedMiddle} middle line(s) omitted …]`);
	}
	if (tail.lines.length) parts.push(tail.lines.join("\n"));

	const text = parts.join("\n");
	return {
		text,
		keptBytes: bytes(text),
		omittedLines: omittedMiddle,
		salientShown: shownMiddle,
	};
}

interface Slice {
	lines: string[];
	bytes: number;
	next: number; // first index NOT taken (head)
	start: number; // first index taken (tail)
}

function takeHead(lines: string[], from: number, maxLines: number, maxBytes: number): Slice {
	const out: string[] = [];
	let used = 0;
	let i = from;
	for (; i < lines.length && out.length < maxLines; i++) {
		const b = bytes(lines[i]) + 1;
		if (used + b > maxBytes && out.length > 0) break;
		out.push(lines[i]);
		used += b;
	}
	return { lines: out, bytes: used, next: i, start: i };
}

function takeTail(lines: string[], notBefore: number, maxLines: number, maxBytes: number): Slice {
	const out: string[] = [];
	let used = 0;
	let i = lines.length - 1;
	for (; i >= notBefore && out.length < maxLines; i--) {
		const b = bytes(lines[i]) + 1;
		if (used + b > maxBytes && out.length > 0) break;
		out.unshift(lines[i]);
		used += b;
	}
	return { lines: out, bytes: used, next: i + 1, start: i + 1 };
}

async function persist(toolCallId: string, text: string): Promise<string | null> {
	try {
		await mkdir(PERSIST_DIR, { recursive: true });
		const safe = toolCallId.replace(/[^a-zA-Z0-9_-]/g, "_") || "tool";
		const path = join(PERSIST_DIR, `${safe}.txt`);
		await writeFile(path, text, "utf8");
		return path;
	} catch {
		return null; // disk issues must not break the tool result
	}
}

async function gc(): Promise<void> {
	let names: string[];
	try {
		names = await readdir(PERSIST_DIR);
	} catch {
		return; // dir absent → nothing to GC
	}

	const now = Date.now();
	const maxAgeMs = GC_MAX_AGE_DAYS * 24 * 60 * 60 * 1000;
	const kept: Array<{ path: string; mtime: number; size: number }> = [];

	for (const name of names) {
		const path = join(PERSIST_DIR, name);
		let s: Awaited<ReturnType<typeof stat>>;
		try {
			s = await stat(path);
		} catch {
			continue;
		}
		if (!s.isFile()) continue;
		if (maxAgeMs > 0 && now - s.mtimeMs > maxAgeMs) {
			await unlink(path).catch(() => {});
			continue;
		}
		kept.push({ path, mtime: s.mtimeMs, size: s.size });
	}

	if (GC_MAX_DIR_BYTES <= 0) return;
	let total = kept.reduce((n, f) => n + f.size, 0);
	if (total <= GC_MAX_DIR_BYTES) return;
	kept.sort((a, b) => a.mtime - b.mtime); // oldest first
	for (const f of kept) {
		if (total <= GC_MAX_DIR_BYTES) break;
		await unlink(f.path).catch(() => {});
		total -= f.size;
	}
}
