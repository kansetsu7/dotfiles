#!/usr/bin/env bash
# Mechanical half of the pi extension audit.
#
# Emits a compact report on stdout. Everything here is deterministic — no LLM
# judgment. The SKILL.md workflow layers changelog reading on top.
#
# Usage: audit.sh [--json-state <path>] [--no-net]
set -uo pipefail

DOTFILES="${DOTFILES:-$HOME/.dotfiles}"
STATE="${DOTFILES}/pi/.pi/agent/extension-audit.json"
EXT_SRC="${DOTFILES}/pi/.pi/agent/extensions"
NO_NET=0

while [ $# -gt 0 ]; do
	case "$1" in
		--json-state) STATE="$2"; shift 2 ;;
		--no-net) NO_NET=1; shift ;;
		*) echo "unknown arg: $1" >&2; exit 2 ;;
	esac
done

say() { printf '%s\n' "$*"; }
hr()  { printf '\n== %s ==\n' "$*"; }

# ---------- locate pi ----------
PI_BIN="$(command -v pi || true)"
[ -n "$PI_BIN" ] || { say "FATAL: pi not on PATH"; exit 1; }
PI_PKG="$(cd "$(dirname "$(readlink -f "$PI_BIN")")/../.." && pwd)"
[ -f "$PI_PKG/package.json" ] || { say "FATAL: cannot locate pi package from $PI_BIN"; exit 1; }

CUR_VER="$(node -p "require('$PI_PKG/package.json').version")"
PREV_VER="null"
[ -f "$STATE" ] && PREV_VER="$(node -p "try{require('$STATE').lastAuditedVersion||'null'}catch(e){'null'}")"

say "pi package:      $PI_PKG"
say "current version: $CUR_VER"
say "last audited:    $PREV_VER"
say "extensions dir:  $EXT_SRC"

[ -d "$EXT_SRC" ] || { say "FATAL: no extensions dir at $EXT_SRC"; exit 1; }

if [ "$PREV_VER" = "$CUR_VER" ]; then
	say "NOTE: already audited at $CUR_VER — re-running anyway."
fi

# ---------- build typecheck harness ----------
HARNESS="$(mktemp -d)"
trap 'rm -rf "$HARNESS"' EXIT
mkdir -p "$HARNESS/node_modules/@earendil-works"
cp -r "$EXT_SRC"/* "$HARNESS"/ 2>/dev/null || true

VENDOR="$PI_PKG/node_modules/@earendil-works"
ln -sfn "$PI_PKG"                     "$HARNESS/node_modules/@earendil-works/pi-coding-agent"
for p in pi-tui pi-ai; do
	[ -d "$VENDOR/$p" ] && ln -sfn "$VENDOR/$p" "$HARNESS/node_modules/@earendil-works/$p"
done
[ -d "$PI_PKG/node_modules/@types" ] && ln -sfn "$PI_PKG/node_modules/@types" "$HARNESS/node_modules/@types"

TSC=""
for c in "$(dirname "$PI_PKG")/../typescript/bin/tsc" "$PI_PKG/node_modules/typescript/bin/tsc"; do
	[ -f "$c" ] && TSC="$c" && break
done
[ -n "$TSC" ] || TSC="$(command -v tsc || true)"

cat > "$HARNESS/tsconfig.json" <<'JSON'
{
  "compilerOptions": {
    "target": "ES2022",
    "module": "nodenext",
    "moduleResolution": "nodenext",
    "allowImportingTsExtensions": true,
    "noEmit": true,
    "strict": true,
    "skipLibCheck": true,
    "types": ["node"]
  },
  "include": ["*/*.ts", "*.ts"]
}
JSON

hr "TYPECHECK (against $CUR_VER .d.ts)"
if [ -z "$TSC" ]; then
	say "SKIP: no tsc found"
	TC_RC=99
else
	( cd "$HARNESS" && node "$TSC" -p tsconfig.json 2>&1 ) | sed 's/^/  /'
	TC_RC=${PIPESTATUS[0]}
	[ "$TC_RC" -eq 0 ] && say "  clean — no type errors"
fi

