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

# Classify branch type using prefix first, then content signals.
# Args: branch_name, commit_messages, mr_title
classify_type() {
  local branch="$1" msgs="$2" mr_title="$3"
  local prefix_type
  prefix_type=$(echo "$branch" | sed -n 's#^\(feature\|bug\|patch\|hotfix\|refactor\|doc\)/.*#\1#p')

  # Trust explicit bug/patch/hotfix/refactor/doc prefixes
  if [ -n "$prefix_type" ] && [ "$prefix_type" != "feature" ]; then
    echo "$prefix_type"
    return
  fi

  # For feature/ or unprefixed branches, scan content for fix signals
  local text
  text=$(printf "%s\n%s" "$msgs" "$mr_title" | tr '[:upper:]' '[:lower:]')
  if echo "$text" | grep -qiE '\bfix(e[sd])?\b|\bbug\b|\bhotfix\b|\bpatch(e[sd])?\s+(data|record|amount|balance)|\brevert\b|\brepair\b|\bcorrect(ed|ion)?\b'; then
    echo "bug"
    return
  fi

  echo "${prefix_type:-other}"
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

  # --- GitLab API calls ---
  local ENCODED_BRANCH=$(echo "$BRANCH" | sed 's#/#%2F#g; s# #%20#g')
  local MR_RAW
  MR_RAW=$(curl -s --header "PRIVATE-TOKEN: $TOKEN" \
    "$API_URL/projects/$PROJECT_ID/merge_requests?state=merged&source_branch=$ENCODED_BRANCH&per_page=1")
  echo "$MR_RAW" \
    | jq -r '.[0] // empty | "\(.iid)|\(.title)|\(.author.name)|\(.description // "" | gsub("\n"; " ") | .[0:200])|\(.created_at // "")|\(.merged_at // "")|\([.reviewers[]?.name] | join(","))"' \
    > "$TMPDIR/mr_cache/$SAFE_SHA" 2>/dev/null || echo "" > "$TMPDIR/mr_cache/$SAFE_SHA"

  # Fetch pipeline data if MR found
  local MR_IID
  MR_IID=$(echo "$MR_RAW" | jq -r '.[0].iid // empty')
  if [ -n "$MR_IID" ]; then
    curl -s --header "PRIVATE-TOKEN: $TOKEN" \
      "$API_URL/projects/$PROJECT_ID/merge_requests/$MR_IID/pipelines?per_page=100" \
      | jq -r 'length as $total | [.[] | select(.status == "failed")] | length as $failed | "\($total)|\($failed)"' \
      > "$TMPDIR/mr_cache/${SAFE_SHA}_pipelines" 2>/dev/null || echo "0|0" > "$TMPDIR/mr_cache/${SAFE_SHA}_pipelines"
  fi

  # --- Git operations (fast, local) ---
  {
    git diff --shortstat "${SHA}^1...${SHA}" 2>/dev/null || echo ""
    echo "---SEPARATOR---"
    git diff --name-only "${SHA}^1...${SHA}" 2>/dev/null || echo ""
    echo "---SEPARATOR---"
    git log "${SHA}^1...${SHA}" --format="%s" --no-merges 2>/dev/null | head -5 | cut -c1-120
    echo "---SEPARATOR---"
    git log "${SHA}^1...${SHA}" --reverse --format="%ai" --no-merges 2>/dev/null | head -1
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
  MERGE_DATE=$(echo "$DATE" | cut -d' ' -f1)

  # Read cached git data
  if [ -f "$TMPDIR_WORK/git_data/$SAFE_SHA" ]; then
    SHORTSTAT=$(sed -n '1,/---SEPARATOR---/p' "$TMPDIR_WORK/git_data/$SAFE_SHA" | head -1)
    CHANGED_FILES=$(sed -n '/---SEPARATOR---/,/---SEPARATOR---/p' "$TMPDIR_WORK/git_data/$SAFE_SHA" \
      | grep -v '^---SEPARATOR---$' || true)
    COMMIT_MSGS=$(awk '/---SEPARATOR---/{n++; next} n==2' "$TMPDIR_WORK/git_data/$SAFE_SHA")
    FIRST_COMMIT_DATE=$(awk '/---SEPARATOR---/{n++; next} n==3 && NF' "$TMPDIR_WORK/git_data/$SAFE_SHA" | head -1 | cut -d' ' -f1)
  else
    SHORTSTAT=""
    CHANGED_FILES=""
    COMMIT_MSGS=""
    FIRST_COMMIT_DATE=""
  fi

  parse_shortstat "$SHORTSTAT"

  # Read cached MR data (format: iid|title|author|desc|created_at|merged_at|reviewers)
  MR_LINE=""
  [ -f "$TMPDIR_WORK/mr_cache/$SAFE_SHA" ] && MR_LINE=$(cat "$TMPDIR_WORK/mr_cache/$SAFE_SHA")
  MR_IID=$(echo "$MR_LINE" | cut -d'|' -f1)
  MR_TITLE=$(echo "$MR_LINE" | cut -d'|' -f2)
  MR_AUTHOR=$(echo "$MR_LINE" | cut -d'|' -f3)
  # Fields from the end: reviewers(last), merged_at(2nd-last), created_at(3rd-last)
  MR_REVIEWERS=$(echo "$MR_LINE" | awk -F'|' '{print $NF}')
  MR_MERGED_AT=$(echo "$MR_LINE" | awk -F'|' '{print $(NF-1)}')
  MR_CREATED_AT=$(echo "$MR_LINE" | awk -F'|' '{print $(NF-2)}')
  # Description is everything between field 4 and the last 3 fields
  MR_DESC=$(echo "$MR_LINE" | awk -F'|' '{for(i=4;i<=NF-3;i++) printf "%s%s",$i,(i<NF-3?"|":""); print ""}')

  # Read cached pipeline data
  PIPELINE_RUNS=0; PIPELINE_FAILURES=0
  if [ -f "$TMPDIR_WORK/mr_cache/${SAFE_SHA}_pipelines" ]; then
    PIPELINE_RUNS=$(cut -d'|' -f1 "$TMPDIR_WORK/mr_cache/${SAFE_SHA}_pipelines")
    PIPELINE_FAILURES=$(cut -d'|' -f2 "$TMPDIR_WORK/mr_cache/${SAFE_SHA}_pipelines")
  fi

  # Compute time-to-merge (hours) and cycle time (hours)
  TTM_HOURS=""
  if [ -n "$MR_CREATED_AT" ] && [ -n "$MR_MERGED_AT" ]; then
    CREATED_EPOCH=$(date -d "$MR_CREATED_AT" +%s 2>/dev/null || echo "")
    MERGED_EPOCH=$(date -d "$MR_MERGED_AT" +%s 2>/dev/null || echo "")
    if [ -n "$CREATED_EPOCH" ] && [ -n "$MERGED_EPOCH" ]; then
      TTM_HOURS=$(( (MERGED_EPOCH - CREATED_EPOCH) / 3600 ))
    fi
  fi
  CYCLE_HOURS=""
  if [ -n "$FIRST_COMMIT_DATE" ] && [ -n "$MR_MERGED_AT" ]; then
    FC_EPOCH=$(date -d "$FIRST_COMMIT_DATE" +%s 2>/dev/null || echo "")
    MERGED_EPOCH=$(date -d "$MR_MERGED_AT" +%s 2>/dev/null || echo "")
    if [ -n "$FC_EPOCH" ] && [ -n "$MERGED_EPOCH" ]; then
      CYCLE_HOURS=$(( (MERGED_EPOCH - FC_EPOCH) / 3600 ))
    fi
  fi

  # Detect test and doc file changes
  HAS_TESTS="no"
  echo "$CHANGED_FILES" | grep -qE '(^|/)spec/|_spec\.rb$|_test\.(rb|go|js|ts)$|(^|/)test/' && HAS_TESTS="yes"
  HAS_DOCS="no"
  echo "$CHANGED_FILES" | grep -qiE 'changelog|readme|\.md$|(^|/)doc/' && HAS_DOCS="yes"

  # Classify type using branch prefix + content signals
  TYPE=$(classify_type "$BRANCH" "$COMMIT_MSGS" "$MR_TITLE")

  # Save SHA→TYPE mapping for weekly density
  echo "${SHA}|${TYPE}" >> "$TMPDIR_WORK/type_map.tsv"

  # Save files for hotspot analysis
  echo "$CHANGED_FILES" | while read -r f; do
    [ -n "$f" ] && echo "${SHA}|${BRANCH}|${MERGE_DATE}|${TYPE}|${f}" >> "$TMPDIR_WORK/all_files.tsv"
  done

  echo "${MR_AUTHOR:-unknown}|${TYPE}" >> "$TMPDIR_WORK/authors.tsv"

  # Track new metrics in temp files
  [ -n "$TTM_HOURS" ] && echo "${SAFE_SHA}|${BRANCH}|${TTM_HOURS}" >> "$TMPDIR_WORK/ttm.tsv"
  [ -n "$CYCLE_HOURS" ] && echo "${SAFE_SHA}|${BRANCH}|${CYCLE_HOURS}" >> "$TMPDIR_WORK/cycle.tsv"
  echo "${INSERTIONS:-0}" >> "$TMPDIR_WORK/sizes.tsv"
  echo "${SAFE_SHA}|${HAS_TESTS}" >> "$TMPDIR_WORK/test_coverage.tsv"
  echo "${SAFE_SHA}|${HAS_DOCS}" >> "$TMPDIR_WORK/doc_changes.tsv"
  echo "${PIPELINE_RUNS}|${PIPELINE_FAILURES}" >> "$TMPDIR_WORK/pipelines.tsv"
  # Track each reviewer for load analysis
  if [ -n "$MR_REVIEWERS" ]; then
    echo "$MR_REVIEWERS" | tr ',' '\n' | while read -r reviewer; do
      [ -n "$reviewer" ] && echo "$reviewer" >> "$TMPDIR_WORK/reviewers.tsv"
    done
  fi

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
time_to_merge_hours: ${TTM_HOURS:-?}
cycle_time_hours: ${CYCLE_HOURS:-?}
reviewers: ${MR_REVIEWERS:-?}
has_tests: $HAS_TESTS
has_docs: $HAS_DOCS
pipeline_runs: $PIPELINE_RUNS
pipeline_failures: $PIPELINE_FAILURES
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
  # Look up content-aware type from Phase 2
  TYPE=$(grep "^${SHA}|" "$TMPDIR_WORK/type_map.tsv" 2>/dev/null | head -1 | cut -d'|' -f2)
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

# --- Review metrics ---
echo ""
echo "---REVIEW-METRICS---"
if [ -f "$TMPDIR_WORK/ttm.tsv" ]; then
  echo "time_to_merge:"
  while IFS='|' read -r SHA BRANCH HOURS; do
    echo "  ${BRANCH}|${HOURS}h"
  done < "$TMPDIR_WORK/ttm.tsv"
  AVG_TTM=$(awk -F'|' '{sum+=$3; n++} END{if(n>0) printf "%d", sum/n}' "$TMPDIR_WORK/ttm.tsv")
  echo "avg_ttm_hours: ${AVG_TTM:-?}"
fi
if [ -f "$TMPDIR_WORK/cycle.tsv" ]; then
  echo "cycle_time:"
  while IFS='|' read -r SHA BRANCH HOURS; do
    echo "  ${BRANCH}|${HOURS}h"
  done < "$TMPDIR_WORK/cycle.tsv"
  AVG_CYCLE=$(awk -F'|' '{sum+=$3; n++} END{if(n>0) printf "%d", sum/n}' "$TMPDIR_WORK/cycle.tsv")
  echo "avg_cycle_hours: ${AVG_CYCLE:-?}"
fi

# --- MR size distribution ---
echo ""
echo "---SIZE-DISTRIBUTION---"
if [ -f "$TMPDIR_WORK/sizes.tsv" ]; then
  awk '
    { v=$1+0
      if (v < 10) xs++
      else if (v < 50) s++
      else if (v < 200) m++
      else if (v < 500) l++
      else xl++
    }
    END {
      printf "xs(<10):%d\ns(10-50):%d\nm(50-200):%d\nl(200-500):%d\nxl(500+):%d\n",
        xs+0, s+0, m+0, l+0, xl+0
    }
  ' "$TMPDIR_WORK/sizes.tsv"
fi

# --- Test coverage signal ---
echo ""
echo "---TEST-COVERAGE---"
if [ -f "$TMPDIR_WORK/test_coverage.tsv" ]; then
  WITH=$(grep -c '|yes$' "$TMPDIR_WORK/test_coverage.tsv" || echo 0)
  WITHOUT=$(grep -c '|no$' "$TMPDIR_WORK/test_coverage.tsv" || echo 0)
  TOTAL_TC=$((WITH + WITHOUT))
  RATIO=0
  [ "$TOTAL_TC" -gt 0 ] && RATIO=$((WITH * 100 / TOTAL_TC))
  echo "with_tests: $WITH"
  echo "without_tests: $WITHOUT"
  echo "ratio: ${RATIO}%"
fi

# --- Documentation changes ---
echo ""
echo "---DOC-CHANGES---"
if [ -f "$TMPDIR_WORK/doc_changes.tsv" ]; then
  WITH=$(grep -c '|yes$' "$TMPDIR_WORK/doc_changes.tsv" || echo 0)
  WITHOUT=$(grep -c '|no$' "$TMPDIR_WORK/doc_changes.tsv" || echo 0)
  echo "with_docs: $WITH"
  echo "without_docs: $WITHOUT"
fi

# --- Pipeline health ---
echo ""
echo "---PIPELINE-HEALTH---"
if [ -f "$TMPDIR_WORK/pipelines.tsv" ]; then
  awk -F'|' '
    { runs+=$1; failures+=$2 }
    END {
      rate=0; if (runs > 0) rate=int(failures * 100 / runs)
      printf "total_runs:%d\ntotal_failures:%d\nfailure_rate:%d%%\n", runs, failures, rate
    }
  ' "$TMPDIR_WORK/pipelines.tsv"
fi

# --- Reviewer load ---
echo ""
echo "---REVIEWERS---"
if [ -f "$TMPDIR_WORK/reviewers.tsv" ]; then
  sort "$TMPDIR_WORK/reviewers.tsv" | uniq -c | sort -rn
fi

echo ""
echo "---METADATA---"
echo "mode: $MODE"
echo "total: $TOTAL"
echo "days_span: $DAYS_SPAN"
echo "since: $SINCE"
echo "project: $PROJECT_PATH (ID: $PROJECT_ID)"
