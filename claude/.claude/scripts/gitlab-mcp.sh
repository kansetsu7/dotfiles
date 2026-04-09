#!/bin/sh
# MCP server launcher for GitLab API access.
# Reads token from GPG at launch — the token lives only in this process,
# never in the agent's shell environment.

set -e

TOKEN=$(gpg -dq "$HOME/.config/credentials/gitlab-readonly-token.env.gpg" 2>/dev/null \
  | sed -n 's/^export GITLAB_READONLY_TOKEN=//p')

if [ -z "$TOKEN" ]; then
  echo "Failed to decrypt GitLab token" >&2
  exit 1
fi

export GITLAB_PERSONAL_ACCESS_TOKEN="$TOKEN"
export GITLAB_API_URL="https://gitlab.abagile.com/api/v4"
export GITLAB_READ_ONLY_MODE="true"

exec npx -y @zereight/mcp-gitlab
