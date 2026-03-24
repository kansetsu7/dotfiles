#!/usr/bin/env bash

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir')
branch=$(git -C "$cwd" branch --show-current 2>/dev/null || echo "")
dir=$(basename "$cwd")
ctx=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
rl5=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
agent=$(echo "$input" | jq -r '.agent.name // empty')

printf "\033[34m \uf07c %s\033[0m" "$dir"
[ -n "$branch" ] && printf "\033[33m \ue725 %s\033[0m" "$branch"
[ -n "$ctx" ] && printf " \033[36m[ctx:%s%%]\033[0m" "$ctx"
[ -n "$rl5" ] && printf " \033[35m[5h:%s%%]\033[0m" "$rl5"
[ -n "$agent" ] && printf " \033[33m[agent:%s]\033[0m" "$agent"

true
