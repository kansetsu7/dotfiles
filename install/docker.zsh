#!/usr/bin/env zsh

if [[ ! -f /.dockerenv ]]; then
  echo 'Not a Docker env, please double check!'
  exit 1;
fi

echo 'You are in Docker...'
echo 'Install developer tools in general'
echo 'Setup Development Perferences (Nvim, Zim...)...'

folders=("git" "tig" "nvim" "pry" "tmux" "tmuxinator" "ctags" "ruby" "lazygit" "lazydocker")

for folder in "${folders[@]}"; do
  mkdir -p /root/.config/$folder
done

cd /root/.dotfiles  # should match with dotfiles volume in compose.yml

stow --verbose \
  git \
  nvim \
  readline \
  ruby \
  tmux \
  zsh \
  env \
  lazygit \
  lazydocker \
  claude \
  sql \

# https://github.com/tmux-plugins/tpm
if [[ ! -d /root/.config/tmux/plugins/tpm ]]; then
  echo 'Setup Tmux Plugin Manager(TMP)...'
  git clone https://github.com/tmux-plugins/tpm /root/.config/tmux/plugins/tpm
  tmux source /root/.config/tmux/tmux.conf
  echo 'Please Press tmux prefix key + I to install tmux plugins'
fi

# forced to provide $ZDOTDDIR here or it will have error at first time loading -> "Failed to source /root/.config/zsh/.zimrc"
ZDOTDIR=/root source /root/.zshrc

echo "Then You are all set!"

