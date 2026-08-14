/**
 * force-session-name — require a display name for every new/forked session.
 *
 * Why: unnamed sessions all look alike in `/resume` and `pi -r` (they fall back
 * to the first user message, which is usually "fix this" or a pasted stack
 * trace). Forks are worse: they inherit the parent's name, so a tree of
 * experiments ends up with N identical rows.
 *
 * How:
 *  - `session_start` (reason `new` / `fork`, optionally `startup`) opens a
 *    blocking input dialog. pi starts the TUI before firing `session_start`
 *    specifically so extensions can use dialogs here.
 *  - A bare `pi` launch first asks new-vs-resume, because at that point you
 *    have not chosen either yet. Resuming hands off to the built-in `/resume`:
 *    event handlers only get an `ExtensionContext`, and `switchSession()` lives
 *    on `ExtensionCommandContext`, so the editor is prefilled instead.
 *  - Escaping the dialog does not silently win: the session is marked pending,
 *    a footer warning is shown, and the next interactive message re-prompts and
 *    is blocked until a name exists. Slash commands stay usable so `/name`,
 *    `/resume`, `/quit` etc. still work.
 *  - Forks always prompt even though `getSessionName()` is non-empty, because
 *    that name came from the parent branch.
 *
 * Config (env):
 *   PI_FORCE_SESSION_NAME=off        disable entirely
 *   PI_FORCE_SESSION_NAME_REASONS    default "startup,new,fork" (also: reload, resume)
 *   PI_FORCE_SESSION_NAME_MIN_LEN    default 3
 *   PI_FORCE_SESSION_NAME_MAX_PROMPTS default 3 re-asks per trigger
 *   PI_FORCE_SESSION_NAME_BLOCK=off  warn only, never block input
 *   PI_FORCE_SESSION_NAME_PICKER=off skip new/resume choice, ask for a name
 */

import type {
	ExtensionAPI,
	ExtensionContext,
	SessionStartEvent,
} from "@earendil-works/pi-coding-agent";

type Reason = SessionStartEvent["reason"];

const STATUS_KEY = "force-session-name";
const DEFAULT_REASONS: Reason[] = ["startup", "new", "fork"];
const ALL_REASONS: Reason[] = ["startup", "reload", "new", "resume", "fork"];
// Everything except `reload`, which re-enters the *same* session in place.
const SWITCH_REASONS = new Set<Reason>(["startup", "new", "resume", "fork"]);

const OFF = new Set(["0", "off", "false", "no"]);
const isOff = (v: string | undefined): boolean =>
	v !== undefined && OFF.has(v.trim().toLowerCase());
const num = (v: string | undefined, d: number): number =>
	v !== undefined && v.trim() !== "" && !Number.isNaN(Number(v)) ? Number(v) : d;
const csv = (v: string | undefined): string[] =>
	(v ?? "").split(",").map((s) => s.trim()).filter(Boolean);

const ENABLED = !isOff(process.env.PI_FORCE_SESSION_NAME);
const PICKER = !isOff(process.env.PI_FORCE_SESSION_NAME_PICKER);
const BLOCK_INPUT = !isOff(process.env.PI_FORCE_SESSION_NAME_BLOCK);
const MIN_LEN = Math.max(1, num(process.env.PI_FORCE_SESSION_NAME_MIN_LEN, 3));
const MAX_PROMPTS = Math.max(1, num(process.env.PI_FORCE_SESSION_NAME_MAX_PROMPTS, 3));

const configuredReasons = csv(process.env.PI_FORCE_SESSION_NAME_REASONS).filter(
	(r): r is Reason => (ALL_REASONS as string[]).includes(r),
);
const REASONS = new Set<Reason>(
	configuredReasons.length > 0 ? configuredReasons : DEFAULT_REASONS,
);

const LABEL: Record<Reason, string> = {
	startup: "new",
	reload: "reloaded",
	new: "new",
	resume: "resumed",
	fork: "forked",
};

// A brand-new session is not entry-free: pi records `model_change` /
// `thinking_level_change` before extensions bind (settings pin defaultModel and
// defaultThinkingLevel). Only conversation entries mean "work already here".
const CONVERSATION_ENTRIES = new Set([
	"message",
	"custom_message",
	"compaction",
	"branch_summary",
]);

const CHOICE_NEW = "New session";
const CHOICE_RESUME = "Resume a previous session";
const RESUME_COMMAND = "/resume";

const normalize = (raw: string): string =>
	raw.replace(/[\r\n]+/g, " ").replace(/\s+/g, " ").trim();

