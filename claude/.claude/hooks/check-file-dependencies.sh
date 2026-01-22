#!/bin/bash
# PostToolUse hook: remind about file dependencies when editing skill files

# Read JSON input from stdin
input=$(cat)

# Extract file_path from tool_input
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

# Check if editing a SKILL.md file
if [[ "$file_path" == *"/skills/"*"/SKILL.md" ]]; then
  echo "📎 Reminder: Check File Dependencies in CLAUDE.md for related files that may need updates."
fi

exit 0
