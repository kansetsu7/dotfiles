# Define path
export PROJECT_PATH=/proj
export DOTFILE_PATH=/root/.dotfiles
export MOUNTED_PROJ_PATH=/project
export NERV_PREFIX=nerv_
export PATH="/root/npm-global/bin:$PATH"

alias aba_site="amoeba_site $1"

# AI
alias cl='claude'
alias cr='claude --resume'
cf(){ claude -r $1 --fork-session }

alias ccu='npx ccusage@latest'
alias ccm='npx ccusage@latest monthly'
alias ccb='npx ccusage@latest blocks'

alias gmn='gemini'
alias ecc='cd /project/everything-claude-code'

# SSH agent - reuse single agent across all tmux windows
export SSH_AUTH_SOCK="$HOME/.ssh/agent.sock"
if ! ssh-add -l &>/dev/null; then
  rm -f "$SSH_AUTH_SOCK"
  eval $(ssh-agent -a "$SSH_AUTH_SOCK" -t 86400) >/dev/null
fi
