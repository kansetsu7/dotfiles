#!/usr/bin/env bash

link_file() {
  [ -f $2 ] && mv -f $2 $2\.backup
  ln -sf $1 $2
}

unlink_file() {
  if [ -L $1 ]; then
    rm -f $1
    [[ -f $1\.backup || -d $1\.backup ]] && mv -f $1\.backup $1
  fi
}

link_files() {
  # symlink configuration files
  link_file $1/config.zsh ~/.oh-my-zsh/custom/config.zsh
  link_file $1/gemrc ~/.gemrc
  link_file $1/gitconfig ~/.gitconfig
  link_file $1/inputrc ~/.inputrc
  link_file $1/pryrc ~/.pryrc
  link_file $1/psqlrc ~/.psqlrc
  link_file $1/tigrc ~/.tigrc
  link_file $1/tmux.conf ~/.tmux.conf
  link_file $1/vimrc.local ~/.vimrc.local
  link_file $1/vimrc.bundles.local ~/.vimrc.bundles.local

  link_file ~/.maximum-awesome/vim ~/.vim
  link_file ~/.maximum-awesome/vimrc ~/.vimrc
  link_file ~/.maximum-awesome/vimrc.bundles ~/.vimrc.bundles
}

unlink_files() {
  # unlink configuration files
  unlink_file ~/.oh-my-zsh/custom/config.zsh
  unlink_file ~/.gemrc
  unlink_file ~/.gitconfig
  unlink_file ~/.inputrc
  unlink_file ~/.pryrc
  unlink_file ~/.psqlrc
  unlink_file ~/.tigrc
  unlink_file ~/.tmux.conf
  unlink_file ~/.vimrc.local
  unlink_file ~/.vimrc.bundles.local

  unlink_file ~/.vim
  unlink_file ~/.vimrc
  unlink_file ~/.vimrc.bundles
}


if (uname -a | grep -i darwin > /dev/null); then
  SCRIPT_DIR=`cd -P -- "$(dirname -- $0)" && pwd -P`
else
  SCRIPT_DIR=`readlink -f $(dirname $0)`
fi
case "$1" in
  install)
    # install oh-my-zsh
    if [ -d ~/.oh-my-zsh ]; then
      echo 'oh-my-zsh already installed, skip ...'
    else
      git clone git://github.com/robbyrussell/oh-my-zsh.git ~/.oh-my-zsh
      [ -f ~/.zshrc ] && cp ~/.zshrc ~/.zshrc.backup
      cp ~/.oh-my-zsh/templates/zshrc.zsh-template ~/.zshrc
    fi
    sed -i "s/^plugins=\(.*\)/plugins=\(bundler chruby git git-extra rails ruby ssh-agent vi-mode\)/g" ~/.zshrc

    # install maximum-awesome
    if [ -d ~/.maximum-awesome ]; then
      echo 'maximum-awesome already installed, skip ...'
    else
      git clone git://github.com/square/maximum-awesome.git ~/.maximum-awesome
      git clone git://github.com/gmarik/vundle.git ~/.maximum-awesome/vim/bundle/vundle
      git clone git://github.com/altercation/vim-colors-solarized.git ~/.maximum-awesome/vim/bundle/vim-colors-solarized
    fi

    link_files $SCRIPT_DIR

    # refresh vim bundle plugins
    sh -c 'vim +BundleInstall +qall'

    # copy ssh.config 
    sudo cp /vagrant/config/example-ssh-config ~/.ssh/config

    echo "installation completed"

    # vim-plug
    curl -fLo ~/.local/share/nvim/site/autoload/plug.vim --create-dirs \
      https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

    vi -E -s -u ~/.config/nvim/init.vim +PlugInstall +qall
    echo "vim plug install done"
    ;;

  relink)
    unlink_files $SCRIPT_DIR
    link_files $SCRIPT_DIR
    echo "configuration symlinks updated"
    ;;

  unlink)
    unlink_files $SCRIPT_DIR
    echo "configuration symlinks removed"
    ;;

  uninstall)
    # move oh-my-zsh to backup directory
    [ -d ~/.oh-my-zsh ] && mv ~/.oh-my-zsh $SCRIPT_DIR/backup/
    mv -f ~/.zshrc $SCRIPT_DIR/backup/
    [ -f ~/.zshrc.backup ] && mv -f ~/.zshrc.backup ~/.zshrc

    # move maximum-awesome to backup directory
    [ -d ~/.maximum-awesome ] && mv ~/.maximum-awesome $SCRIPT_DIR/backup/

    unlink_files $SCRIPT_DIR
    echo "remove $SCRIPT_DIR to completely uninstall everything"
    ;;

  *)
    echo "Usage: $SCRIPT_DIR/run.sh {install|relink|unlink|uninstall}"
    ;;
esac

exit 0

