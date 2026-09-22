/**
 * openspec-skills — load the openspec skills only in the sessions that want them.
 *
 * Why: the six `openspec-*` skills are only useful in company projects, but
 * their descriptions sit in *every* system prompt once they live in a
 * discovered skill directory. Deleting them is not an option either — they are
 * exactly what is wanted a few times a month. So they live in
 * `skills-optional/`, which no discovery path looks at, and are contributed
 * back through `resources_discover` when the session asks for them.
 *
 * Why per session, not per project or per process:
 *  - The skills list is part of the system prompt, which is the first cached
 *    block (`cache_control` on the system blocks). Changing it mid-conversation
 *    invalidates the whole cached prefix — cheap on turn 1, expensive on turn 40.
 *  - A per-session flag means a resumed session rebuilds the *same* prompt it
 *    was cached with, so `/resume` never pays for a re-cache. A per-process flag
 *    would drift out of sync with whichever session you resumed into.
 *
 * How:
 *  - The flag is a `custom` session entry (`pi.appendEntry`). Custom entries
 *    never enter LLM context, survive `/resume` and `--fork`, and cannot be
 *    dropped by compaction — so the session carries its own answer.
 *  - `session_start` reads it (it fires immediately before `resources_discover`,
 *    see agent-session.js `bindExtensions`), `resources_discover` acts on it.
 *  - Session replacement (`/resume`, `/fork`, `newSession`) builds a *fresh*
 *    ResourceLoader, so switching between an "on" and an "off" session
 *    reconciles on its own, in both directions, with no reload.
 *  - `/openspec on|off` inside one session is the exception: `extendResources()`
 *    merges and never removes, so a change of mind requires `ctx.reload()`.
 *    That is also the only reload this extension ever triggers, and the command
 *    warns first when the session is big enough for the re-cache to be felt.
 *  - `session_start` gets an `ExtensionContext`, which has no `reload()` — only
 *    command contexts do. Nothing here needs one, by the design above.
 *
 * Config (env):
 *   PI_OPENSPEC=off        disable the extension entirely
 *   PI_OPENSPEC=on         default new sessions to on (sessions that recorded a
 *                          flag still win — that is the point of per-session)
 *   PI_OPENSPEC_COMMAND    default "openspec"
 *   PI_OPENSPEC_SKILLS     override the skills directory
 */

import { existsSync, realpathSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import type {
	ExtensionAPI,
	ExtensionCommandContext,
	ExtensionContext,
} from "@earendil-works/pi-coding-agent";

const OFF = new Set(["0", "off", "false", "no"]);
const ON = new Set(["1", "on", "true", "yes"]);
const flag = (v: string | undefined): boolean | undefined => {
	const s = v?.trim().toLowerCase();
	if (!s) return undefined;
	if (OFF.has(s)) return false;
	if (ON.has(s)) return true;
	return undefined;
};

const ENABLED = flag(process.env.PI_OPENSPEC) !== false;
const DEFAULT_ON = flag(process.env.PI_OPENSPEC) === true;
const COMMAND = process.env.PI_OPENSPEC_COMMAND?.trim() || "openspec";

/** Session entry type carrying the flag. Not LLM context — pure extension state. */
const ENTRY_TYPE = "openspec";

/**
 * Turning the skills on rebuilds the system prompt, which invalidates the
 * cached prefix. Below this many tokens the re-cache is noise; above it, say so
 * before doing it.
 */
const WARN_TOKENS = 10_000;

/**
 * `skills-optional/openspec`, found relative to this file. The extensions
 * directory is a stow symlink, so the real path is tried first — resolving
 * `../..` through the link would otherwise land in `~/.pi/agent`, where the
 * directory deliberately does not exist.
 */
function locateSkills(): string | undefined {
	const override = process.env.PI_OPENSPEC_SKILLS?.trim();
	if (override) {
		const path = resolve(override.replace(/^~(?=$|\/)/, process.env.HOME ?? "~"));
		return existsSync(path) ? path : undefined;
	}

	const here = fileURLToPath(import.meta.url);
	const candidates = new Set<string>();
	for (const start of [safeRealpath(here), here]) {
		candidates.add(join(dirname(dirname(dirname(start))), "skills-optional", "openspec"));
	}
	for (const path of candidates) {
		if (existsSync(path)) return path;
	}
	return undefined;
}

const safeRealpath = (path: string): string => {
	try {
		return realpathSync(path);
	} catch {
		return path;
	}
};

/** The session's own answer, or the env default when it has never been asked. */
function readFlag(ctx: ExtensionContext): boolean {
	let enabled = DEFAULT_ON;
	for (const entry of ctx.sessionManager.getEntries()) {
		if (entry.type !== "custom" || entry.customType !== ENTRY_TYPE) continue;
		const data = entry.data as { enabled?: unknown } | undefined;
		if (typeof data?.enabled === "boolean") enabled = data.enabled;
	}
	return enabled;
}

export default function openspecSkills(pi: ExtensionAPI): void {
	if (!ENABLED) return;

	const skillsDir = locateSkills();
	// State for *this* runtime: what the session asked for, and what the
	// ResourceLoader was actually given. They only differ between a toggle and
	// the reload that carries it out.
	let wanted = false;
	let loaded = false;

	pi.on("session_start", (_event, ctx) => {
		wanted = skillsDir ? readFlag(ctx) : false;
	});

	pi.on("resources_discover", () => {
		if (!wanted || !skillsDir) return;
		loaded = true;
		return { skillPaths: [skillsDir] };
	});

	pi.registerCommand(COMMAND, {
		description: "Toggle the openspec skills for this session (on/off/status)",
		getArgumentCompletions: (prefix: string) =>
			["on", "off", "toggle", "status"]
				.filter((v) => v.startsWith(prefix.trim().toLowerCase()))
				.map((value) => ({ value, label: value })),
		handler: async (args: string, ctx: ExtensionCommandContext) => {
			if (!skillsDir) {
				ctx.ui.notify(
					"openspec skills not found — expected pi/.pi/agent/skills-optional/openspec or $PI_OPENSPEC_SKILLS",
					"error",
				);
				return;
			}

			const arg = args.trim().toLowerCase();
			const state = () => (wanted ? "on" : "off");

			if (arg === "" || arg === "status") {
				ctx.ui.notify(`openspec skills: ${state()} for this session`, "info");
				return;
			}

			const target =
				arg === "toggle" ? !wanted : ON.has(arg) ? true : OFF.has(arg) ? false : undefined;
			if (target === undefined) {
				ctx.ui.notify(`Usage: /${COMMAND} [on|off|toggle|status]`, "error");
				return;
			}
			if (target === wanted && target === loaded) {
				ctx.ui.notify(`openspec skills already ${state()}`, "info");
				return;
			}

			// The flag is recorded before the reload so the replacement runtime
			// reads it back out of the session, which is also what a later
			// /resume will do.
			pi.appendEntry(ENTRY_TYPE, { enabled: target });
			wanted = target;

			const tokens = ctx.getContextUsage()?.tokens ?? 0;
			if (tokens > WARN_TOKENS) {
				ctx.ui.notify(
					`openspec skills ${target ? "on" : "off"} — rebuilding the system prompt re-caches ~${Math.round(tokens / 1000)}k tokens on the next turn`,
					"warning",
				);
			} else {
				ctx.ui.notify(`openspec skills ${target ? "on" : "off"} for this session`, "info");
			}

			// Only a reload can *remove* skills (extendResources merges, never
			// prunes), and it is the cheapest way to add them too. Treat it as
			// terminal: everything after it runs in the old, stale runtime.
			await ctx.reload();
			return;
		},
	});
}
