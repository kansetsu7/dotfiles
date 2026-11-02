# Define path
export PROJECT_PATH=/proj
export DOTFILE_PATH=/root/.dotfiles
export MOUNTED_PROJ_PATH=/project
export NERV_PREFIX=nerv_
export PATH="/root/npm-global/bin:$PATH"

alias aba_site="amoeba_site $1"

# AI
cl()  { _claude_in_container }
cr()  { _claude_in_container --resume "$1" }
cf()  { _claude_in_container -r "$1" --fork-session }
cy()  { _claude_in_container --dangerously-skip-permissions }

alias gmn='gemini'
alias ecc='cd /project/everything-claude-code'

# SSH agent
# Skip in sandbox: ~/.ssh isn't mounted and there are no keys to load.
# Prefer the Mac's agent forwarded by Colima/Docker Desktop (compose sets
# SSH_AUTH_SOCK). Fall back to a per-container agent shared across tmux
# windows when the forwarded socket is missing or stale (e.g. after
# `colima restart` without recreating the container).
# ssh-add -l exit 2 = no agent reachable; 0/1 = agent is fine.
# Fallback socket lives in /tmp because ~/.ssh may be a bind-mount on a
# filesystem (e.g. Docker Desktop grpcfuse) that doesn't support unix sockets.
if [[ -z "$IS_SANDBOX" ]]; then
  if SSH_AUTH_SOCK=/run/host-services/ssh-auth.sock ssh-add -l &>/dev/null; [[ $? -ne 2 ]]; then
    export SSH_AUTH_SOCK=/run/host-services/ssh-auth.sock
  else
    export SSH_AUTH_SOCK="/tmp/ssh-agent.$(id -u).sock"
    _ssh_agent_lock="/tmp/ssh-agent.$(id -u).lock"
    [[ -f "$_ssh_agent_lock" ]] || touch "$_ssh_agent_lock"
    (
      flock -n 9 || exit 0
      ssh-add -l &>/dev/null
      if [ $? -eq 2 ]; then
        rm -f "$SSH_AUTH_SOCK"
        eval $(ssh-agent -a "$SSH_AUTH_SOCK" -t 86400) >/dev/null
      fi
    ) 9<"$_ssh_agent_lock"
    unset _ssh_agent_lock
  fi
fi
