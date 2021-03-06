# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# shell environment initialization {{{

case "$(uname -s)" in
  Linux)
    source /etc/os-release
    ;;
  Darwin)
    NAME=Darwin
esac

case "$NAME" in
  Ubuntu)
    for tool (git-extras htop tree neovim); do
      [[ -z $(dpkg -l | grep $tool) ]] && sudo apt-get install -y $tool
    done
    ;;
  # Darwin)
  #   for tool (git-extras htop neovim); do
  #     [[ -z $(brew list | grep $tool) ]] && brew install $tool
  #   done
  #   ;;
esac

if [[ ! -d ~/.dotfiles ]]; then
  git clone git://github.com/kansetsu7/dotfiles.git ~/.dotfiles

  ln -sf ~/.dotfiles/gemrc               ~/.gemrc
  ln -sf ~/.dotfiles/inputrc             ~/.inputrc
  ln -sf ~/.dotfiles/psqlrc              ~/.psqlrc
  ln -sf ~/.dotfiles/tigrc               ~/.tigrc
  ln -sf ~/.dotfiles/tmux.conf           ~/.tmux.conf
  ln -sf ~/.dotfiles/zshrc               ~/.zshrc
  ln -sf ~/.dotfiles/gitconfig           ~/.gitconfig
  ln -sf ~/.dotfiles/.pryrc              ~/.pryrc
  ln -sf ~/.dotfiles/ripgreprc           ~/ripgreprc
  ln -sf ~/.dotfiles/rgignore            ~/.rgignore
  ln -sf ~/.dotfiles/p10k.zsh            ~/.p10k.zsh

  mkdir -p ~/.config/nvim
  ln -sf ~/.dotfiles/init.vim            ~/.config/nvim/init.vim

  sudo update-alternatives --install /usr/bin/vi vi /usr/bin/nvim 60
  sudo update-alternatives --auto vi
  sudo update-alternatives --install /usr/bin/vim vim /usr/bin/nvim 60
  sudo update-alternatives --auto vim
  sudo update-alternatives --install /usr/bin/editor editor /usr/bin/nvim 60
  sudo update-alternatives --auto editor

  mkdir -p ~/.psql_history
fi

# }}}

# zplug {{{
### Added by Zinit's installer
# install zinit, if necessary
if [[ ! -f $HOME/.zinit/bin/zinit.zsh ]]; then
    print -P "%F{33}▓▒░ %F{220}Installing %F{33}DHARMA%F{220} Initiative Plugin Manager (%F{33}zdharma/zinit%F{220})…%f"
    command mkdir -p "$HOME/.zinit" && command chmod g-rwX "$HOME/.zinit"
    command git clone https://github.com/zdharma/zinit "$HOME/.zinit/bin" && \
        print -P "%F{33}▓▒░ %F{34}Installation successful.%f%b" || \
        print -P "%F{160}▓▒░ The clone has failed.%f%b"
fi

source "$HOME/.zinit/bin/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

### End of Zinit's installer chunk

zinit light zsh-users/zsh-autosuggestions
zinit light zsh-users/zsh-history-substring-search
zinit light zdharma/fast-syntax-highlighting
zinit ice depth=1; zinit light romkatv/powerlevel10k

zinit ice as="program" pick="$ZPFX/bin/(fzf|fzf-tmux)" \
  atclone="./install;cp bin/(fzf|fzf-tmux) $ZPFX/bin"
zinit light junegunn/fzf

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

export FZF_TMUX=1

# need to install svn, `sudo apt-get install subversion`
zinit ice svn
zinit snippet PZT::modules/git

zinit snippet PZT::modules/environment
zinit snippet PZT::modules/completion
zinit snippet PZT::modules/history
zinit snippet PZT::modules/rsync
zinit snippet PZT::modules/directory
zinit snippet PZT::modules/ssh
for index ({1..9}) alias "$index"="$index"; unset index  # to revert the shitty alias from directory module
zinit snippet OMZ::plugins/rails/rails.plugin.zsh
zinit snippet OMZ::plugins/vi-mode/vi-mode.plugin.zsh
zinit snippet OMZ::plugins/bundler/bundler.plugin.zsh

