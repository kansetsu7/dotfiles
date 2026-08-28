/**
 * nerv-unified-sessions — route all Nerv worktree sessions to a unified directory
 * 
 * Why: The Nerv project has multiple worktrees (nerv_hk, nerv_ck, nerv_sg, nerv_ave_ck)
 * that represent different subsidiaries but share most features. Sessions should be
 * accessible from any worktree, not locked to the one where they were created.
 * 
 * Approach: Uses symlink consolidation. All nerv_* session directories are symlinked
 * to a unified --proj-nerv-- directory, so new sessions automatically go there.
 */

import { type ExtensionAPI } from "@earendil-works/pi-coding-agent";

const fs = require("fs");
const path = require("path");

const OFF = new Set(["0", "off", "false", "no"]);
const isOff = (v: string | undefined): boolean =>
	v !== undefined && OFF.has(v.trim().toLowerCase());

const ENABLED = !isOff(process.env.PI_NERV_UNIFIED_SESSIONS);
const NERV_PATTERN = /\bnerv_(hk|ck|sg|ave_ck)\b/;
const SESSION_BASE = path.join(process.env.HOME || "/root", ".pi/agent/sessions");
const UNIFIED_DIR = path.join(SESSION_BASE, "--proj-nerv--");

export default function (api: ExtensionAPI) {
	if (!ENABLED) {
		return;
	}

	// On first load, consolidate and symlink existing session dirs
	try {
		ensureConsolidation();
	} catch (err) {
		console.warn("nerv-unified-sessions: consolidation failed:", err);
	}
}

function ensureConsolidation() {
	// Create unified directory if it doesn't exist
	if (!fs.existsSync(UNIFIED_DIR)) {
		fs.mkdirSync(UNIFIED_DIR, { recursive: true });
	}

	// Scan for nerv_* session directories and symlink them
	const files = fs.readdirSync(SESSION_BASE);

	files.forEach((file: string) => {
		const fullPath = path.join(SESSION_BASE, file);
		const stat = fs.statSync(fullPath);

		// Match --proj-nerv_*-- pattern
		if (
			stat.isDirectory() &&
			file.startsWith("--proj-nerv_") &&
			file.endsWith("--")
		) {
			// If it's a real directory (not a symlink), move its sessions to unified
			if (!stat.isSymbolicLink()) {
				moveSessionsToUnified(fullPath);
				// Replace it with a symlink
				fs.rmSync(fullPath, { recursive: true });
				fs.symlinkSync(UNIFIED_DIR, fullPath);
			}
		}
	});
}

function moveSessionsToUnified(sourceDir: string) {
	try {
		const sessions = fs.readdirSync(sourceDir);
		sessions.forEach((file: string) => {
			const src = path.join(sourceDir, file);
			const dst = path.join(UNIFIED_DIR, file);

			// Skip if destination already exists
			if (!fs.existsSync(dst)) {
				fs.copyFileSync(src, dst);
			}
		});
	} catch (err) {
		console.warn(`Failed to move sessions from ${sourceDir}:`, err);
	}
}
