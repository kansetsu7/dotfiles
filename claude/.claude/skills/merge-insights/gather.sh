#!/usr/bin/env bash
# merge-insights/gather.sh — Collects all merge data into compact structured output.
# Usage: bash gather.sh [since_date]
# Example: bash gather.sh "1 week ago"
#          bash gather.sh "2026-03-01"
set -uo pipefail

SINCE="${1:-1 week ago}"
GITLAB_URL="https://gitlab.abagile.com"
API_URL="$GITLAB_URL/api/v4"
MAX_PARALLEL="${MERGE_INSIGHTS_PARALLEL:-10}"

# --- Resolve GitLab project ID ---
PROJECT_PATH=$(git remote get-url origin 2>/dev/null \
  | sed -E 's#(ssh://)?git@gitlab\.abagile\.com(:7788)?[:/]##; s#https://gitlab\.abagile\.com/##; s#\.git$##')
ENCODED_PATH=$(echo "$PROJECT_PATH" | sed 's#/#%2F#g')
PROJECT_ID=$(curl -s --header "PRIVATE-TOKEN: $GITLAB_READONLY_TOKEN" \
  "$API_URL/projects/$ENCODED_PATH" | jq '.id')

if [ "$PROJECT_ID" = "null" ] || [ -z "$PROJECT_ID" ]; then
  echo "ERROR: Could not resolve project ID for $PROJECT_PATH" >&2
  exit 1
fi

# --- Collect merge commits ---
MERGES=$(git log master --merges --first-parent --since="$SINCE" \
  --format="%H|%ai|%s" 2>/dev/null || true)

if [ -z "$MERGES" ]; then
  echo "---METADATA---"
  echo "mode: short"
  echo "total: 0"
  exit 0
fi

TOTAL=$(echo "$MERGES" | wc -l | tr -d ' ')

# Determine mode based on date range
OLDEST_DATE=$(echo "$MERGES" | tail -1 | cut -d'|' -f2 | cut -d' ' -f1)
OLDEST_EPOCH=$(date -d "$OLDEST_DATE" +%s 2>/dev/null || echo 0)
NOW_EPOCH=$(date +%s)
DAYS_SPAN=$(( (NOW_EPOCH - OLDEST_EPOCH) / 86400 ))
if [ "$DAYS_SPAN" -gt 14 ]; then
  MODE="long"
else
  MODE="short"
fi

# --- Temp files ---
TMPDIR_WORK=$(mktemp -d)
trap "rm -rf $TMPDIR_WORK" EXIT
mkdir -p "$TMPDIR_WORK/mr_cache" "$TMPDIR_WORK/git_data"

parse_shortstat() {
  local stat="$1"
  FILES_CHANGED=$(echo "$stat" | awk -F',' '{for(i=1;i<=NF;i++) if($i ~ /file/) {gsub(/[^0-9]/,"",$i); print $i}}')
  INSERTIONS=$(echo "$stat" | awk -F',' '{for(i=1;i<=NF;i++) if($i ~ /insertion/) {gsub(/[^0-9]/,"",$i); print $i}}')
  DELETIONS=$(echo "$stat" | awk -F',' '{for(i=1;i<=NF;i++) if($i ~ /deletion/) {gsub(/[^0-9]/,"",$i); print $i}}')
  FILES_CHANGED=${FILES_CHANGED:-0}
  INSERTIONS=${INSERTIONS:-0}
  DELETIONS=${DELETIONS:-0}
}

# ===========================================================================
# Phase 1: Parallel data collection — GitLab API and git operations run
#          concurrently for each merge commit
# ===========================================================================

# Worker function: collects all data for one merge commit
collect_one_merge() {
  local SHA="$1" DATE="$2" MSG="$3" TMPDIR="$4" API_URL="$5" PROJECT_ID="$6" TOKEN="$7"

  local BRANCH=$(echo "$MSG" | sed -n "s/Merge branch '\(.*\)' into 'master'/\1/p")
  [ -z "$BRANCH" ] && return

  local SAFE_SHA="${SHA:0:12}"

  # --- GitLab API call (the slow part we're parallelizing) ---
  local ENCODED_BRANCH=$(echo "$BRANCH" | sed 's#/#%2F#g; s# #%20#g')
  curl -s --header "PRIVATE-TOKEN: $TOKEN" \
    "$API_URL/projects/$PROJECT_ID/merge_requests?state=merged&source_branch=$ENCODED_BRANCH&per_page=1" \
    | jq -r '.[0] // empty | "\(.iid)|\(.title)|\(.author.name)|\(.description // "" | gsub("\n"; " ") | .[0:200])"' \
    > "$TMPDIR/mr_cache/$SAFE_SHA" 2>/dev/null || echo "" > "$TMPDIR/mr_cache/$SAFE_SHA"

  # --- Git operations (fast, local) ---
  {
    git diff --shortstat "${SHA}^1...${SHA}" 2>/dev/null || echo ""
    echo "---SEPARATOR---"
    git diff --name-only "${SHA}^1...${SHA}" 2>/dev/null || echo ""
    echo "---SEPARATOR---"
    git log "${SHA}^1...${SHA}" --format="%s" --no-merges 2>/dev/null | head -5 | cut -c1-120
  } > "$TMPDIR/git_data/$SAFE_SHA" 2>/dev/null
}
export -f collect_one_merge

