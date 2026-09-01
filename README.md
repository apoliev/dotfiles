# dotfiles

Configs for linux

## Installing

Clone the repo and run the matching installer with **bash**:

### Ubuntu

```bash
cd ~/.dotfiles
bash scripts/ubuntu.sh
```

### Termux

```bash
cd ~/.dotfiles
bash scripts/termux.sh
```

## What it does

- Updates the system and installs packages from `libs.list` (or `termux/libs.list`)
- Installs [mise](https://mise.jdx.dev) (always the latest release, with its
  official checksum verified before running) and the tools from `.config/mise/config.toml`
- Stows your dotfiles into `$HOME` via [GNU Stow](https://www.gnu.org/software/stow/)
- Loads shell/zsh/vim/tmux templates and plugins

## Safety

The installers never overwrite an existing config blindly:

- On the first run, any existing real file is moved to `<name>.bak`.
- On repeated runs, nothing is clobbered: if both the file and its `.bak`
  already exist, the installer skips it and lets `stow` fail safely so you can
  resolve the conflict manually.
- The mise installer is downloaded to a file, verified against the official
  SHA-256 digest, and executed with an explicit `bash`.

## Uninstalling

Remove the stowed symlinks without touching your data:

```bash
stow -d ~/.dotfiles -t "$HOME" -D .
