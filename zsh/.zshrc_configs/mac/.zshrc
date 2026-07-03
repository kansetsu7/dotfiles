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
alias e3='~/proj/vm/docker-dev/edit/e3/start.sh'
alias ob='~/Library/Mobile\ Documents/iCloud\~md\~obsidian/Documents/Obsidian\ Vault'


cl()  { CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1 claude }
cr()  { CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1 claude --resume }
cf()  { CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1 claude -r "$1" --fork-session }
cy()  { CLAUDE_CODE_SUBPROCESS_ENV_SCRUB=1 claude --dangerously-skip-permissions }

# Install/update the Claudian Obsidian plugin from a GitHub release tag.
# Usage: obplugin 2.0.27
obplugin() {
  if [[ -z "$1" ]]; then
    echo "Usage: obplugin <release-tag>" >&2
    return 1
  fi

  local base="https://github.com/YishenTu/claudian/releases/download/$1"

  # Reuse the `ob` alias for the vault path; eval to expand ~ and unescape spaces.
  local vault
  eval "vault=${aliases[ob]}"
  local dest="$vault/.obsidian/plugins/Claudian"

  local tmp
  tmp="$(mktemp -d)" || return 1

  local f
  for f in main.js manifest.json styles.css; do
    echo "Downloading $f..."
    if ! curl -fL --progress-bar -o "$tmp/$f" "$base/$f"; then
      echo "Failed to download $f" >&2
      rm -rf "$tmp"
      return 1
    fi
  done

  mkdir -p "$dest" || { rm -rf "$tmp"; return 1; }
  mv "$tmp"/* "$dest/" && rm -rf "$tmp"
  echo "Installed Claudian plugin files to $dest"
}
