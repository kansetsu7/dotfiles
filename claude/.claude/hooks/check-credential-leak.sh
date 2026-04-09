#!/bin/bash
# PostToolUse hook: block writes that introduce credential leakage patterns
#
# Checks for:
# 1. Direct references to env tokens (GITLAB_READONLY_TOKEN, OPENAI_API_KEY, etc.)
#    in skill files or MCP configs — credentials should go through MCP servers
# 2. GPG credential sourcing without IS_SANDBOX guard
# 3. Hardcoded tokens/keys in any file

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.command // empty')
tool_name=$(echo "$input" | jq -r '.tool_name // empty')

# For Bash tool, extract file paths from common write patterns
if [[ "$tool_name" == "Bash" ]]; then
  # Skip non-file-writing commands
  [[ "$file_path" =~ (cat|echo|printf).*\> ]] || exit 0
fi

# Only check relevant files
case "$file_path" in
  *.zshrc*|*/skills/*|*/scripts/*|*.mcp.json|*/settings.json) ;;
  *) exit 0 ;;
esac

content=""
if [[ "$tool_name" == "Edit" ]]; then
  content=$(echo "$input" | jq -r '.tool_input.new_string // empty')
elif [[ "$tool_name" == "Write" ]]; then
  content=$(echo "$input" | jq -r '.tool_input.content // empty')
fi

[ -z "$content" ] && exit 0

# --- Check 1: Credential env var references in skill/script files ---
# Matches $VAR or ${VAR} where VAR contains TOKEN, KEY, SECRET, PASSWORD, or CREDENTIAL
if [[ "$file_path" == */skills/* || "$file_path" == */scripts/* ]]; then
  matched=$(echo "$content" | grep -oE '\$\{?[A-Z_]*(TOKEN|KEY|SECRET|PASSWORD|CREDENTIAL)[A-Z_]*\}?' | head -1)
  if [[ -n "$matched" ]]; then
    # Allow MCP launcher scripts — they are the designated credential holders
    if [[ "$file_path" == *"-mcp.sh" ]]; then
      exit 0
    fi
    echo "CREDENTIAL LEAK: Found credential env var reference: $matched"
    echo "Do not reference secret env vars directly in skills/scripts."
    echo "Use an MCP server to isolate credentials from the agent."
    exit 2
  fi
fi

# --- Check 2: GPG sourcing without IS_SANDBOX guard ---
if [[ "$file_path" == *.zshrc* ]]; then
  if echo "$content" | grep -qE 'gpg -dq.*credentials.*\.gpg'; then
    if ! echo "$content" | grep -qE 'IS_SANDBOX'; then
      echo "CREDENTIAL LEAK: GPG credential sourcing must be wrapped in IS_SANDBOX guard."
      echo 'Use: if [[ -z "\$IS_SANDBOX" ]]; then ... fi'
      exit 2
    fi
  fi
fi

# --- Check 3: Hardcoded tokens (generic pattern) ---
if echo "$content" | grep -qE '(glpat-|sk-[a-zA-Z0-9]{20,}|ghp_[a-zA-Z0-9]{36}|xox[bpas]-[a-zA-Z0-9-]+)'; then
  echo "CREDENTIAL LEAK: Detected what looks like a hardcoded token."
  echo "Store credentials in GPG-encrypted files under ~/.config/credentials/"
  exit 2
fi

exit 0
