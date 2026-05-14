# Define path
export PROJECT_PATH=$HOME/proj
export DOTFILE_PATH=$HOME/.dotfiles
export NERV_PREFIX=''

# for e3 startup
export MAC_OS_HOME=$HOME
export MAC_OS_PROJECT=$HOME/proj
export MAC_OS_DOTFILE=$HOME/.dotfiles
export MAC_OS_PRYRC_PATH=$HOME/.config/pry/pryrc

alias ld=lazydocker
alias e3='sync_docker_clipboard; ~/proj/vm/docker-dev/edit/e3/start.sh'
alias ob='~/Library/Mobile\ Documents/iCloud\~md\~obsidian/Documents/Obsidian\ Vault'


cl()  { CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1 claude }
cr()  { CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1 claude --resume }
cf()  { CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1 claude -r "$1" --fork-session }
cy()  { CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1 claude --dangerously-skip-permissions }
