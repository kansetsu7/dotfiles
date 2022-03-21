zstyle ':zim:git' aliases-prefix 'g'
. ~/.zplugin

# customization {{{

if [[ "`uname -s`" == "Darwin" ]]; then
  # export LANG=C
  # export LC_ALL=en_US.UTF-8
  export LANG=en_US.UTF-8
fi
export RIPGREP_CONFIG_PATH=~/.ripgreprc

# directory shortcut {{{
p()  { cd ~/proj/$1;}
h()  { cd ~/$1;}
vm() { cd ~/vagrant/$1;}
cdpath=(~ ~/proj)

compctl -W ~/proj -/ p
compctl -W ~ -/ h
compctl -W ~/vagrant -/ vm
# }}}

# development shortcut {{{
alias pa!='[[ -f config/puma.rb ]] && RAILS_RELATIVE_URL_ROOT=/`basename $PWD` bundle exec puma -C $PWD/config/puma.rb'
alias pa='[[ -f config/puma.rb ]] && RAILS_RELATIVE_URL_ROOT=/`basename $PWD` bundle exec puma -C $PWD/config/puma.rb -d'
alias kpa='[[ -f tmp/pids/puma.state ]] && bundle exec pumactl -S tmp/pids/puma.state stop'
# alias kpa='[[ -f tmp/pids/puma.pid ]] && kill `cat tmp/pids/puma.pid`'

alias mc='mailcatcher --http-ip 0.0.0.0'
alias kmc='pkill -f mailcatcher'
alias sk='[[ -f config/sidekiq.yml ]] && bundle exec sidekiq -C $PWD/config/sidekiq.yml -d'
alias ksk='pkill sidekiq'

pairg() { ssh -t $1 ssh -o 'StrictHostKeyChecking=no' -o 'UserKnownHostsFile=/dev/null' -p $2 -t ${3:-vagrant}@localhost 'tmux attach' }
pairh() { ssh -S none -o 'ExitOnForwardFailure=yes' -R $2\:localhost:22 -t $1 'watch -en 10 who' }

