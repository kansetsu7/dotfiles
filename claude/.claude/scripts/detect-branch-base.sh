#!/bin/sh
# Detect the commit the current branch was created from.
#
# Usage: detect-branch-base.sh [override-ref]
#
# Prints KEY=VALUE lines on stdout:
#   BASE_COMMIT   commit the branch forked from (empty if branch reaches a root commit)
#   BASE_REF      branch that best explains BASE_COMMIT (may be empty)
#   METHOD        how BASE_COMMIT was found (see below)
#   COMMIT_COUNT  commits in BASE_COMMIT..HEAD
#   CONFIDENCE    high | medium | low
#   NOTE          human-readable caveat (may be empty)
#
# METHOD values:
#   override        caller passed an explicit ref
#   unique-commits  commits reachable from HEAD but from no other branch
#   root            branch reaches a root commit; whole history is the range
#   fork-suffix     fell back to `<branch>-fork` -> `<branch>` convention
#   default-branch  fell back to merge-base with master/main
#   on-default      HEAD is master/main; there is no branch to summarize
#   none            nothing usable found
#
# The primary method asks: which commits are reachable from HEAD but from no
# other local or remote branch? The oldest of those is this branch's first
# commit, so its parent is the fork point. Refs for the current branch itself
# (local and any remote copy) are excluded, otherwise a pushed branch would
# exclude all of its own commits.

set -u

emit() {
    printf 'BASE_COMMIT=%s\nBASE_REF=%s\nMETHOD=%s\nCOMMIT_COUNT=%s\nCONFIDENCE=%s\nNOTE=%s\n' \
        "$1" "$2" "$3" "$4" "$5" "$6"
    exit 0
}

git rev-parse --git-dir >/dev/null 2>&1 || {
    emit "" "" "none" "0" "low" "not a git repository"
}

CUR=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo HEAD)
DETACHED=""
[ "$CUR" = "HEAD" ] && DETACHED="detached HEAD; current branch could not be excluded from the search"

count_range() {
    # commits in $1..HEAD; whole history when $1 is empty
    if [ -n "$1" ]; then
        git rev-list --count "$1..HEAD" 2>/dev/null || echo 0
    else
        git rev-list --count HEAD 2>/dev/null || echo 0
    fi
}

# Name the branch that best explains a base commit: among refs containing it,
# the one whose tip is closest. Local refs win ties over remote ones.
name_ref() {
    base="$1"
    [ -z "$base" ] && return
    git for-each-ref --format='%(refname:short)' --contains "$base" \
        refs/heads refs/remotes 2>/dev/null |
        while IFS= read -r ref; do
            case "$ref" in
                "$CUR" | */"$CUR") continue ;;
                */HEAD) continue ;;
            esac
            dist=$(git rev-list --count "$base..$ref" 2>/dev/null || echo 999999)
            case "$ref" in
                */*/* | origin/*) tier=1 ;;
                *) tier=0 ;;
            esac
            printf '%s %s %s\n' "$dist" "$tier" "$ref"
        done | sort -k1,1n -k2,2n | head -1 | cut -d' ' -f3
}

# 1. Explicit override.
if [ $# -gt 0 ] && [ -n "$1" ]; then
    if sha=$(git rev-parse --verify --quiet "$1^{commit}"); then
        mb=$(git merge-base "$sha" HEAD 2>/dev/null || echo "$sha")
        emit "$mb" "$1" "override" "$(count_range "$mb")" "high" ""
    fi
    emit "" "" "none" "0" "low" "override ref '$1' does not resolve to a commit"
fi

# 2. On the default branch there is no fork point to find. Without this guard
# the search below would happily report where the newest run of master-only
# commits began, which is not a merge request base.
case "$CUR" in
    master | main)
        emit "" "$CUR" "on-default" "0" "low" \
            "HEAD is the default branch '$CUR'; pass a base ref explicitly to compare against it"
        ;;
esac

# 3. Oldest commit unique to this branch -> its parent is the fork point.
FIRST=$(git rev-list HEAD --not \
    --exclude="$CUR" --branches \
    --exclude="*/$CUR" --remotes 2>/dev/null | tail -1)

if [ -n "$FIRST" ]; then
    if parent=$(git rev-parse --verify --quiet "$FIRST^{commit}^"); then
        emit "$parent" "$(name_ref "$parent")" "unique-commits" \
            "$(count_range "$parent")" "high" "$DETACHED"
    fi
    emit "" "" "root" "$(count_range "")" "high" \
        "branch reaches a root commit; summarize the whole history"
fi

# No unique commits: every commit here is also on another branch. That happens
# when a child branch was cut from this one, when the branch was already
# merged, or on a branch that has no commits of its own yet.
NOTE="no commits unique to this branch (already merged, or another branch points at HEAD)"
[ -n "$DETACHED" ] && NOTE="$NOTE; $DETACHED"

# 4. The `-fork` naming convention.
case "$CUR" in
    *-fork)
        parent_branch=${CUR%-fork}
        if git rev-parse --verify --quiet "$parent_branch^{commit}" >/dev/null; then
            mb=$(git merge-base "$parent_branch" HEAD)
            emit "$mb" "$parent_branch" "fork-suffix" "$(count_range "$mb")" "medium" "$NOTE"
        fi
        ;;
esac

# 5. Default branch.
for b in master main origin/master origin/main; do
    if git rev-parse --verify --quiet "$b^{commit}" >/dev/null; then
        mb=$(git merge-base "$b" HEAD 2>/dev/null) || continue
        emit "$mb" "$b" "default-branch" "$(count_range "$mb")" "low" "$NOTE"
    fi
done

emit "" "" "none" "0" "low" "$NOTE"
