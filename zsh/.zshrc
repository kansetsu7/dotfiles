########################
# Zim
########################

# Remove older command from the history if a duplicate is to be added.
setopt HIST_IGNORE_ALL_DUPS

# --------------------
# Module configuration
# --------------------

# Set a custom prefix for the generated aliases. The default prefix is 'G'.
zstyle ':zim:git' aliases-prefix 'g'

# Customize the style that the suggestions are shown with.
# See https://github.com/zsh-users/zsh-autosuggestions/blob/master/README.md#suggestion-highlight-style
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=242'  # 240?

# Set what highlighters will be used.
# See https://github.com/zsh-users/zsh-syntax-highlighting/blob/master/docs/highlighters.md
ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets)

# ------------------
# Initialize modules
# ------------------
# reference: https://zimfw.sh/docs/install/
ZIM_HOME=${ZDOTDIR:-${HOME}}/.zim
if [[ ! -e ${ZIM_HOME}/zimfw.zsh ]]; then
  # Download zimfw script if missing.
  if (( ${+commands[curl]} )); then
    curl -fsSL --create-dirs -o ${ZIM_HOME}/zimfw.zsh https://github.com/zimfw/zimfw/releases/latest/download/zimfw.zsh
  else
    mkdir -p ${ZIM_HOME} && wget -nv -O ${ZIM_HOME}/zimfw.zsh https://github.com/zimfw/zimfw/releases/latest/download/zimfw.zsh
  fi
fi

if [[ ! ${ZIM_HOME}/init.zsh -nt ${ZDOTDIR:-${HOME}}/.zimrc ]]; then
  # Install missing modules, and update ${ZIM_HOME}/init.zsh if missing or outdated.
  source ${ZIM_HOME}/zimfw.zsh init -q
fi
source ${ZIM_HOME}/init.zsh

# }}} End configuration added by Zim install

########################
# Detect OS
########################
if [[ "$(uname)" == "Darwin" ]]; then
  export OS_TYPE="mac"
elif [[ -f /.dockerenv ]]; then
  export OS_TYPE="docker"
else
  export OS_TYPE="unknown"
fi

# Source OS-specific config
if [[ -f "$HOME/.zshrc_configs/$OS_TYPE/.zshrc" ]]; then
  source "$HOME/.zshrc_configs/$OS_TYPE/.zshrc"  # must define before .zshrc_helper because it will use $PROJECT_PATH
fi

########################
# General
########################

source ~/.zshrc_helper
if [[ -f "$HOME/.zshrc_configs/$OS_TYPE/.zshrc_helper" ]]; then
  source "$HOME/.zshrc_configs/$OS_TYPE/.zshrc_helper"
fi

# [ -f ~/.ssh/abagile-dev.pem ] && ssh-add ~/.ssh/abagile-dev.pem 2&> /dev/null
[ -f ~/.ssh/id_pair ] && ssh-add ~/.ssh/id_pair 2&> /dev/null

# this setting is also affect language in Vim
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export LC_CTYPE=en_US.UTF-8

export EDITOR='nvim'

# pair {{{
# pairg() { ssh -t $1 ssh -o 'StrictHostKeyChecking=no' -o 'UserKnownHostsFile=/dev/null' -p $2 -t ${3:-vagrant}@localhost 'tmux attach' } # pair in mac env
pairh() { ssh -S none -o 'ExitOnForwardFailure=yes' -R $2\:localhost:22 -t $1 'watch -en 10 who' }
pairg() { ssh -t $1 ssh -o 'StrictHostKeyChecking=no' -o 'UserKnownHostsFile=/dev/null' -p $2 -t ${3:-vagrant}@localhost ${4:-'zsh -il -c docker-attach'} } # pair in docker env
# }}}

# Use nvim
alias e='nvim'
alias vdiff='nvim -d'
alias v.='vi .'
alias vi='nvim'

alias cat='bat'

if type nvim > /dev/null 2>&1; then
  alias vim='nvim'
fi

alias sshc='e ~/.ssh/config'
# alias sshc_p='e ~/.ssh/config.d/prod'
# alias setup_tags='ctags -R'

alias grep='grep --color=auto'
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'
alias c='clear'
alias aq='ag -F'
alias px='ps aux'
alias ep='exit'
alias ag=rg
alias rh='fc -R'

export RIPGREP_CONFIG_PATH=~/.ripgreprc
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"