# Launch all workers in parallel
echo "$MERGES" | while IFS='|' read -r SHA DATE MSG; do
  echo "${SHA}|${DATE}|${MSG}|${TMPDIR_WORK}|${API_URL}|${PROJECT_ID}|${GITLAB_READONLY_TOKEN}"
done | xargs -I{} -P "$MAX_PARALLEL" bash -c '
  IFS="|" read -r SHA DATE MSG TMPDIR API PID TOKEN <<< "{}"
  collect_one_merge "$SHA" "$DATE" "$MSG" "$TMPDIR" "$API" "$PID" "$TOKEN"
'

# ===========================================================================
# Phase 2: Assemble output from cached results (serial, fast)
# ===========================================================================

echo "$MERGES" | while IFS='|' read -r SHA DATE MSG; do
  BRANCH=$(echo "$MSG" | sed -n "s/Merge branch '\(.*\)' into 'master'/\1/p")
  [ -z "$BRANCH" ] && continue

  SAFE_SHA="${SHA:0:12}"
  TYPE=$(echo "$BRANCH" | sed -n 's#^\(feature\|bug\|patch\|hotfix\|refactor\|doc\)/.*#\1#p')
  [ -z "$TYPE" ] && TYPE="other"
  MERGE_DATE=$(echo "$DATE" | cut -d' ' -f1)

  # Read cached git data
  if [ -f "$TMPDIR_WORK/git_data/$SAFE_SHA" ]; then
    SHORTSTAT=$(sed -n '1,/---SEPARATOR---/p' "$TMPDIR_WORK/git_data/$SAFE_SHA" | head -1)
    CHANGED_FILES=$(sed -n '/---SEPARATOR---/,/---SEPARATOR---/p' "$TMPDIR_WORK/git_data/$SAFE_SHA" \
      | grep -v '^---SEPARATOR---$' || true)
    COMMIT_MSGS=$(sed -n '/---SEPARATOR---/{n; :loop; /---SEPARATOR---/q; p; n; b loop}' "$TMPDIR_WORK/git_data/$SAFE_SHA" 2>/dev/null || true)
    # Simpler: just get everything after the second separator
    COMMIT_MSGS=$(awk '/---SEPARATOR---/{n++; next} n>=2' "$TMPDIR_WORK/git_data/$SAFE_SHA")
  else
    SHORTSTAT=""
    CHANGED_FILES=""
    COMMIT_MSGS=""
  fi

  parse_shortstat "$SHORTSTAT"

  # Save files for hotspot analysis
  echo "$CHANGED_FILES" | while read -r f; do
    [ -n "$f" ] && echo "${SHA}|${BRANCH}|${MERGE_DATE}|${TYPE}|${f}" >> "$TMPDIR_WORK/all_files.tsv"
  done

  # Read cached MR data
  MR_JSON=""
  [ -f "$TMPDIR_WORK/mr_cache/$SAFE_SHA" ] && MR_JSON=$(cat "$TMPDIR_WORK/mr_cache/$SAFE_SHA")
  MR_IID=$(echo "$MR_JSON" | cut -d'|' -f1)
  MR_TITLE=$(echo "$MR_JSON" | cut -d'|' -f2)
  MR_AUTHOR=$(echo "$MR_JSON" | cut -d'|' -f3)
  MR_DESC=$(echo "$MR_JSON" | cut -d'|' -f4-)

  echo "${MR_AUTHOR:-unknown}|${TYPE}" >> "$TMPDIR_WORK/authors.tsv"

  cat <<RECORD
---MERGE---
sha: $SAFE_SHA
date: $MERGE_DATE
branch: $BRANCH
type: $TYPE
mr_iid: ${MR_IID:-?}
mr_title: ${MR_TITLE:-$BRANCH}
author: ${MR_AUTHOR:-unknown}
files_changed: $FILES_CHANGED
insertions: $INSERTIONS
deletions: $DELETIONS
commit_messages:
$COMMIT_MSGS
mr_description_excerpt: ${MR_DESC:-}
RECORD

