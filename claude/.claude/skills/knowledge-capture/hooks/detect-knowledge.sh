#!/bin/bash
# Hook: Detect knowledge signals in user prompts
# Triggered on: PreToolUse or user prompt submission
# Supports context capture for better topic inference

set -euo pipefail

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="$SKILL_DIR/config.json"
KNOWLEDGE_BASE="${HOME}/.claude/knowledge"

# Detect project from git root
get_project() {
    local git_root
    git_root=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "_global"; return; }
    local basename=$(basename "$git_root")

    # Check aliases in config
    local alias=$(jq -r --arg name "$basename" '.projects.aliases[$name] // empty' "$CONFIG_FILE" 2>/dev/null)
    if [[ -n "$alias" ]]; then
        echo "$alias"
    else
        echo "$basename"
    fi
}

PROJECT=$(get_project)
PROJECT_BASE="${KNOWLEDGE_BASE}/${PROJECT}"
SIGNALS_FILE="${PROJECT_BASE}/signals.jsonl"

# Ensure signals directory exists
mkdir -p "$PROJECT_BASE"

# Read hook input from stdin
INPUT=$(cat)

# Extract fields from hook payload
USER_MESSAGE=$(echo "$INPUT" | jq -r '.user_message // .content // empty' 2>/dev/null || echo "")
SOURCE_FILE=$(echo "$INPUT" | jq -r '.source_file // empty' 2>/dev/null || echo "")
LINE_NUMBER=$(echo "$INPUT" | jq -r '.line_number // empty' 2>/dev/null || echo "")
FILE_TOPIC=$(echo "$INPUT" | jq -r '.file_topic // empty' 2>/dev/null || echo "")
CONTEXT_BEFORE=$(echo "$INPUT" | jq -r '.context_before // empty' 2>/dev/null || echo "")
CONTEXT_AFTER=$(echo "$INPUT" | jq -r '.context_after // empty' 2>/dev/null || echo "")

if [[ -z "$USER_MESSAGE" ]]; then
    exit 0
fi

# Load config
CONTEXT_LINES_BEFORE=$(jq -r '.detection.context_lines_before // 5' "$CONFIG_FILE" 2>/dev/null)
CONTEXT_LINES_AFTER=$(jq -r '.detection.context_lines_after // 2' "$CONFIG_FILE" 2>/dev/null)

# Load patterns from config
EXPLICIT_PATTERNS=$(jq -r '.detection.patterns.explicit[]' "$CONFIG_FILE" 2>/dev/null)
DOMAIN_PATTERNS=$(jq -r '.detection.patterns.domain[]' "$CONFIG_FILE" 2>/dev/null)
CORRECTION_PATTERNS=$(jq -r '.detection.patterns.correction[]' "$CONFIG_FILE" 2>/dev/null)

detect_signal() {
    local message="$1"
    local signal_type=""
    local matched_pattern=""

    # Check explicit signals (case-insensitive)
    while IFS= read -r pattern; do
        if echo "$message" | grep -qiE "$pattern"; then
            signal_type="explicit"
            matched_pattern="$pattern"
            break
        fi
    done <<< "$EXPLICIT_PATTERNS"

    # Check domain signals if no explicit match
    if [[ -z "$signal_type" ]]; then
        while IFS= read -r pattern; do
            if echo "$message" | grep -qiE "$pattern"; then
                signal_type="domain"
                matched_pattern="$pattern"
                break
            fi
        done <<< "$DOMAIN_PATTERNS"
    fi

    # Check correction signals if no match yet
    if [[ -z "$signal_type" ]]; then
        while IFS= read -r pattern; do
            if echo "$message" | grep -qiE "$pattern"; then
                signal_type="correction"
                matched_pattern="$pattern"
                break
            fi
        done <<< "$CORRECTION_PATTERNS"
    fi

    if [[ -n "$signal_type" ]]; then
        echo "$signal_type|$matched_pattern"
    fi
}

# Extract context from source file if provided and no context given
extract_file_context() {
    local file="$1"
    local line_num="$2"
    local before="$3"
    local after="$4"

    if [[ -n "$file" && -f "$file" && -n "$line_num" ]]; then
        local start=$((line_num - before))
        [[ $start -lt 1 ]] && start=1
        local end=$((line_num + after))

        # Get context lines
        sed -n "${start},${end}p" "$file" 2>/dev/null | head -20
    fi
}

# Get file header (first N non-empty lines) for topic detection
get_file_header() {
    local file="$1"
    local max_lines="${2:-10}"

    if [[ -n "$file" && -f "$file" ]]; then
        head -n 30 "$file" 2>/dev/null | grep -v '^$' | head -n "$max_lines"
    fi
}

# Detect knowledge signal
DETECTION=$(detect_signal "$USER_MESSAGE")

if [[ -n "$DETECTION" ]]; then
    SIGNAL_TYPE=$(echo "$DETECTION" | cut -d'|' -f1)
    MATCHED_PATTERN=$(echo "$DETECTION" | cut -d'|' -f2)

    # Get session ID from environment or generate one
    SESSION_ID="${CLAUDE_SESSION_ID:-$(date +%Y%m%d_%H%M%S)_$$}"

    # Build context if not provided but source file available
    if [[ -z "$CONTEXT_BEFORE" && -n "$SOURCE_FILE" && -n "$LINE_NUMBER" ]]; then
        CONTEXT_BEFORE=$(extract_file_context "$SOURCE_FILE" "$LINE_NUMBER" "$CONTEXT_LINES_BEFORE" 0)
        CONTEXT_AFTER=$(extract_file_context "$SOURCE_FILE" "$LINE_NUMBER" 0 "$CONTEXT_LINES_AFTER")
    fi

    # Get file header for topic inference
    FILE_HEADER=""
    if [[ -n "$SOURCE_FILE" && -f "$SOURCE_FILE" ]]; then
        FILE_HEADER=$(get_file_header "$SOURCE_FILE" 10)
    fi

    # Create signal entry with context (compact JSON for jsonlines format)
    SIGNAL_ENTRY=$(jq -c -n \
        --arg timestamp "$(date -Iseconds)" \
        --arg signal_type "$SIGNAL_TYPE" \
        --arg pattern "$MATCHED_PATTERN" \
        --arg content "$USER_MESSAGE" \
        --arg session "$SESSION_ID" \
        --arg project "$PROJECT" \
        --arg source_file "$SOURCE_FILE" \
        --arg line_number "$LINE_NUMBER" \
        --arg file_topic "$FILE_TOPIC" \
        --arg context_before "$CONTEXT_BEFORE" \
        --arg context_after "$CONTEXT_AFTER" \
        --arg file_header "$FILE_HEADER" \
        '{
            timestamp: $timestamp,
            signal_type: $signal_type,
            matched_pattern: $pattern,
            content: $content,
            session: $session,
            project: $project,
            source_file: (if $source_file == "" then null else $source_file end),
            line_number: (if $line_number == "" then null else ($line_number | tonumber) end),
            file_topic: (if $file_topic == "" then null else $file_topic end),
            context: {
                before: (if $context_before == "" then null else $context_before end),
                after: (if $context_after == "" then null else $context_after end),
                file_header: (if $file_header == "" then null else $file_header end)
            },
            processed: false
        }')

    # Append to signals file
    echo "$SIGNAL_ENTRY" >> "$SIGNALS_FILE"

    # Output for hook system (optional status)
    echo '{"status": "signal_detected", "type": "'"$SIGNAL_TYPE"'"}' >&2
fi

# Always exit success to not block the main flow
exit 0
