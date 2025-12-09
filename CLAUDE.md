# Dotfiles Repository

## Environment

This is a dotfiles repo used inside a dockerized dev environment.

- **Dockerized dev repo**: `/project/vm/docker-dev/`
- **Dockerfile**: `/project/vm/docker-dev/src/build/edit/e3/Dockerfile`
- **Compose file**: `/project/vm/docker-dev/edit/e3/compose.yml`
- **Base image**: Alpine Linux 3.23
- **Symlink manager**: GNU Stow

### Important Notes

- Packages installed at runtime will **not persist** after container restart
- To persist packages, add them to the Dockerfile
- Go tools are installed to `/cache/go/bin` (may be a mounted volume)
- When suggesting package installations, remind about Dockerfile updates

## Structure

- `nvim/` - Neovim configuration (stow target: `~/.config/nvim`)
- `zsh/` - Zsh configuration
- `claude/` - Claude Code settings

## Stow Usage

```bash
# Link configs
stow --verbose nvim

# If conflicts with existing files, adopt them into repo
stow --adopt --verbose nvim
```