cop() {
  local exts=('rb,thor,jbuilder')
  local excludes=':(top,exclude)db/schema.rb'
  local extra_options='--display-cop-names --rails'

  if [[ $# -gt 0 ]]; then
    local files=$(eval "git diff $@ --name-only -- \*.{$exts} '$excludes'")
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

# aliases {{{
# alias sed=gsed # sed in macOs is different from ubuntu, so override sed by gsed
alias g='git'

if [[ "`uname -s`" == "Darwin" ]]; then
  alias vi='nvim'
  alias vim='nvim'
  # if [ `whence gls` > /dev/null ]; then
  #   alias ls='gls --group-directories-first --color=auto'
  # fi
fi

for index ({1..9}) alias "$index"="$index"; unset index  # to revert the shitty alias from directory module

alias ls='exa --group-directories-first'
alias l='ls -la'

alias px='ps aux'
alias vt='vi -c :CtrlP'
alias vl='vi -c :CtrlPMRU'
alias v.='vi .'

alias sa='ssh-add'
alias salock='ssh-add -x'
alias saunlock='ssh-add -X'

alias agi='ag -i'
alias agiw='ag -i -w'
alias agr='ag --ruby'
alias agri='ag --ruby -i'

alias rgi='rg -i'
alias rgiw='rg -iw'

alias -g G='| rg'
alias -g P='| $PAGER'
alias -g WC='| wc -l'
alias -g RE='RESCUE=1'

alias rc='bin/rails console'
alias rr='bin/rake routes'
alias rdm='bin/rake db:migrate'
alias rdr='bin/rake db:rollback'
alias rdms='bin/rake db:migrate:status'

alias va=vagrant
# alias vsh='va ssh'
# alias vsf='va ssh -- -L 0.0.0.0:8080:localhost:80 -L 1080:localhost:1080'
alias vsh='ssh gko.abagile.aws.kr'
alias vsf='vsh -L 0.0.0.0:8080:localhost:80 -L 1080:localhost:1080'
alias vup='va up'
alias vsup='va suspend'
alias vhalt='va halt'

alias zshrc='vi ~/.zshrc'
alias vimrc='vi ~/.config/nvim/init.vim'

alias cat=bat

alias apb=ansible-playbook
# }}}

# environment variables {{{
if [ `whence nvim` > /dev/null ]; then
  export EDITOR=nvim
  export VISUAL=nvim
else
  export EDITOR=vi
  export VISUAL=vi
fi
#}}}

# key bindings {{{
bindkey -M vicmd '^a' beginning-of-line
bindkey -M vicmd '^e' end-of-line

bindkey '^[f' vi-forward-word
bindkey '^[b' vi-backward-word

bindkey '^o' autosuggest-accept

bindkey '^p' history-substring-search-up
bindkey '^n' history-substring-search-down
# }}}

# export fpath=(~/.config/exercism/functions $fpath)
# autoload -U compinit && compinit

# export PATH=$PATH:/usr/local/opt/ansible@2.9/bin:/usr/local/opt/erlang@23/bin:/usr/local/sbin:~/bin:/snap/bin
# }}}

if [[ "`uname -s`" == "Darwin" ]]; then
  [ -f $(brew --prefix)/etc/profile.d/autojump.sh ] && . $(brew --prefix)/etc/profile.d/autojump.sh
  [ -f $(brew --prefix asdf)/libexec/asdf.sh ] && . $(brew --prefix asdf)/libexec/asdf.sh
else
  [ -f ~/.asdf/asdf.sh ] && source ~/.asdf/asdf.sh && source "$HOME/.asdf/completions/asdf.bash"
  [ -f /usr/local/etc/profile.d/autojump.sh ] && . /usr/local/etc/profile.d/autojump.sh
fi

[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

[ -f ~/.ssh/id_pair ] && ssh-add ~/.ssh/id_pair 2> /dev/null

export _git_log_fuller_format='%C(bold yellow)commit %H%C(auto)%d%n%C(bold)Author: %C(blue)%an <%ae> %C(reset)%C(cyan)%ai (%ar)%n%C(bold)Commit: %C(blue)%cn <%ce> %C(reset)%C(cyan)%ci (%cr)%C(reset)%n%+B'
export _git_log_oneline_format='%C(bold yellow)%h%C(reset) %s%C(auto)%d%C(reset)'
export _git_log_oneline_medium_format='%C(bold yellow)%h%C(reset) %<(50,trunc)%s %C(bold blue)<%an> %C(reset)%C(cyan)(%ar)%C(auto)%ad%C(reset)'

git-current-branch() {
  git symbolic-ref -q --short HEAD
}

git-branch-delete-interactive() {
  local -a remotes
  if (( ${*[(I)(-r|--remotes)]} )); then
    remotes=(${^*:#-*})
  else
    remotes=(${(f)"$(command git rev-parse --abbrev-ref ${^*:#-*}@{u} 2>/dev/null)"}) || remotes=()
  fi
  if command git branch --delete ${@} && \
      (( ${#remotes} )) && \
      read -q "?Also delete remote branch(es) ${remotes} [y/N]? "; then
    print
    local remote
    for remote (${remotes}) command git push ${remote%%/*} :${remote#*/}
  fi
}

# HSTR configuration - add this to ~/.zshrc
# alias hh=hstr                    # hh to be alias for hstr
# setopt histignorespace           # skip cmds w/ leading space from history
export HSTR_CONFIG=hicolor       # get more colors
bindkey -s "\C-r" "\C-a hstr -- \C-j"     # bind hstr to Ctrl-r (for Vi mode check doc)

# export FZF_DEFAULT_COMMAND='rg --files --no-ignore-vcs --hidden'
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export PATH="/opt/homebrew/opt/postgresql@10/bin:$PATH"

# ===== Andre =====

# development shortcut {{{
alias be='bundle exec'
alias pa!='[[ -f config/puma.rb ]] && RAILS_RELATIVE_URL_ROOT=/`basename $PWD` bundle exec puma -C $PWD/config/puma.rb'
alias pa='[[ -f config/puma.rb ]] && RAILS_RELATIVE_URL_ROOT=/`basename $PWD` bundle exec puma -C $PWD/config/puma.rb -d'
alias kpa='[[ -f tmp/pids/puma.state ]] && bundle exec pumactl -S tmp/pids/puma.state stop'
alias rs='rails s'

alias apa!='RAILS_RELATIVE_URL_ROOT=/angel bundle exec puma -C config/puma.rb'
alias apa='RAILS_RELATIVE_URL_ROOT=/angel bundle exec puma -C config/puma.rb -d'
alias kapa='bundle exec pumactl -P /home/vagrant/p/angel/tmp/pids/puma.pid stop'

alias mc='mailcatcher --http-ip 0.0.0.0'
alias kmc='pkill -fe mailcatcher'
alias sk='[[ -f config/sidekiq.yml ]] && bundle exec sidekiq -C $PWD/config/sidekiq.yml -d'
alias ksk='pkill -fe sidekiq'

alias rcsb='rc --sandbox'
alias rct='rc test'
alias rdrst='rake db:reset RAILS_ENV=test'

alias nginx_test_and_reload='sudo nginx -t && sudo service nginx reload'
alias sync_time='sudo systemctl restart systemd-timesyncd.service'

alias sprs='spring stop && spring binstub'
alias rdr1="rake db:migrate:redo STEP=1"
rdrd() { rake db:migrate:redo STEP="$1" }
rdrv() { rake db:migrate:redo VERSION="$1" }

alias rcp='rubocop $1 -d'
alias fix_ssl='sync_time && sudo apt-get update && sudo apt-get install ca-certificates'

# skip patching migrate
alias mg="rake db:migrate SKIP_PATCHING_MIGRATION='skip_any_patching_related_migrations'"

lint() {
  [[ $PWD =~ '(.*perv|.*sg|.*nerv|.*amoeba)' ]] && project_path=$match[1]

  if [[ $project_path ]]; then
    "$project_path/clojure/adam/bin/lint" && "$project_path/eva/asuka/bin/lint"
  fi
  # if [[ $# -gt 0 ]]; then
  #   local files=$(eval "git diff $@ --diff-filter=d --name-only -- \*.{$exts} '$excludes'")
  # else
  #   local files=$(eval "git status --porcelain -- \*.{$exts} '$excludes' | sed -e '/^\s\?[DRC] /d' -e 's/^.\{3\}//g'")
  # fi
}
nrw() {
  local folder_path
  local folder_name
  local asuka_path

  [[ $PWD =~ '(.*perv|.*sg|.*nerv)' ]] && folder_path=$match[1]
  [[ $folder_path =~ '.*(perv|sg|nerv)$' ]] && folder_name=$match[1]

  asuka_path="$folder_path/clojure/projects/asuka"

  echo "run npm for $asuka_path, set NERV_BASE=$folder_name"
  cd $asuka_path && DEV_DARK_MODE=true NERV_BASE=/${=folder_name} npm run watch
}

cd_adam() {
  local folder_path
  local adam_path

  [[ $PWD =~ '(.*perv|.*sg|.*nerv)' ]] && folder_path=$match[1]

  cd "$folder_path/clojure/projects/adam"
}

start_all_server() {
  tmux splitw -v -p 80 \; selectp -U \; splitw -h -p 66 \;
  tmux send-keys -t 1 C-z 'nrw' Enter
  tmux send-keys -t 2 C-z 'cjn' Enter
  tmux send-keys -t 3 C-z 'rpu' Enter
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
  local folder_path
  [[ $PWD =~ '(.*amoeba|.*cam|.*perv|.*sg|.*nerv)' ]] && folder_path=$match[1]
  cd $folder_path

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


# # 啟動／停止 mailcatcher
# rmailcatcher() {
#   rm /home/vagrant/.nohup/mailcatcher.out
#   local pid=$(ps --no-headers -C mailcatcher -o pid,args | command grep '/bin/mailcatcher --http-ip' | sed 's/^ //' | cut -d' ' -f 1)
#   if [[ -n $pid ]]; then
#     kill $pid && echo "MailCatcher process $pid killed."
#   else
#     echo "Start MailCatcher process..."
#     nohup mailcatcher --http-ip 0.0.0.0 > ~/.nohup/mailcatcher.out 2>&1&
#     disown %nohup
#   fi
# }

pairg() { ssh -t $1 ssh -o 'StrictHostKeyChecking=no' -o 'UserKnownHostsFile=/dev/null' -p $2 -t ${3:-vagrant}@localhost 'tmux attach' }
pairh() { ssh -S none -o 'ExitOnForwardFailure=yes' -R $2\:localhost:22222 -t $1 'watch -en 10 who' }

cop() {
  local exts=('rb,thor,jbuilder')
  local excludes=':(top,exclude)db/schema.rb'
  local app=${$(pwd):t}
  local extra_options='--display-cop-names --rails'

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
alias rgr='rg_pcre2 $1 $2'

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

# alias gws=gwS
alias ws=gws
alias gsh='git show'
alias gba='gb -a'
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

alias ha=hanami
alias hac='ha console'
alias had='ha destroy'
alias hag='ha generate'
alias ham='ha generate migration'
alias has='ha server'
alias har='ha routes'

alias rgm='be rails g migration'

alias lsl='ls -al'

alias dumpdb='~/vm/scripts/dump_db.zsh'
alias dumpsg='scp dev.abagile.com:~/masked_db/nerv_staging_sg.custom ~/tmp/dumpdb/nerv_sg_development'
# alias dumpdb="DEV_PASSWORD='666' ~/vm/scripts/db_dump.rb"
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
alias aoc='cd ~/advant-of-code'
alias cms-sg 'cd ~/cms-sg'
alias angel='cd ~/angel'
alias adam='cd clojure/projects/adam'
alias asuka='cd clojure/projects/asuka'
alias lcl='cd clojure/components/lcl'
alias magi='cd clojure/components/magi'
alias asu=asuka
alias qt='cd clojure/projects/questionnaire'
alias kaworu='cd eva/kaworu'
alias aba='cd ~/amoeba'
alias cam='cd ~/cam'
# alias ndb='cd ~/tmp/dumpdb/nerv_development'
# alias pdb='cd ~/tmp/dumpdb/nerv_ck_development'

alias viz='vi ~/.dotfiles/stow/zsh/.zshrc'
alias viv='vi ~/.dotfiles/stow/nvim/.config/nvim/init.vim'
alias szsh="reload_zshrc"

alias krpu='rpu kill'

# clojure
alias cjn='cd_adam && clj -M:dev:nrepl'
alias ctr='cd_adam && clj -M:test:runner --watch'
alias ctrf='cd_adam && clj -M:test:runner --watch --focus $1'

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
  # command git rebase -i "HEAD~$1"
  # git rebase -i "HEAD~$1"
  git rebase -i "HEAD~$1"
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

asset_size() {
  rake assets:precompile
  du -sh public/assets
  rake assets:clobber
}

xxx() {
  $(echo "        nerv  1) nerv_masked.custom" | sed 's/.\+[0-9]) //g')
}
