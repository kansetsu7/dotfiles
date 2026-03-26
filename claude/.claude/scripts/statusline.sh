#!/usr/bin/env bash

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir')
branch=$(git -C "$cwd" branch --show-current 2>/dev/null || echo "")
dir=$(basename "$cwd")
ctx=$(echo "$input" | jq -r '.context_window.remaining_percentage // empty')
ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // empty')
rl5=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
agent=$(echo "$input" | jq -r '.agent.name // empty')

printf "\033[34m \uf07c %s\033[0m" "$dir"
[ -n "$branch" ] && printf "\033[33m \ue725 %s\033[0m" "$branch"
# Context: red ≤10%, yellow ≤25%, green >25%
if [ -n "$ctx" ]; then
  if [ "$ctx" -le 10 ]; then
    printf " \033[31mctx:%s%%\033[0m" "$ctx"
  elif [ "$ctx" -le 25 ]; then
    printf " \033[33mctx:%s%%\033[0m" "$ctx"
  else
    printf " \033[32mctx:%s%%\033[0m" "$ctx"
  fi
fi
[ -n "$rl5" ] && printf " \033[35m[5h:%.1f%%]\033[0m" "$rl5"
[ -n "$agent" ] && printf " \033[33m[agent:%s]\033[0m" "$agent"

true
