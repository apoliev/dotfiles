#!/bin/bash

set -e

DIR="$(dirname "$(readlink -f "$0")")"

# shellcheck disable=SC1091
source "$DIR/../shell/prompt_utils.sh"

# Fail early with an install hint instead of dying halfway through.
# The package is "neovim" (apt/pkg name); the binary it provides is nvim.
require_cmds git:git nvim:neovim || exit 1

# Not fatal: only the gopls mason package needs the go toolchain to build.
# The mise step installs go; without it the other servers still install.
command -v go >/dev/null 2>&1 ||
  show_warn "go not found — the gopls (Go LSP) install will be skipped\n"

# Install/update plugins headlessly via lazy.nvim. The first run clones
# lazy.nvim and every plugin (treesitter parsers are compiled too — the
# config installs them synchronously); repeated runs are no-ops.
prompt_txt 'Install/update Neovim plugins...'
if nvim --headless "+Lazy! sync" +qa; then
  show_success "Success\n"
else
  show_error 'Error'
  exit 1
fi

# LSP servers via mason (ruby-lsp, gopls, pyright, typescript-language-
# server). MasonInstallAll waits for the installs to finish; if the network
# fails here it is not fatal — the config re-runs it on the next nvim launch.
prompt_txt 'Install LSP servers (mason)...'
if nvim --headless "+MasonInstallAll" +qa; then
  show_success "Success\n"
else
  show_error 'Error'
  exit 1
fi
