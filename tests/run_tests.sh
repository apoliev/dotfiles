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
  # mirror stow_home(): ~/.config must pre-exist, or stow claims the whole dir
  mkdir -p "$fake/.config"
  # opencode keeps its own artifacts in the real ~/.config/opencode; stow must
  # skip them (.stow-local-ignore), never back them up and never link over them
  mkdir -p "$fake/.config/opencode"
  mkdir -p "$fake/.config/opencode/node_modules"
  printf '{}\n' >"$fake/.config/opencode/package.json"
  printf 'lock\n' >"$fake/.config/opencode/package-lock.json"
  printf 'ig\n' >"$fake/.config/opencode/.gitignore"
  # stale repo-side artifacts (opencode once ran inside the repo): must be
  # ignored too, or stow tree-folds/conflicts with the fake $HOME copies
  repo_nm="$REPO_ROOT/.config/opencode/node_modules"
  repo_pj="$REPO_ROOT/.config/opencode/package.json"
  test_nm=0; test_pj=0
  if [ ! -e "$repo_nm" ]; then mkdir -p "$repo_nm"; test_nm=1; fi
  if [ ! -e "$repo_pj" ]; then printf '{}\n' >"$repo_pj"; test_pj=1; fi
  expect_ok "stow succeeds" stow -d "$REPO_ROOT" -t "$fake" .
  for l in .zshrc .vimrc .tmux.conf .irbrc; do
    expect_ok "linked: $l" bash -c "[ -L '$fake/$l' ] && [ '$fake/$l' -ef '$REPO_ROOT/$l' ]"
  done
  expect_ok "not hijacked: .config" bash -c "[ -d '$fake/.config' ] && [ ! -L '$fake/.config' ]"
  expect_ok "linked: .config/mise" bash -c "[ '$fake/.config/mise/config.toml' -ef '$REPO_ROOT/.config/mise/config.toml' ]"
  expect_ok "linked: opencode.jsonc" \
    bash -c "[ -L '$fake/.config/opencode/opencode.jsonc' ] && [ '$fake/.config/opencode/opencode.jsonc' -ef '$REPO_ROOT/.config/opencode/opencode.jsonc' ]"
  expect_ok "linked: opencode cli.json" \
    bash -c "[ -L '$fake/.config/opencode/cli.json' ] && [ '$fake/.config/opencode/cli.json' -ef '$REPO_ROOT/.config/opencode/cli.json' ]"
  expect_ok "linked: opencode agents" \
    bash -c "[ '$fake/.config/opencode/agents/architect.md' -ef '$REPO_ROOT/.config/opencode/agents/architect.md' ]"
  expect_ok "untouched: opencode artifacts" bash -c "
    [ -d '$fake/.config/opencode/node_modules' ] &&
    [ \"\$(cat '$fake/.config/opencode/package.json')\" = '{}' ] &&
    [ ! -L '$fake/.config/opencode/package.json' ]"
  expect_ok "repo artifacts not linked into \$HOME node_modules" \
    bash -c "[ -z \"\$(ls -A '$fake/.config/opencode/node_modules')\" ]"
  for f in README.md AGENTS.md libs.list .stow-local-ignore .git .gitignore .devcontainer \
           .agents scripts shell zsh vim tmux termux gnome tests .github; do
    expect_ok "not leaked: $f" bash -c "[ ! -e '$fake/$f' ] && [ ! -L '$fake/$f' ]"
  done
  [ "$test_pj" -eq 1 ] && rm -f "$repo_pj"
  [ "$test_nm" -eq 1 ] && rm -rf "$repo_nm"
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

echo "== sanity: opencode config is stowed, secrets are not =="
expect_ok "ubuntu.sh backs up opencode.jsonc" \
  bash -c "grep -q 'backup_once.*opencode/opencode.jsonc' '$REPO_ROOT/scripts/ubuntu.sh'"
expect_ok "termux.sh backs up opencode.jsonc" \
  bash -c "grep -q 'backup_once.*opencode/opencode.jsonc' '$REPO_ROOT/scripts/termux.sh'"
expect_ok "ubuntu.sh backs up cli.json" \
  bash -c "grep -q 'backup_once.*opencode/cli.json' '$REPO_ROOT/scripts/ubuntu.sh'"
expect_ok "termux.sh backs up cli.json" \
  bash -c "grep -q 'backup_once.*opencode/cli.json' '$REPO_ROOT/scripts/termux.sh'"
expect_ok "stow ignore covers service.json" \
  bash -c "grep -q 'service.*json' '$REPO_ROOT/.stow-local-ignore'"
expect_ok "gitignore covers service.json" \
  bash -c "grep -q 'opencode/service.json' '$REPO_ROOT/.gitignore'"
expect_ok "stow does not ignore opencode.jsonc" \
  bash -c "! grep -q 'opencode.*jsonc' '$REPO_ROOT/.stow-local-ignore'"

echo "== sanity: .stow-local-ignore covers opencode artifacts and .agents =="
expect_ok "ignores node_modules" \
  bash -c "grep -q '^node_modules$' '$REPO_ROOT/.stow-local-ignore'"
expect_ok "ignores package.json" \
  bash -c "grep -q '^package\.json$' '$REPO_ROOT/.stow-local-ignore'"
expect_ok "ignores .agents" \
  bash -c "grep -q '^\.agents$' '$REPO_ROOT/.stow-local-ignore'"

echo
echo "passed: $pass, failed: $fail"
[ "$fail" -eq 0 ]