export default function forceSessionName(pi: ExtensionAPI): void {
	if (!ENABLED) return;

	let pending = false;
	let prompting = false;

	const setPending = (ctx: ExtensionContext, value: boolean): void => {
		pending = value;
		ctx.ui.setStatus(
			STATUS_KEY,
			value ? "⚠ unnamed session — use /name <name>" : undefined,
		);
	};

	async function askForName(
		ctx: ExtensionContext,
		reason: Reason,
		suggestion: string | undefined,
	): Promise<string | undefined> {
		const what = LABEL[reason];
		for (let attempt = 0; attempt < MAX_PROMPTS; attempt++) {
			const title =
				attempt === 0
					? `Name this ${what} session`
					: `Name required (min ${MIN_LEN} characters)`;
			const answer = await ctx.ui.input(
				title,
				suggestion ?? "e.g. Refactor auth module",
			);
			if (answer === undefined) return undefined; // escaped
			const name = normalize(answer);
			if (name.length >= MIN_LEN) return name;
			ctx.ui.notify(
				`Session name must be at least ${MIN_LEN} characters.`,
				"warning",
			);
		}
		return undefined;
	}

	/**
	 * Bare `pi` has not committed to a session yet, so offer the choice.
	 * Escaping is not an opt-out — it falls through to the name gate.
	 */
	async function chooseStartupAction(
		ctx: ExtensionContext,
	): Promise<"new" | "resume"> {
		const choice = await ctx.ui.select("Start a session", [
			CHOICE_NEW,
			CHOICE_RESUME,
		]);
		return choice === CHOICE_RESUME ? "resume" : "new";
	}

	async function ensureNamed(ctx: ExtensionContext, reason: Reason): Promise<void> {
		if (prompting) return;
		prompting = true;
		try {
			const inherited = pi.getSessionName();
			const suggestion =
				reason === "fork" && inherited ? `${inherited} (fork)` : undefined;
			const name = await askForName(ctx, reason, suggestion);
			if (name) {
				pi.setSessionName(name);
				setPending(ctx, false);
				ctx.ui.notify(`Session named: ${name}`, "info");
				return;
			}
			setPending(ctx, true);
			ctx.ui.notify(
				BLOCK_INPUT
					? "Session name required — you cannot send messages until it is set."
					: "Session left unnamed. Set one with /name <name>.",
				BLOCK_INPUT ? "error" : "warning",
			);
		} finally {
			prompting = false;
		}
	}

	pi.on("session_start", async (event, ctx) => {
		// Dialogs need a UI; print/json modes have none.
		if (!ctx.hasUI) return;

		// `pending` describes the session we are leaving. Escaping the prompt and
		// then `/resume`-ing a named session must not carry the block over, so
		// clear it on any real session switch and let the checks below re-arm it.
		if (pending && SWITCH_REASONS.has(event.reason)) setPending(ctx, false);

		if (!REASONS.has(event.reason)) return;

		// `startup` also covers `pi -c` / `--session`; only treat an empty
		// session as genuinely new so continuing work is not interrupted.
		if (event.reason === "startup" || event.reason === "reload") {
			const hasHistory = ctx.sessionManager
				.getEntries()
				.some((entry) => CONVERSATION_ENTRIES.has(entry.type));
			if (hasHistory) return;
		}

		// A fork inherits the parent's name, so an existing name proves nothing.
		if (event.reason !== "fork" && pi.getSessionName()) return;

		// `/new` and `/fork` already state the intent; only a bare launch asks.
		if (PICKER && event.reason === "startup") {
			if (prompting) return;
			prompting = true;
			let action: "new" | "resume";
			try {
				action = await chooseStartupAction(ctx);
			} finally {
				prompting = false;
			}
			if (action === "resume") {
				// Only command handlers get ctx.switchSession(), so defer to the
				// built-in picker instead of reimplementing session switching.
				ctx.ui.setEditorText(RESUME_COMMAND);
				ctx.ui.notify(
					`Press Enter to run ${RESUME_COMMAND} and pick a session.`,
					"info",
				);
				// Arm the gate anyway: if the resume is abandoned and a message is
				// typed instead, this session still needs a name. Actually resuming
				// clears it via the session switch.
				setPending(ctx, true);
				return;
			}
		}

		await ensureNamed(ctx, event.reason);
	});

	// Named some other way (/name, RPC, another extension) — clear the block.
	pi.on("session_info_changed", (event, ctx) => {
		if (event.name && normalize(event.name).length >= MIN_LEN) {
			setPending(ctx, false);
		}
	});

	pi.on("input", async (event, ctx) => {
		if (!pending || !BLOCK_INPUT || !ctx.hasUI) return;
		if (event.source !== "interactive") return;
		// Let slash commands through so /name, /resume, /quit still work.
		if (event.text.trimStart().startsWith("/")) return;

		await ensureNamed(ctx, "new");
		if (pending) {
			ctx.ui.notify("Name the session first: /name <name>", "error");
			return { action: "handled" };
		}
	});
}
