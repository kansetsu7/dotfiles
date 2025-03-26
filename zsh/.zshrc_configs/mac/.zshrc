# Define path
export PROJECT_PATH=$HOME/proj
export DOTFILE_PATH=$HOME/.dotfiles
export NERV_PREFIX=''

export SSH_IDENTITY_AGENT="usekeychain"

# for e3 startup
export MAC_OS_HOME=$HOME
export MAC_OS_PROJECT=$HOME/proj
export MAC_OS_DOTFILE=$HOME/.dotfiles
export MAC_OS_PRYRC_PATH=$HOME/.config/pry/pryrc

alias ld=lazydocker
alias e3='sync_docker_clipboard; ~/proj/vm/docker-dev/edit/e3/start.sh'
