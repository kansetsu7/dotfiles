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
  bin \
  git \
  nvim \
  readline \
  ruby \
  tmux \
  zsh \
  credentials \
  lazygit \
  lazydocker \
  claude \
  sql \

# lazydocker: pick the OS-specific config (its `up`/`upService` templates use
# absolute paths that differ per OS — see lazydocker/.config/lazydocker/configs/).
ln -sf configs/docker/config.yml /root/.config/lazydocker/config.yml

# https://github.com/tmux-plugins/tpm
if [[ ! -d /root/.config/tmux/plugins/tpm ]]; then
  echo 'Setup Tmux Plugin Manager(TMP)...'
  git clone https://github.com/tmux-plugins/tpm /root/.config/tmux/plugins/tpm
  tmux source /root/.config/tmux/tmux.conf
  echo 'Please Press tmux prefix key + I to install tmux plugins'
fi

# forced to provide $ZDOTDDIR here or it will have error at first time loading -> "Failed to source /root/.config/zsh/.zimrc"
ZDOTDIR=/root source /root/.zshrc

# install
npm install -g --prefix=/root/npm-global @anthropic-ai/claude-code@latest @google/gemini-cli

# GitLab MCP, registered at *user* scope. The stowed ~/.mcp.json is project
# scope: Claude Code finds it by walking up from the project dir, so /root/.mcp.json
# never applies to repos under /project. User scope covers every project, but
# lives in ~/.claude.json, which isn't stow-managed — hence this step.
claude mcp get gitlab > /dev/null 2>&1 || \
  claude mcp add-json -s user gitlab "{\"command\":\"$HOME/.dotfiles/claude/.claude/scripts/gitlab-mcp.sh\"}"

# Go tooling. nvim runs this gopls rather than Mason's (see
# nvim/.config/nvim/lua/config/lsp/init.lua) so the editor reports the same
# diagnostics as CI, which installs `gopls@latest` too. Re-run to refresh it:
# a gopls older than the project's Go toolchain mis-typechecks and goes quiet.
go install golang.org/x/tools/gopls@latest

echo "Then You are all set!"