# Git
alias gs='git status'
alias gcom='git checkout master'
alias gRs='git remote show origin'
alias gRp='git remote show origin | grep patch'
alias gRf='git remote show origin | grep feature'
alias gbda='git branch --merged | egrep -v "(^\*|master|nerv_ck|nerv_sg)" | xargs git branch -d'
alias gbdda='git branch | egrep -v "(^\*|master|nerv_ck|nerv_sg)" | xargs git branch -D'
alias glg='git log --stat --max-count=10 --pretty=format:"${_git_log_medium_format}"'
alias gdd='gwd origin/master...'
# alias goc='gco'
alias gddd='gwd origin/master...'
alias gdde='e `gddd --name-only --relative`'
alias gddm='tig origin/master..'
alias gdda='gdd clojure/projects/adam'
alias gdds='gdd clojure/projects/asuka'
alias gddc='gdd clojure/components'
alias gle='e `gcs --pretty=format: --name-only`'
alias gddn='gddd --name-only --relative | cat'
alias gwe='e `git diff --name-only --relative`'
alias gie='e `git diff --cached --name-only --relative`'
alias gbs='git branch | grep -v andre'
# alias gbt='git checkout nerv_ck'
alias gff='git checkout -b $(git branch --show-current)-fork'
alias glcs='git rev-parse --short=12 HEAD'
alias gsh='git show'
alias gcm='git checkout master'
alias grm='git rebase master'
alias ggpull='git pull origin $(git_branch_current)'
alias gpc='git push --set-upstream origin "$(git_branch_current 2> /dev/null)"'
alias gpcc='lint && cop master... && gpc'
alias gfo='git fetch origin'
alias gbd='git branch -D'
alias grh='git reset --hard'
alias gfco="gfo $1 && gco $1"
alias grb="rebase_func $1"
alias grbi="git rebase -i $1"
alias gdf="git diff $1"
alias gcaa='git commit --amend'
alias gbf="git_branch_current | sed -E 's/\-fork$//' | xargs git checkout"

alias sp='switch_to_tmp_branch'
alias gcmbdc='gcm_and_gbd_current_branch'
alias vgc='git diff --name-only --diff-filter=U | xargs nvim'  # git conflicts

# TODO: not sure the effect of below 3 configs, maybe I don't need it?
export _git_log_fuller_format='%C(bold yellow)commit %H%C(auto)%d%n%C(bold)Author: %C(blue)%an <%ae> %C(reset)%C(cyan)%ai (%ar)%n%C(bold)Commit: %C(blue)%cn <%ce> %C(reset)%C(cyan)%ci (%cr)%C(reset)%n%+B'
export _git_log_oneline_format='%C(bold yellow)%h%C(reset) %s%C(auto)%d%C(reset)'
export _git_log_oneline_medium_format='%C(bold yellow)%h%C(reset) %<(50,trunc)%s %C(bold blue)<%an> %C(reset)%C(cyan)(%ar)%C(auto)%ad%C(reset)'

alias lg='lazygit'
alias lzd='lazydocker'

# JavaScript
alias nodejs=node

# ripgrep
alias rgdef="rg_method_def $1"

# nginx
alias nginx_test_and_reload='nginx -t && brew services restart nginx && sudo chown -R andre /opt/homebrew/var/run/nginx/client_body_temp/'
alias vnginx='vi /opt/homebrew/etc/nginx/servers/'

# sshuttle
alias staging_ssh='sshuttle --dns -NHr dev.abagile.com metis-hk.abagile.com metis-ck.abagile.com metis-sg.abagile.com avenueil.abagile.com metis-demo.abagile.com'

########################
# Project Related
########################
export DISABLE_SPRING=1
alias krpu='rpu kill'
alias pru='rpu'
alias spru='skip_mig_warn=1 rpu'

alias rss='RAILS_RELATIVE_URL_ROOT=/`basename $PWD` rails server'

alias aoc="j $PROJECT_PATH/advent-of-code"

# Nerv Projects
alias ck="j $PROJECT_PATH/${NERV_PREFIX}ck"
alias hk="j $PROJECT_PATH/${NERV_PREFIX}hk"
alias sg="j $PROJECT_PATH/${NERV_PREFIX}sg"
alias av="j $PROJECT_PATH/${NERV_PREFIX}ave_ck"
alias aba="j $PROJECT_PATH/amoeba"
alias angel="j $PROJECT_PATH/angel"
alias adam="j clojure/projects/adam"
alias asuka="j clojure/projects/asuka"
alias asu=asuka
alias lcl='j clojure/components/lcl'
alias magi='j clojure/components/magi'
alias pb="j ${MOUNTED_PROJ_PATH:-$PROJECT_PATH}/playbooks"
alias pb2="j ${MOUNTED_PROJ_PATH:-$PROJECT_PATH}/playbooks2"
alias vm="j ${MOUNTED_PROJ_PATH:-$PROJECT_PATH}/vm"

