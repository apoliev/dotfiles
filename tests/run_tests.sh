#!/bin/bash
# Test suite for the dotfiles repo: syntax checks, backup_once unit tests,
# stow package integration and package list sanity. No framework, pure bash.
# Run from anywhere: bash tests/run_tests.sh

set -u

DIR="$(dirname "$(readlink -f "$0")")"
REPO_ROOT="$(dirname "$DIR")"

pass=0
fail=0

ok()  { pass=$((pass + 1)); echo "  ok   - $1"; }
bad() { fail=$((fail + 1)); echo "  FAIL - $1"; }

expect_ok() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else bad "$d"; fi; }

# shellcheck disable=SC1091
source "$REPO_ROOT/shell/prompt_utils.sh"

echo "== syntax: bash -n =="
while IFS= read -r f; do
  expect_ok "bash -n $f" bash -n "$f"
done < <(find "$REPO_ROOT" -name '*.sh' -not -path '*/.git/*' | sort)

echo "== syntax: zsh -n =="
if command -v zsh >/dev/null 2>&1; then
  while IFS= read -r f; do
    expect_ok "zsh -n $f" zsh -n "$f"
  done < <(find "$REPO_ROOT" \( -name '*.zsh' -o -name '*.zsh-theme' -o -name '.zshrc' \) -not -path '*/.git/*' | sort)
else
  echo "  skip - zsh not installed"
fi

echo "== syntax: bash -n (no .sh extension) =="
expect_ok "bash -n sourcecraft/sc-ipc" bash -n "$REPO_ROOT/sourcecraft/sc-ipc"

echo "== unit: backup_once =="
t="$(mktemp -d)"

expect_ok "missing file: rc 0, no backup created" bash -c "
  source '$REPO_ROOT/shell/prompt_utils.sh'
  backup_once '$t/missing' && [ ! -e '$t/missing.bak' ]"

echo x > "$t/f"
expect_ok "real file: moved to .bak" bash -c "
  source '$REPO_ROOT/shell/prompt_utils.sh'
  backup_once '$t/f' && [ -e '$t/f.bak' ] && [ ! -e '$t/f' ]"

echo x > "$t/g"; echo y > "$t/g.bak"
expect_ok "file + .bak both exist: refuses (rc 1), both kept" bash -c "
  source '$REPO_ROOT/shell/prompt_utils.sh'
  if backup_once '$t/g'; then exit 1; fi
  [ -e '$t/g' ] && [ -e '$t/g.bak' ]"

ln -s /etc/hostname "$t/l"
expect_ok "symlink: rc 0, symlink untouched" bash -c "
  source '$REPO_ROOT/shell/prompt_utils.sh'
  backup_once '$t/l' && [ -L '$t/l' ]"

rm -rf "$t"

echo "== integration: stow into fake \$HOME =="
if command -v stow >/dev/null 2>&1; then
  fake="$(mktemp -d)"
  # mirror stow_home(): ~/.config must pre-exist, or stow claims the whole dir
  mkdir -p "$fake/.config"
  # app-created configs block stow — stow_home() backs them up first; mirror that
  mkdir -p "$fake/.config/opencode"
  printf '{"schema":"pre-existing"}\n' >"$fake/.config/opencode/opencode.jsonc"
  # shellcheck disable=SC1091
  source "$REPO_ROOT/shell/prompt_utils.sh"
  backup_once "$fake/.config/opencode/opencode.jsonc"
  expect_ok "stow succeeds" stow -d "$REPO_ROOT" -t "$fake" .
  for l in .zshrc .vimrc .tmux.conf .irbrc; do
    expect_ok "linked: $l" bash -c "[ -L '$fake/$l' ] && [ '$fake/$l' -ef '$REPO_ROOT/$l' ]"
  done
  expect_ok "not hijacked: .config" bash -c "[ -d '$fake/.config' ] && [ ! -L '$fake/.config' ]"
  expect_ok "linked: .config/mise" bash -c "[ '$fake/.config/mise/config.toml' -ef '$REPO_ROOT/.config/mise/config.toml' ]"
  expect_ok "linked: opencode.jsonc" bash -c "[ -L '$fake/.config/opencode/opencode.jsonc' ] && [ '$fake/.config/opencode/opencode.jsonc' -ef '$REPO_ROOT/.config/opencode/opencode.jsonc' ]"
  expect_ok "opencode.jsonc original kept as .bak" bash -c "[ -f '$fake/.config/opencode/opencode.jsonc.bak' ]"
  for f in README.md AGENTS.md libs.list .stow-local-ignore .git .devcontainer \
           scripts shell sourcecraft zsh vim tmux termux gnome tests .github; do
    expect_ok "not leaked: $f" bash -c "[ ! -e '$fake/$f' ] && [ ! -L '$fake/$f' ]"
  done
  stow -D -d "$REPO_ROOT" -t "$fake" .
  rm -rf "$fake"
else
  echo "  skip - stow not installed"
fi

echo "== sanity: package lists =="
for list in "$REPO_ROOT/libs.list" "$REPO_ROOT/termux/libs.list"; do
  label="${list#"$REPO_ROOT"/}"
  expect_ok "exists and non-empty: $label" test -s "$list"
  expect_ok "no duplicates: $label" bash -c "! sort '$list' | uniq -d | grep -q ."
done

echo "== sanity: tpm headless fork-bomb guard =="
expect_ok "install.sh sets TMUX_HEADLESS for tpm scripts" \
  bash -c "grep -q 'TMUX_HEADLESS=1 bash' '$REPO_ROOT/tmux/install.sh'"
expect_ok ".tmux.conf guards run -b tpm with TMUX_HEADLESS" \
  bash -c "grep -q 'TMUX_HEADLESS' '$REPO_ROOT/.tmux.conf'"

echo "== sanity: app-created configs backed up before stow =="
expect_ok "ubuntu.sh backs up opencode.jsonc" \
  bash -c "grep -q 'backup_once.*opencode/opencode.jsonc' '$REPO_ROOT/scripts/ubuntu.sh'"

echo "== sanity: sourcecraft zsh plugin =="
expect_ok "zsh/install.sh links sourcecraft plugin" \
  bash -c "grep -q 'custom/plugins/sourcecraft' '$REPO_ROOT/zsh/install.sh'"
expect_ok "sourcecraft plugin is enabled by default" \
  bash -c "grep -Eq '^[[:space:]]+sourcecraft[[:space:]]*$' '$REPO_ROOT/.zshrc'"
expect_ok "sourcecraft plugin guards on src binary" \
  bash -c "grep -q 'sourcecraft/bin/src' '$REPO_ROOT/zsh/custom/plugins/sourcecraft/sourcecraft.plugin.zsh'"

echo "== sanity: sourcecraft install.sh =="
expect_ok "auth check uses src auth status, not quota" \
  bash -c "grep -q 'auth status' '$REPO_ROOT/sourcecraft/install.sh' && ! grep -q 'quota' '$REPO_ROOT/sourcecraft/install.sh'"
expect_ok "auth check is wrapped in timeout" \
  bash -c "grep -q 'timeout' '$REPO_ROOT/sourcecraft/install.sh'"

echo
echo "passed: $pass, failed: $fail"
[ "$fail" -eq 0 ]