# ---------- tests ----------
hr "TESTS"
TEST_FAIL=0
for d in "$EXT_SRC"/*/; do
	name="$(basename "$d")"
	if [ -f "$d/test.mjs" ]; then
		out="$(cd "$d" && timeout 180 node test.mjs 2>&1 | tail -1)"
		printf '  %-24s %s\n' "$name" "$out"
		case "$out" in *"0 failed"*) ;; *) TEST_FAIL=1 ;; esac
	else
		printf '  %-24s NO TESTS\n' "$name"
	fi
done

# ---------- export surface diff ----------
hr "EXPORT SURFACE DIFF ($PREV_VER -> $CUR_VER)"
OLD_DTS=""
if [ "$PREV_VER" = "null" ]; then
	say "  no recorded baseline — skipping (this run will set one)"
elif [ "$PREV_VER" = "$CUR_VER" ]; then
	say "  same version — nothing to diff"
elif [ "$NO_NET" -eq 1 ]; then
	say "  --no-net — skipped"
else
	TARBALL_DIR="$(mktemp -d)"
	URL="$(timeout 60 npm view "@earendil-works/pi-coding-agent@$PREV_VER" dist.tarball 2>/dev/null | tail -1)"
	if [ -n "$URL" ] && timeout 180 curl -sL "$URL" -o "$TARBALL_DIR/p.tgz" 2>/dev/null; then
		( cd "$TARBALL_DIR" && tar xzf p.tgz package/dist/index.d.ts package/dist/core/extensions/types.d.ts 2>/dev/null )
		[ -f "$TARBALL_DIR/package/dist/index.d.ts" ] && OLD_DTS="$TARBALL_DIR/package"
	fi
	[ -n "$OLD_DTS" ] || say "  could not fetch $PREV_VER from npm (offline?) — skipped"
fi

if [ -n "$OLD_DTS" ]; then
	node - "$OLD_DTS" "$PI_PKG" "$EXT_SRC" <<'NODE'
const fs = require("node:fs");
const path = require("node:path");
const [, , oldRoot, newRoot, extSrc] = process.argv;

// Names exported from a barrel .d.ts: everything inside `export { ... }` /
// `export type { ... }` braces, plus `export declare X` / `export interface X`.
function surface(root) {
	const names = new Set();
	for (const rel of ["dist/index.d.ts", "dist/core/extensions/types.d.ts"]) {
		const f = path.join(root, rel);
		if (!fs.existsSync(f)) continue;
		const src = fs.readFileSync(f, "utf8");
		for (const m of src.matchAll(/export\s+(?:type\s+)?\{([^}]*)\}/g)) {
			for (let n of m[1].split(",")) {
				n = n.trim().replace(/^type\s+/, "").split(/\s+as\s+/).pop().trim();
				if (/^[A-Za-z_$][\w$]*$/.test(n)) names.add(n);
			}
		}
		for (const m of src.matchAll(/export\s+(?:declare\s+)?(?:interface|type|class|function|const)\s+([A-Za-z_$][\w$]*)/g)) {
			names.add(m[1]);
		}
	}
	return names;
}

// What our extensions actually import from @earendil-works/*
function imported(dir) {
	const used = new Map();
	const walk = (d) => {
		for (const e of fs.readdirSync(d, { withFileTypes: true })) {
			const p = path.join(d, e.name);
			if (e.isDirectory()) walk(p);
			else if (/\.(ts|mts|mjs)$/.test(e.name)) {
				const src = fs.readFileSync(p, "utf8");
				for (const m of src.matchAll(/import\s+(?:type\s+)?\{([^}]*)\}\s*from\s*["'](@earendil-works\/[^"']+)["']/g)) {
					for (let n of m[1].split(",")) {
						n = n.trim().replace(/^type\s+/, "").split(/\s+as\s+/)[0].trim();
						if (n) used.set(n, { file: path.relative(extSrc, p), mod: m[2] });
					}
				}
			}
		}
	};
	walk(dir);
	return used;
}

const oldS = surface(oldRoot), newS = surface(newRoot), used = imported(extSrc);
const removed = [...oldS].filter((n) => !newS.has(n)).sort();
const added = [...newS].filter((n) => !oldS.has(n)).sort();

const CORE = "@earendil-works/pi-coding-agent";
const fromCore = (n) => used.has(n) && used.get(n).mod === CORE;
const where = (n) => `${used.get(n).file}`;

const impacting = removed.filter(fromCore);
console.log(`  removed/renamed exports: ${removed.length}   new exports: ${added.length}`);
if (impacting.length) {
	console.log("  !! REMOVED AND USED BY YOUR EXTENSIONS:");
	for (const n of impacting) console.log(`     - ${n}   (${where(n)})`);
} else {
	console.log("  none of the removed exports are imported by your extensions");
}
if (removed.length) console.log(`  (all removed: ${removed.slice(0, 40).join(", ")}${removed.length > 40 ? " ..." : ""})`);

// Imports from pi-coding-agent that resolve to nothing in the current surface.
// Only core imports are checked — pi-tui/pi-ai have their own surfaces.
const dangling = [...used.keys()].filter((n) => fromCore(n) && !newS.has(n));
if (dangling.length) {
	console.log("\n  !! imported from pi-coding-agent but NOT in its current surface:");
	for (const n of dangling) console.log(`     - ${n}   (${where(n)})`);
	console.log("     ^ latent even if pre-existing: type-only imports are erased at runtime");
}
NODE
fi

# ---------- changelog slice ----------
hr "CHANGELOG RANGE"
if [ "$PREV_VER" = "null" ] || [ "$PREV_VER" = "$CUR_VER" ]; then
	say "  nothing to slice"
else
	CL="$PI_PKG/CHANGELOG.md"
	if [ -f "$CL" ]; then
		END_LINE="$(grep -n "^## \[$PREV_VER\]" "$CL" | head -1 | cut -d: -f1)"
		if [ -n "$END_LINE" ]; then
			say "  $CL lines 1..$((END_LINE - 1)) cover $PREV_VER -> $CUR_VER"
			say "  versions in range:"
			sed -n "1,$((END_LINE - 1))p" "$CL" | grep '^## \[' | sed 's/^/    /'
		else
			say "  $PREV_VER not found in CHANGELOG.md — read from the top"
		fi
	fi
fi

hr "SUMMARY"
say "  typecheck: $([ "${TC_RC:-1}" -eq 0 ] && echo PASS || echo "FAIL/SKIP (rc=${TC_RC:-?})")"
say "  tests:     $([ "$TEST_FAIL" -eq 0 ] && echo PASS || echo FAIL)"
say "  state file: $STATE"
say ""
say "If the audit concludes clean, record it:"
say "  node -e 'const f=\"$STATE\";const s=require(\"node:fs\");s.mkdirSync(require(\"node:path\").dirname(f),{recursive:true});s.writeFileSync(f,JSON.stringify({lastAuditedVersion:\"$CUR_VER\",auditedAt:new Date().toISOString().slice(0,10)},null,2)+\"\\n\")'"