# Gems
alias be='bundle exec'
alias rse='RAILS_RELATIVE_URL_ROOT=/`basename $PWD` be sidekiq'
alias rsk='RAILS_RELATIVE_URL_ROOT=/`basename $PWD` be rake sneakers:run'
alias stopme='be spring stop'
alias copm='cop master...'
alias rake='be rake'

# be careful with the folder position
# alias db_time='ll /tmp/(^amoeba|nerv)_*.custom'
# if [[ -d ~/proj/vm ]]; then
#   alias e_db='vim ~/proj/vm/user/db_mapping.yml'
#
#   alias db_dump='~/proj/vm/scripts/db_dump.rb && ch_pw'
#   alias adb_dump='PGPORT=15432 ~/proj/vm/scripts/db_dump.rb && ch_pw'
#   # alias dump_db='~/proj/vm/scripts/dump_db.zsh'
#   alias dumpdb=dump_db
#   alias ch_pw='be rails runner ~/proj/vm/scripts/nerv/change_passwords.rb'
#   alias e_pw='vim ~/proj/vm/scripts/nerv/change_passwords.rb'
# else
#   echo "[Reminder] You need to clone vm project from Gitlab to get scripts for alias."
# fi
#
# if [[ -d ~/proj/wscripts ]]; then
#   alias e_db='vim ~/proj/wscripts/db/db_mapping.yml'
#   alias ch_pw='be rails runner ~/proj/wscripts/db/ch_pw.rb'
#   alias e_pw='vim ~/proj/wscripts/db/ch_pw.rb'
# fi

# Rails
alias rc='be rails c'
alias rct='be rails console -e test'
alias rcsb='be rails console --sandbox'
alias rch="tail -f ~/.pry_history | grep -v 'exit'"

alias skip_env="SKIP_PATCHING_MIGRATION='skip_any_patching_related_migrations'"
alias rdm='rails db:migrate'
alias rdms='rails db:migrate:status'
alias roll='rails db:rollback'
alias rock!='rails db:migrate:redo STEP=1'
alias test_db_seed='rails db:seed RAILS_ENV=test'
alias mg='skip_env mig'
alias rgm='rails generate migration'

alias rdrst='rake db:reset RAILS_ENV=test'
alias rdr1="rake db:migrate:redo STEP=1"
rdrd() { rake db:migrate:redo STEP="$1" }
rdrv() { rake db:migrate:redo VERSION="$1" }

alias unlog='gunzip `rg -g production.log -w`'
alias olog='e log/development.log'
alias otlog='e log/test.log'
alias clog='cat /dev/null >! log/lograge_development.log && cat /dev/null >! log/development.log'
alias ctlog='cat /dev/null >! log/lograge_test.log && cat /dev/null >! log/test.log'

# Test
alias rt='rails test'
alias testba='rails test test/controllers test/concepts test/forms test/models'

# Amoeba
alias ku='[[ -f tmp/pids/unicorn.pid ]] && kill `cat tmp/pids/unicorn.pid`'

# Clojure
alias ccop='clj-kondo --lint src --config .clj-kondo/config.edn --cache false'
alias ccup='brew reinstall clj-kondo'

# Adam
alias cjn='cd_adam && clj -M:dev:nrepl'
alias ct='cd_adam && clj -M:test:runner --focus $1'
alias ctrf='cd_adam && clj -M:test:runner --watch --focus $1'

# Asuka
alias rw='npm run watch'
alias rwh='NERV_BASE=/nerv_hk npm run watch'
alias rwc='NERV_BASE=/nerv_ck npm run watch'
alias rws='NERV_BASE=/nerv_sg npm run watch'

# Tmuxinator
alias t='tmuxinator'
alias work='t s work'
alias deploy='t s deploy'

# DevOps
alias dk='docker'
alias dco='docker compose'
alias dcn='docker container'