# BurntSushi/ripgrep
zinit ice as"command" from"gh-r" mv"ripgrep* -> rg" pick"rg/rg"
zinit light BurntSushi/ripgrep
export RIPGREP_CONFIG_PATH=~/.ripgreprc

zinit cdclear -q

autoload -Uz compinit
compinit
zinit cdreplay -q # <- execute compdefs provided by rest of plugins
# zinit cdlist # look at gathered compdefs

# asdf setting
. $HOME/.asdf/asdf.sh
. $HOME/.asdf/completions/asdf.bash

# # install zplug, if necessary
# if [[ ! -d ~/.zplug ]]; then
#   export ZPLUG_HOME=~/.zplug
#   git clone https://github.com/zplug/zplug $ZPLUG_HOME
# fi

# source ~/.zplug/init.zsh

# zplug "plugins/vi-mode", from:oh-my-zsh
# # zplug "plugins/chruby",  from:oh-my-zsh
# zplug "plugins/asdf",    from:oh-my-zsh
# zplug "plugins/bundler", from:oh-my-zsh
# zplug "plugins/rails",   from:oh-my-zsh

# zplug "b4b4r07/enhancd", use:init.sh
# zplug "junegunn/fzf", as:command, hook-build:"./install --bin", use:"bin/{fzf-tmux,fzf}"

# zplug "zsh-users/zsh-autosuggestions", defer:3

# # zim {{{
# zstyle ':zim:git' aliases-prefix 'g'
# zplug "zimfw/git"

# zplug "zimfw/zimfw", as:plugin, use:"init.zsh", hook-build:"ln -sf $ZPLUG_REPOS/zimfw/zimfw ~/.zim"

# zmodules=(directory environment git git-info history input ssh utility \
#           prompt completion syntax-highlighting history-substring-search)

# zhighlighters=(main brackets pattern cursor root)

# zplug 'dracula/zsh', as:theme
# # zplug denysdovhan/spaceship-prompt, use:spaceship.zsh, from:github, as:theme

# # if [[ "$NAME" = "Ubuntu" ]]; then
# #   zprompt_theme='eriner'
# # else
# #   zprompt_theme='liquidprompt'
# # fi
# # }}}

# if ! zplug check --verbose; then
#   zplug install
# fi

# zplug load #--verbose

# ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=240'

# source ~/.zplug/repos/junegunn/fzf/shell/key-bindings.zsh
# source ~/.zplug/repos/junegunn/fzf/shell/completion.zsh

# export FZF_COMPLETION_TRIGGER=';'
# export FZF_TMUX=1

# }}}

# diff-highlight {{{
if [[ ! -e /usr/local/bin/diff-highlight ]]; then
  sudo curl https://raw.githubusercontent.com/git/git/3dadfc7e173e27db641291d8f049ab487b696704/contrib/diff-highlight/diff-highlight --create-dirs -o /usr/local/bin/diff-highlight
  sudo chmod +x /usr/local/bin/diff-highlight
fi
# }}}

# customization {{{

# set nvim for macOS {{{
case "$NAME" in
  Darwin)
    alias vi='nvim'
esac
# }}}

# directory shortcut {{{
p()  { cd ~/proj/$1;}
h()  { cd ~/$1;}
vm() { cd ~/vagrant/$1;}

compctl -W ~/proj -/ p
compctl -W ~ -/ h
compctl -W ~/vagrant -/ vm
# }}}

# development shortcut {{{
alias be='bundle exec'
alias pa!='[[ -f config/puma.rb ]] && RAILS_RELATIVE_URL_ROOT=/`basename $PWD` bundle exec puma -C $PWD/config/puma.rb'
alias pa='[[ -f config/puma.rb ]] && RAILS_RELATIVE_URL_ROOT=/`basename $PWD` bundle exec puma -C $PWD/config/puma.rb -d'
alias kpa='[[ -f tmp/pids/puma.state ]] && bundle exec pumactl -S tmp/pids/puma.state stop'
alias rs='rails s'

