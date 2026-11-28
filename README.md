# dotfiles

Configs for linux

## Installing

Clone the repo and run the matching installer with **bash**:

### Ubuntu

```bash
cd ~/.dotfiles
bash scripts/ubuntu.sh
```

Without arguments every step runs in the default order. To run only
selected steps (for example on an account without admin rights), list them:

```bash
bash scripts/ubuntu.sh help           # list all steps
bash scripts/ubuntu.sh stow zsh vim   # only these steps
bash scripts/ubuntu.sh all            # everything, in the default order
```

Steps that need `sudo` (`update`, `packages`, `chsh`) are skipped with a
warning when the account has no admin rights. The per-area install scripts
(`zsh/install.sh`, `vim/install.sh`, `nvim/install.sh`, `tmux/install.sh`)
check their dependencies up front and print the exact install command if
something is missing.

### Termux

```bash
cd ~/.dotfiles
bash scripts/termux.sh
```

Same step selection as on Ubuntu (without `mise`): `bash scripts/termux.sh stow zsh`.

## What it does

- Updates the system and installs packages from `libs.list` (or `termux/libs.list`)
- Installs [mise](https://mise.jdx.dev) (always the latest release, with its
  official checksum verified before running) and the tools from
  `.config/mise/config.toml` (`mise install` + `mise up` to update them)
- Stows your dotfiles into `$HOME` via [GNU Stow](https://www.gnu.org/software/stow/)
- Loads shell/zsh/vim/nvim/tmux templates and plugins

## Safety

The installers never overwrite an existing config blindly:

- On the first run, any existing real file is moved to `<name>.bak`.
- The same applies to symlinks stow doesn't own (for example an absolute
  `~/.zshrc` left behind by the oh-my-zsh installer): they are moved to
  `<name>.bak` too, and stow recreates its own relative link on the next run
  instead of failing with "existing target is not owned by stow".
- On repeated runs, nothing is clobbered: if both the file and its `.bak`
  already exist, the installer skips it and lets `stow` fail safely so you can
  resolve the conflict manually.
- The mise installer is downloaded to a file, verified against the official
  SHA-256 digest, and executed with an explicit `bash`.

## Uninstalling

Remove the stowed symlinks without touching your data:

```bash
stow -d ~/.dotfiles -t "$HOME" -D .