# DB
alias ndb='~/tmp/dumpdb/nerv_hk'
alias upload_ndb="scp ~/tmp/dumpdb/nerv_hk/$1 dev.abagile.com:~/tmp/snapshot_share/$2"
alias download_ndb="scp dev.abagile.com:~/tmp/snapshot_share/$1 ~/tmp/dumpdb/nerv_hk/$2"

########################
# Jump Into Config File
########################
alias df="cd $DOTFILE_PATH"
alias viz="cd $DOTFILE_PATH && vi zsh/.zshrc"
alias vizz="cd $DOTFILE_PATH && vi zsh/.zshrc_configs/$OS_TYPE/.zshrc"
alias vic="cd $DOTFILE_PATH && vi claude/.claude/CLAUDE.md"
alias szsh="exec $DOTFILE_PATH/zsh/.zshrc"
alias viv="cd $DOTFILE_PATH && vi nvim/.config/nvim/init.lua"
alias vie='vi .env'


########################
# eza
########################
alias ls='eza'
alias ll='eza -l -a'
alias tree='eza --tree'

# Git pager setting
export LESS=R

# Fix GPG
export GPG_TTY=$(tty)

# use emacs mode in command line
# bindkey -e

# use vim mode in command line
bindkey -v

# emacs style
bindkey '^a' beginning-of-line
bindkey '^e' end-of-line

bindkey '^f' vi-forward-word
bindkey '^b' vi-backward-word

export FZF_TMUX=1
# https://github.com/sharkdp/fd#integration-with-other-programs
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git --color=always'
export FZF_DEFAULT_OPTS="--ansi"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

# module widget remap
export FZF_COMPLETION_TRIGGER=';'
bindkey '^r' fzf-history-widget
bindkey '^t' fzf-completion
bindkey '^F' autosuggest-accept
bindkey '^p' history-substring-search-up
bindkey '^n' history-substring-search-down

eval "$(zoxide init zsh --cmd j)"

# use localhost / nerv for postgres service running in docker
export PGHOST=localhost
export PGUSER=psql

if [ -f "$HOME/.config/credentials/openai.env.gpg" ]; then
  gpg -dq "$HOME/.config/credentials/openai.env.gpg" 2>/dev/null | source /dev/stdin
fi

case `uname` in
  Darwin)
    export HOMEBREW_NO_AUTO_UPDATE=1 # https://docs.brew.sh/Manpage

    # only works in ZSH
    path=(
      /opt/homebrew/opt/git/share/git-core/contrib/diff-highlight
      /opt/homebrew/opt/libpq/bin
      $path
    )

    # enable ruby 2.7 deprecation warning
    # export RUBYOPT='-W:deprecated'
    export RUBYOPT=''

    # export CFLAGS="-Wno-error=implicit-function-declaration"
    # export optflags="-Wno-error=implicit-function-declaration"

    # setting for Ruby 2.5.9 installation
    # export RUBY_CONFIGURE_OPTS="--with-openssl-dir=$(brew --prefix openssl@1.1)"

    # setting for Ruby 2.1.5 / 2.2.3 installation
    # export RUBY_CONFIGURE_OPTS="--with-openssl-dir=$(brew --prefix openssl@1.0)"

    listening() {
      if [ $# -eq 0 ]; then
        lsof -iTCP -sTCP:LISTEN -n -P
      elif [ $# -eq 1 ]; then
        lsof -iTCP -sTCP:LISTEN -n -P | grep -i --color $1
      else
        echo "Usage: listening [pattern]"
      fi
    }
  ;;
  Linux)
    alias grep='grep --color=auto'
  ;;
esac

function _cop_ruby() {
  local exts=('rb,thor,builder,jbuilder,pryrc')
  local excludes=':(top,exclude)db/schema.rb'
  local extra_options='--display-cop-names'

  if [[ $# -gt 0 ]]; then
    local files=$(eval "noglob git diff $@ --diff-filter=d --name-only -- *.{$exts} $excludes")
  else
    local files=$(eval "noglob git status --porcelain -- *.{$exts} $excludes | sed -e '/^\s\?[DRC] /d' -e 's/^.\{3\}//g'")
  fi

  if [[ -n "$files" ]]; then
    echo $files | xargs bundle exec rubocop `echo $extra_options` --format pacman
  else
    echo 'Nothing to check (rubocop).'
  fi
}

if type brew &>/dev/null
then
  FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"

  # autoload -Uz compinit
  # compinit
fi

# fix issue on puma start in deamon mode
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