alias apa!='RAILS_RELATIVE_URL_ROOT=/angel bundle exec puma -C config/puma.rb'
alias apa='RAILS_RELATIVE_URL_ROOT=/angel bundle exec puma -C config/puma.rb -d'
alias kapa='bundle exec pumactl -P /home/vagrant/p/angel/tmp/pids/puma.pid stop'

alias mc='bundle exec mailcatcher --http-ip 0.0.0.0'
alias kmc='pkill -fe mailcatcher'
alias sk='[[ -f config/sidekiq.yml ]] && bundle exec sidekiq -C $PWD/config/sidekiq.yml -d'
alias ksk='pkill -fe sidekiq'

alias rcsb='rc --sandbox'
alias rct='rc test'
alias rdrst='rake db:reset RAILS_ENV=test'

alias nginx_test_and_reload='sudo nginx -t && sudo service nginx reload'

alias sprs='spring stop && spring binstub'
alias rdr1="rake db:migrate:redo STEP=1"
rdrd() { rake db:migrate:redo STEP="$1" }
rdrv() { rake db:migrate:redo VERSION="$1" }

# skip patching migrate
alias mg="rake db:migrate SKIP_PATCHING_MIGRATION='skip_any_patching_related_migrations'"

lint() {
  [[ $PWD =~ '(.*perv|.*sg|.*nerv|.*amoeba|.*magi)' ]] && project_path=$match[1]

  if [[ $project_path ]]; then
    "$project_path/clojure/adam/bin/lint" && "$project_path/eva/asuka/bin/lint"
  fi
}
nrw() {
  local folder_path
  local folder_name
  local asuka_path

  [[ $PWD =~ '(.*perv|.*sg|.*nerv|.*magi)' ]] && folder_path=$match[1]
  [[ $folder_path =~ '.*(perv|sg|nerv|magi)$' ]] && folder_name=$match[1]

  asuka_path="$folder_path/eva/asuka"

  echo "run npm for $asuka_path"
  cd $asuka_path && NERV_BASE=/${=folder_name} npm run watch
}

amoeba_test_reset() {
  RAILS_ENV=test be rake db:drop
  RAILS_ENV=test be rake db:create
  RAILS_ENV=test be rake db:schema:load
  RAILS_ENV=test be rake db:seed
}

# 重啟 puma/unicorn（非 daemon 模式，用於 pry debug）
rpy() {
  if bundle show pry-remote > /dev/null 2>&1; then
    bundle exec pry-remote
  else
    rpu pry
  fi
}

# 這是 rpu 會用到的 helper function
rserver_restart() {
  local app=${$(pwd):t}
  [[ ! $app =~ '^(amoeba|cam|perv|sg|angel)' ]] && app='nerv' # support app not named 'nerv' (e.g., nerv2)

  case "$1" in
    puma)
      shift
      RAILS_RELATIVE_URL_ROOT=/$app bundle exec puma -C config/puma.rb config.ru $*
      ;;
    unicorn)
      shift
      RAILS_RELATIVE_URL_ROOT=/$app bundle exec unicorn -c config/unicorn.rb $* && echo 'unicorn running'
      ;;
    *)
      echo 'invalid argument'
  esac
}

