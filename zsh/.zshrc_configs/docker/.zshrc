# Define path
export PROJECT_PATH=/proj
export DOTFILE_PATH=/root/.dotfiles
export MOUNTED_PROJ_PATH=/project
export NERV_PREFIX=nerv_
export PATH="/root/npm-global/bin:$PATH"

alias aba_site="amoeba_site $1"

# AI (cl/cr/cf/cy defined in shared .zshrc, using _claude_in_container from .zshrc_helper)

alias gmn='gemini'
alias ecc='cd /project/everything-claude-code'

# SSH agent - reuse single agent across all tmux windows
# Skip in sandbox: ~/.ssh isn't mounted and there are no keys to load.
if [[ -z "$IS_SANDBOX" ]]; then
  export SSH_AUTH_SOCK="$HOME/.ssh/agent.sock"
  (
    flock -n 9 || exit 0
    ssh-add -l &>/dev/null
    # exit 2 = no agent reachable; 0/1 = agent is fine, keep it
    if [ $? -eq 2 ]; then
      rm -f "$SSH_AUTH_SOCK"
      eval $(ssh-agent -a "$SSH_AUTH_SOCK" -t 86400) >/dev/null
    fi
  ) 9>>"$HOME/.ssh/agent.lock"
fi
