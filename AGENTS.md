# AGENTS.md

Dotfiles deployed as one GNU Stow package into `$HOME`. Tests: `bash tests/run_tests.sh`;
CI: `.github/workflows/ci.yml` (no build step).

## Layout & Stow

- Repo root **is** the stow package: `stow -d ~/.dotfiles -t "$HOME" .` symlinks
  top-level dotfiles (`.zshrc`, `.vimrc`, `.tmux.conf`, `.irbrc`, `.config/`) into `$HOME`.
- `.stow-local-ignore` excludes non-dotfiles from stowing. **Any new top-level
  file/dir that is not a dotfile must be added there**, or stow symlinks it into `$HOME`.
- Per-area dirs (`zsh/`, `vim/`, `tmux/`, `shell/`) are NOT stowed — their `install.sh`
  scripts symlink pieces into `~/.oh-my-zsh/custom`, `~/.local/lib`, `~/.vim`, `~/.tmux/plugins`.
- `gnome/*.dconf` files are stored here only; no script applies them.

## Install flow

`scripts/ubuntu.sh` (apt/snap) and `scripts/termux.sh` (pkg) duplicate the same step
order: update system → install packages from `libs.list` / `termux/libs.list` →
set default shell (`chsh -s zsh`) → stow →
[ubuntu only: install mise + `mise install`] → run `shell/zsh/vim/tmux` install scripts.

- **Mirror every installer change in both scripts.** Termux never gets mise
  (`.zshrc` guards the mise plugin with `$TERMUX_VERSION`).
- Package lists are per-platform with different names (e.g. `gnupg2` vs `gnupg`).
  Ubuntu system packages go in root `libs.list`, Termux in `termux/libs.list`.
- CLI tools (bat, fd, fzf, jq, ripgrep, node, python, ruby, opencode, …) come from
  `.config/mise/config.toml`, **not** libs.list.
- Area `install.sh` scripts must stay idempotent: skip existing installs,
  `git pull --ff-only` vendor checkouts, `rm -rf` + `ln -s` for our own links.

## Where plugins live

- vim: vim-plug; plugin list in `.vimrc` (`Plug` lines); `vim/install.sh` installs
  vim-plug and runs `:PlugInstall`.
- tmux: TPM; plugin list in `.tmux.conf` (`@plugin` lines); `tmux/install.sh` clones
  tpm and runs install/update.
- zsh: oh-my-zsh; custom `copy` plugin + `bira-shell` theme (`zsh/custom`,
  `zsh/themes`) are symlinked into the oh-my-zsh custom dir by `zsh/install.sh`.
  New oh-my-zsh plugins must also be added to `plugins=(...)` in `.zshrc`.

## Script conventions

- `set -e`; resolve own dir with `DIR="$(dirname "$(readlink -f "$0")")"`;
  all output via `shell/prompt_utils.sh` helpers (`prompt_txt` / `show_success` /
  `show_warn` / `show_error`).
- Remote installers are downloaded to a file and run with explicit `bash` (never
  piped to a shell); the mise installer is SHA-256 verified against the GitHub
  release digest.
- Installers never clobber: existing dotfiles are moved to `.bak` once
  (`backup_once` in shell/prompt_utils.sh); if file and `.bak` both exist the
  installer skips and lets stow fail safely.

## Verification

`bash tests/run_tests.sh` — syntax (`bash -n` / `zsh -n`), unit tests for
`backup_once`, stow integration into a fake `$HOME` (catches `.stow-local-ignore`
leaks), package list sanity. Lint shell scripts with `shellcheck` — CI enforces
both. The `smoke` CI job additionally runs every `install.sh` on a clean runner;
every installer and area script is safe to re-run (e.g. `bash zsh/install.sh`).
