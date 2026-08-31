/**
 * nerv-unified-sessions — route all Nerv worktree sessions to a unified directory
 *
 * Why: The Nerv project has multiple worktrees (nerv_hk, nerv_ck, nerv_sg,
 * nerv_ave_ck, ...) that represent different subsidiaries but share most
 * features. Sessions should be resumable from any worktree, not locked to the
 * one where they were created.
 *
 * Approach: pi derives a session directory from the cwd, so
 * `/proj/nerv_hk` → `--proj-nerv_hk--`. Replacing each of those directories
 * with a symlink to a single `--proj-nerv--` makes pi write and list every
 * Nerv session in one place, with no changes to pi itself.
 *
 * Safety rules, learned the hard way:
 *  - `statSync()` follows symlinks, so it can never identify one. Detection
 *    uses `lstatSync()`; without it every launch re-consolidated and re-created
 *    the symlinks it had already made.
 *  - A source directory is only removed once it is verifiably empty
 *    (`rmdirSync`, not `rmSync(recursive)`), so a failed or partial move can
 *    never delete sessions.
 *  - Name collisions are moved aside as `.conflict-*` rather than skipped,
 *    because "skip, then delete the source" loses the file.
 *
 * Config (env):
 *   PI_NERV_UNIFIED_SESSIONS=off      disable entirely
 *   PI_NERV_UNIFIED_SESSIONS_DIR      unified dir name, default "--proj-nerv--"
 *   PI_NERV_UNIFIED_SESSIONS_PATTERN  regex for dirs to unify,
 *                                     default "^--proj-nerv_.*--$"
 */

import {
	copyFileSync,
	existsSync,
	lstatSync,
	mkdirSync,
	readdirSync,
	readlinkSync,
	renameSync,
	rmdirSync,
	statSync,
	symlinkSync,
	unlinkSync,
} from "node:fs";
import { homedir } from "node:os";
import { join, resolve } from "node:path";

const OFF = new Set(["0", "off", "false", "no"]);
const isOff = (v: string | undefined): boolean =>
	v !== undefined && OFF.has(v.trim().toLowerCase());

const UNIFIED_NAME =
	process.env.PI_NERV_UNIFIED_SESSIONS_DIR?.trim() || "--proj-nerv--";

/** Matches the worktree session dirs to fold into the unified one. */
const MATCH = new RegExp(
	process.env.PI_NERV_UNIFIED_SESSIONS_PATTERN?.trim() ||
		"^--proj-nerv_.*--$",
);

const sessionBase = (): string =>
	join(process.env.PI_SESSION_BASE || join(homedir(), ".pi/agent"), "sessions");

export default function () {
	if (isOff(process.env.PI_NERV_UNIFIED_SESSIONS)) {
		return;
	}
	try {
		consolidate(sessionBase());
	} catch (err) {
		console.warn("nerv-unified-sessions: consolidation failed:", err);
	}
}

/**
 * Fold every matching worktree session dir into `unified` and leave a symlink
 * behind. Idempotent: once the symlinks exist this performs no writes at all.
 */
export function consolidate(base: string): void {
	if (!existsSync(base)) {
		return;
	}
	const unified = join(base, UNIFIED_NAME);

	for (const name of readdirSync(base)) {
		if (name === UNIFIED_NAME || !MATCH.test(name)) {
			continue;
		}
		const full = join(base, name);

		// lstat, not stat: stat follows the link and reports the target dir,
		// which made every already-linked dir look like a fresh one.
		let entry: ReturnType<typeof lstatSync>;
		try {
			entry = lstatSync(full);
		} catch {
			continue;
		}

		if (entry.isSymbolicLink()) {
			// Already managed: leave it completely alone. Only a link pointing
			// somewhere else gets re-pointed.
			if (pointsAt(full, unified)) {
				continue;
			}
			mkdirSync(unified, { recursive: true });
			unlinkSync(full);
			symlinkSync(unified, full);
			continue;
		}

		if (!entry.isDirectory()) {
			continue;
		}

		mkdirSync(unified, { recursive: true });
		if (!drain(full, unified)) {
			console.warn(
				`nerv-unified-sessions: left ${name} in place (could not move every session)`,
			);
			continue;
		}

		// rmdirSync refuses a non-empty dir, so this cannot eat sessions even if
		// drain() lied about being complete.
		rmdirSync(full);
		symlinkSync(unified, full);
	}
}

function pointsAt(link: string, unified: string): boolean {
	try {
		return resolve(readlinkSync(link)) === resolve(unified);
	} catch {
		return false;
	}
}

/**
 * Move every file out of `dir` into `unified`.
 * Returns true only when `dir` ended up empty, which is the precondition for
 * deleting it.
 */
function drain(dir: string, unified: string): boolean {
	let complete = true;

	for (const name of readdirSync(dir)) {
		const src = join(dir, name);
		try {
			if (!lstatSync(src).isFile()) {
				// Subdirectories are not sessions; leave them (and the parent) alone
				// rather than throwing inside copyFileSync like the old version did.
				complete = false;
				continue;
			}
			move(src, destinationFor(src, join(unified, name)));
		} catch (err) {
			console.warn(`nerv-unified-sessions: could not move ${src}:`, err);
			complete = false;
		}
	}

	return complete;
}

/**
 * Pick a free destination. An identical-size file already there is treated as
 * the same session (the previous implementation copied instead of moving, so
 * duplicates are expected); anything else is preserved under a suffix instead
 * of being silently dropped.
 */
function destinationFor(src: string, dst: string): string | undefined {
	if (!existsSync(dst)) {
		return dst;
	}
	if (statSync(src).size === statSync(dst).size) {
		return undefined; // duplicate — drop the source
	}
	return `${dst}.conflict-${Date.now()}`;
}

function move(src: string, dst: string | undefined): void {
	if (dst === undefined) {
		unlinkSync(src);
		return;
	}
	try {
		renameSync(src, dst);
	} catch (err) {
		if ((err as NodeJS.ErrnoException).code !== "EXDEV") {
			throw err;
		}
		copyFileSync(src, dst);
		unlinkSync(src);
	}
}