done

# --- Hotspot analysis ---
echo ""
echo "---HOTSPOTS---"
if [ -f "$TMPDIR_WORK/all_files.tsv" ]; then
  cut -d'|' -f5 "$TMPDIR_WORK/all_files.tsv" \
    | grep -vE '^(db/schema\.rb|db/structure\.sql|config/locales/.*\.yml)$' \
    | sort | uniq -c | sort -rn \
    | awk '$1 >= 2 { printf "%d|%s\n", $1, $2 }' \
    | head -20 \
    | while IFS='|' read -r COUNT FILE; do
      BRANCHES=$(grep -F "|${FILE}" "$TMPDIR_WORK/all_files.tsv" | grep "|${FILE}$" | cut -d'|' -f2 | sort -u | paste -sd',' -)
      TYPES=$(grep -F "|${FILE}" "$TMPDIR_WORK/all_files.tsv" | grep "|${FILE}$" | cut -d'|' -f4 | sort | uniq -c | sort -rn | awk '{printf "%s(%d) ", $2, $1}')
      echo "${COUNT}|${FILE}|${BRANCHES}|${TYPES}"
    done
fi

# --- Rapid-fix detection ---
echo ""
echo "---RAPID-FIXES---"
if [ -f "$TMPDIR_WORK/all_files.tsv" ]; then
  grep -E '\|(bug|patch|hotfix)\|' "$TMPDIR_WORK/all_files.tsv" \
    | cut -d'|' -f1-4 | sort -u \
    | while IFS='|' read -r SHA BRANCH DATE TYPE; do
      BUG_EPOCH=$(date -d "$DATE" +%s 2>/dev/null || echo 0)
      SEVEN_DAYS_BEFORE=$((BUG_EPOCH - 7*86400))

      BUG_FILES=$(grep "^${SHA}|" "$TMPDIR_WORK/all_files.tsv" | cut -d'|' -f5 \
        | grep -vE '^(db/schema\.rb|db/structure\.sql|config/locales/.*\.yml|config/system_config\.yml)$' \
        | sort -u)

      while IFS='|' read -r OTHER_SHA OTHER_BRANCH OTHER_DATE OTHER_TYPE OTHER_FILE; do
        [ "$OTHER_SHA" = "$SHA" ] && continue
        OTHER_EPOCH=$(date -d "$OTHER_DATE" +%s 2>/dev/null || echo 0)
        [ "$OTHER_EPOCH" -lt "$SEVEN_DAYS_BEFORE" ] && continue
        [ "$OTHER_EPOCH" -gt "$BUG_EPOCH" ] && continue

        if echo "$BUG_FILES" | grep -qxF "$OTHER_FILE"; then
          DAYS_APART=$(( (BUG_EPOCH - OTHER_EPOCH) / 86400 ))
          echo "${BRANCH}|${OTHER_BRANCH}|${OTHER_FILE}|${DAYS_APART}d|${TYPE}>${OTHER_TYPE}"
        fi
      done < "$TMPDIR_WORK/all_files.tsv"
    done | sort -u | head -30
fi

# --- Weekly density ---
echo ""
echo "---WEEKLY-DENSITY---"
echo "$MERGES" | while IFS='|' read -r SHA DATE MSG; do
  BRANCH=$(echo "$MSG" | sed -n "s/Merge branch '\(.*\)' into 'master'/\1/p")
  TYPE=$(echo "$BRANCH" | sed -n 's#^\(feature\|bug\|patch\|hotfix\|refactor\|doc\)/.*#\1#p')
  [ -z "$TYPE" ] && TYPE="other"
  WEEK=$(date -d "$(echo "$DATE" | cut -d' ' -f1)" +%Y-W%V 2>/dev/null || echo "unknown")
  echo "$WEEK|$TYPE"
done | sort | uniq -c | awk '{ print $2 "|" $1 }' | sort

# --- Author summary (from cached data, no extra API calls) ---
echo ""
echo "---AUTHORS---"
if [ -f "$TMPDIR_WORK/authors.tsv" ]; then
  sort "$TMPDIR_WORK/authors.tsv" | uniq -c | sort -rn
fi

echo ""
echo "---METADATA---"
echo "mode: $MODE"
echo "total: $TOTAL"
echo "days_span: $DAYS_SPAN"
echo "since: $SINCE"
echo "project: $PROJECT_PATH (ID: $PROJECT_ID)"
