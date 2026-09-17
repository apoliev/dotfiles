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
  expect_ok "stow succeeds" stow -d "$REPO_ROOT" -t "$fake" .
  for l in .zshrc .vimrc .tmux.conf .irbrc .config; do
    expect_ok "linked: $l" bash -c "[ -L '$fake/$l' ] && [ '$fake/$l' -ef '$REPO_ROOT/$l' ]"
  done
  for f in README.md AGENTS.md libs.list .stow-local-ignore .git \
           scripts shell zsh vim tmux termux gnome tests .github; do
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

echo
echo "passed: $pass, failed: $fail"
[ "$fail" -eq 0 ]