# 重啟 puma/unicorn
#
# - rpu       → 啟動或重啟（如果已有 pid）
# - rpu kill  → 殺掉 process，不重啟
# - rpu xxx   → xxx 參數會被丟給 pumactl（不支援 unicorn）
rpu() {
  emulate -L zsh
  if [[ -d tmp ]]; then
    local action=$1
    local pid
    local animal

    if [[ -f config/puma.rb ]]; then
      animal='puma'
    elif [[ -f config/unicorn.rb ]]; then
      animal='unicorn'
    else
      echo "No puma/unicorn directory, aborted."
      return 1
    fi

    if [[ -r tmp/pids/$animal.pid && -n $(ps h -p `cat tmp/pids/$animal.pid` | tr -d ' ') ]]; then
      pid=`cat tmp/pids/$animal.pid`
    fi

    if [[ -n $action ]]; then
      case "$action" in
        pry)
          if [[ -n $pid ]]; then
            kill -9 $pid && echo "Process killed ($pid)."
          fi
          rserver_restart $animal
          ;;
        kill)
          if [[ -n $pid ]]; then
            kill -9 $pid && echo "Process killed ($pid)."
          else
            echo "No process found."
          fi
          ;;
        *)
          if [[ -n $pid ]]; then
            # TODO: control unicorn
            pumactl -p $pid $action
          else
            echo 'ERROR: "No running PID (tmp/pids/puma.pid).'
          fi
      esac
    else
      if [[ -n $pid ]]; then
        # Alternatives:
        # pumactl -p $pid restart
        # kill -USR2 $pid && echo "Process killed ($pid)."

        # kill -9 (SIGKILL) for force kill
        kill -9 $pid && echo "Process killed ($pid)."
        rserver_restart $animal $([[ "$animal" == 'puma' ]] && echo '-d' || echo '-D')
      else
        rserver_restart $animal $([[ "$animal" == 'puma' ]] && echo '-d' || echo '-D')
      fi
    fi
  else
    echo 'ERROR: "tmp" directory not found.'
  fi
}

# 啟動／停止 sidekiq
rsidekiq() {
 emulate -L zsh
   if [[ -d tmp ]]; then
     if [[ -r tmp/pids/sidekiq.pid && -n $(ps h -p `cat tmp/pids/sidekiq.pid` | tr -d ' ') ]]; then
       case "$1" in
         restart)
           bundle exec sidekiqctl restart tmp/pids/sidekiq.pid
           ;;
         *)
           bundle exec sidekiqctl stop tmp/pids/sidekiq.pid
       esac
    else
      echo "Start sidekiq process..."
      nohup bundle exec sidekiq  > ~/.nohup/sidekiq.out 2>&1&
      disown %nohup
    fi
  else
    echo 'ERROR: "tmp" directory not found.'
  fi
}


# 啟動／停止 mailcatcher
rmailcatcher() {
  rm /home/vagrant/.nohup/mailcatcher.out
  local pid=$(ps --no-headers -C mailcatcher -o pid,args | command grep '/bin/mailcatcher --http-ip' | sed 's/^ //' | cut -d' ' -f 1)
  if [[ -n $pid ]]; then
    kill $pid && echo "MailCatcher process $pid killed."
  else
    echo "Start MailCatcher process..."
    nohup mailcatcher --http-ip 0.0.0.0 > ~/.nohup/mailcatcher.out 2>&1&
    disown %nohup
  fi
}

pairg() { ssh -t $1 ssh -o 'StrictHostKeyChecking=no' -o 'UserKnownHostsFile=/dev/null' -p $2 -t ${3:-vagrant}@localhost 'tmux attach' }
pairh() { ssh -S none -o 'ExitOnForwardFailure=yes' -R $2\:localhost:22222 -t $1 'watch -en 10 who' }

