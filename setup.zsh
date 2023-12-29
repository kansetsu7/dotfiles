#!/usr/bin/env zsh

if [[ "`uname -s`" == "Darwin" ]]; then

  brew install asdf stow fzf nvim tig tmux httpie htop bat fd autojump lazygit exa just diff-so-fancy

  ln -sf $(brew --prefix)/opt/fzf ~/.fzf

  cd ~/.dotfiles/stow
  for s in *; do stow -t ~ $s; done

  sh -c 'curl -fLo "${XDG_DATA_HOME:-$HOME/.local/share}"/nvim/site/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'

  pip3 install pynvim

  nvim +PlugInstall +qall

else
  mkdir -p ~/.psql_history

  cd ~/.dotfiles/stow
  for s in *; do stow -t ~ $s; done

  if [ ! -d ~/.fzf ]; then
    git clone https://github.com/junegunn/fzf.git ~/.fzf
    yes n | ~/.fzf/install
  fi

  if [ ! `whence hstr` ]; then
    sudo add-apt-repository -y ppa:ultradvorka/ppa
    sudo apt update
    sudo apt install hstr
    # hstr --show-configuration >> ~/.zshrc
  fi

  vi +PlugInstall +qall

fi
