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

# SSH agent - reuse single agent across all tmux windows
# Skip in sandbox: ~/.ssh isn't mounted and there are no keys to load.
# Socket lives in /tmp because ~/.ssh may be a bind-mount on a filesystem
# (e.g. Docker Desktop grpcfuse) that doesn't support unix domain sockets.
if [[ -z "$IS_SANDBOX" ]]; then
  export SSH_AUTH_SOCK="/tmp/ssh-agent.$(id -u).sock"
  _ssh_agent_lock="/tmp/ssh-agent.$(id -u).lock"
  [[ -f "$_ssh_agent_lock" ]] || touch "$_ssh_agent_lock"
  (
    flock -n 9 || exit 0
    ssh-add -l &>/dev/null
    # exit 2 = no agent reachable; 0/1 = agent is fine, keep it
    if [ $? -eq 2 ]; then
      rm -f "$SSH_AUTH_SOCK"
      eval $(ssh-agent -a "$SSH_AUTH_SOCK" -t 86400) >/dev/null
    fi
  ) 9<"$_ssh_agent_lock"
  unset _ssh_agent_lock
fi