cop() {
  local exts=('rb,thor,jbuilder')
  local excludes=':(top,exclude)db/schema.rb'
  local app=${$(pwd):t}
  if [[ $app != "magi" ]]; then
    local extra_options='--display-cop-names --rails'
  else
    local extra_options='--display-cop-names --require rubocop-rails'
  fi

  if [[ $# -gt 0 ]]; then
    local files=$(eval "git diff $@ --diff-filter=d --name-only -- \*.{$exts} '$excludes'")
  else
    local files=$(eval "git status --porcelain -- \*.{$exts} '$excludes' | sed -e '/^\s\?[DRC] /d' -e 's/^.\{3\}//g'")
  fi
  # local files=$(eval "git diff --name-only -- \*.{$exts} '$excludes'")

  if [[ -n "$files" ]]; then
    echo $files | xargs bundle exec rubocop `echo $extra_options`
  else
    echo "Nothing to check. Write some *.{$exts} to check.\nYou have 20 seconds to comply."
  fi
}
# }}}

# tmux shortcut {{{
tx() {
  if ! tmux has-session -t work 2> /dev/null; then
    tmux new -s work -d;
    # tmux splitw -h -p 40 -t work;
    # tmux select-p -t 1;
  fi
  tmux attach -t work;
}
txtest() {
  if ! tmux has-session -t test 2> /dev/null; then
    tmux new -s test -d;
  fi
  tmux attach -t test;
}
txpair() {
  SOCKET=/home/share/tmux-pair/default
  if ! tmux -S $SOCKET has-session -t pair 2> /dev/null; then
    tmux -S $SOCKET new -s pair -d;
    # tmux -S $SOCKET send-keys -t pair:1.1 "chmod 1777 " $SOCKET C-m "clear" C-m;
  fi
  tmux -S $SOCKET attach -t pair;
}
fixssh() {
  if [ "$TMUX" ]; then
    export $(tmux showenv SSH_AUTH_SOCK)
  fi
}
# }}}

# setup color
alias ls='ls --color=auto'
alias grep='grep --color=auto'

# aliases {{{
alias px='ps aux'
alias vt='vi -c :CtrlP'
alias vl='vi -c :CtrlPMRU'
alias v.='vi .'

alias sa='ssh-add'
alias salock='ssh-add -x'
alias saunlock='ssh-add -X'

# ripgrep
alias rgdef="rg_method_def $1"

alias ag='rg -i'
alias agdef="rg_method_def $1"
alias agr='rg_pcre2 $1 $2'

# alias -g G='| ag'
# alias -g P='| $PAGER'
# alias -g WC='| wc -l'
# alias -g RE='RESCUE=1'

alias -g HED='HANAMI_ENV=development'
alias -g HEP='HANAMI_ENV=production'
alias -g HET='HANAMI_ENV=test'

alias va='cd ~/vm;vagrant'
alias vsh='va ssh'
alias vsf='va ssh -- \
  -L 8088:localhost:88 \
  -L 8080:localhost:80 \
  -L 8065:localhost:65 \
  -L 1080:localhost:1080 \
  -L 22222:localhost:22 \
  -L 3000:localhost:3000 \
  -L 3310:localhost:3310 \
  -L 6666:localhost:6666 \
  -L 9527:localhost:9527 \
  -L 15672:localhost:15672 \
  -L 9630:localhost:9630'
alias vup='va up'
alias vsup='va suspend'
alias vhalt='va halt'
alias vus="vup;vsf"

alias gws=gwS
alias ws=gws
alias gsh='git show'
alias gba='gb -a'
alias gcm='git checkout master'
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

alias ha=hanami
alias hac='ha console'
alias had='ha destroy'
alias hag='ha generate'
alias ham='ha generate migration'
alias has='ha server'
alias har='ha routes'

alias rgm='rails g migration'

alias lsl='ls -al'

alias dumpdb='/vagrant/scripts/dump_db.zsh'
alias magidb='~/.dotfiles/magi_db.zsh'
alias upload_ndb="scp ~/tmp/dumpdb/nerv_development/$1 dev.abagile.com:~/tmp/snapshot_share/$2"
alias upload_pdb="scp ~/tmp/dumpdb/nerv_ck_development/$1 dev.abagile.com:~/tmp/snapshot_share/$2"
alias download_ndb="scp dev.abagile.com:~/tmp/snapshot_share/$1 ~/tmp/dumpdb/nerv_development/$2"
alias download_pdb="scp dev.abagile.com:~/tmp/snapshot_share/$1 ~/tmp/dumpdb/nerv_ck_development/$2"
alias download_log="scp -r dev.abagile.com:~/nerv_production_log ~/tmp/nerv_production_log;
  scp -r dev.abagile.com:~/nerv_production_log_ck ~/tmp/nerv_production_log_ck
  scp -r dev.abagile.com:/var/log/app-log/ipc/amoeba/log ~/tmp/amoeba_log"

alias dotfiles='cd ~/.dotfiles'
alias dotfile='dotfiles'
alias df='dotfiles'
alias nerv='cd ~/nerv'
alias perv='cd ~/perv'
alias sg='cd ~/sg'
alias angel='cd ~/angel'
alias adam='cd clojure/adam'
alias asuka='cd eva/asuka'
alias asu=asuka
alias kaworu='cd eva/kaworu'
alias aba='cd ~/amoeba'
alias cam='cd ~/cam'
alias ndb='cd ~/tmp/dumpdb/nerv_development'
alias pdb='cd ~/tmp/dumpdb/nerv_ck_development'
alias mdb='cd ~/tmp/dumpdb/magi_ck_development'
alias magi='cd ~/magi'
alias melchior='cd ~/magi/clojure/melchior'
alias melc=melchior

alias viz='vi ~/.dotfiles/zshrc'
alias viv='vi ~/.dotfiles/init.vim'
alias szsh="reload_zshrc"

alias krpu='rpu kill'

# clojure
alias cjn='clj -M:dev:nrepl'
alias cjt='clj -M:test:nrepl'
alias ctr='clj -M:test:runner --watch'
alias ctrf='clj -M:test:runner --watch --focus $1'

alias cjp='clj -M:dev:prepl'
alias clj-st='clj -M:dev -m abagile.adam.core'
# }}}

# environment variables {{{
export EDITOR=vi
export VISUAL=vi
#}}}

# key bindings {{{
bindkey -M vicmd '^a' beginning-of-line
bindkey -M vicmd '^e' end-of-line

# emacs style
bindkey '^a' beginning-of-line
bindkey '^e' end-of-line

bindkey '^f' vi-forward-word
bindkey '^b' vi-backward-word

bindkey '^o' autosuggest-accept

bindkey '^p' history-substring-search-up
bindkey '^n' history-substring-search-down
# }}}

# git functions {{{
rebase_func() {
  git rebase -i HEAD~$1
}
git_branch_current() {
  git rev-parse --abbrev-ref HEAD
}
# }}}

# rg functions {{{
rg_method_def() {
  rg "def $1"
}

rg_pcre2() {
  # rg -P => support look-around
  if [ -n "$2" ]; then
    rg -P $1 $2
  else
    rg -P $1
  fi
}
#}}}

clean_tmp() {
  ls -d ./tmp/* | grep -P "tmp/statement_.*.pdf$" | xargs -d"\n" rm
  ls -d ./tmp/* | grep -P "tmp/valuation_logo_.*.pdf$" | xargs -d"\n" rm
}

reload_zshrc() {
  case "$(uname -s)" in
    Linux)
      source ~/.zshrc
      ;;
    Darwin)
      exec $SHELL
  esac
}

fix_zhistory() {
  mv /home/vagrant/.zhistory /home/vagrant/.zhistory_bad
  strings /home/vagrant/.zhistory_bad > /home/vagrant/.zhistory
  fc -R /home/vagrant/.zhistory
}

if [ -f ~/.config/exercism/exercism_completion.zsh ]; then
  source ~/.config/exercism/exercism_completion.zsh
fi

path+=~/bin

# }}}
if [ "$TMUX" = "" ]; then
  WHOAMI=$(whoami)
  if tmux has-session -t $WHOAMI 2>/dev/null; then
    tmux -2 attach-session -t $WHOAMI
  else
    tmux -2 new-session -s $WHOAMI
  fi
fi

# p10k setting backup
#
#   local eva_green='#52d053'
#   local eva_purple='135'
#   typeset -g POWERLEVEL9K_DIR_FOREGROUND=$eva_green
#   typeset -g POWERLEVEL9K_VCS_FOREGROUND=$eva_purple

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
