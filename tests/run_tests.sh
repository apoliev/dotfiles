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
  # opencode.jsonc is no longer stowed (sourcecraft/update-models generates it
  # in $HOME) — stow must never link over it and stow_home() no longer backs it up
  mkdir -p "$fake/.config/opencode"
  printf '{"schema":"pre-existing"}\n' >"$fake/.config/opencode/opencode.jsonc"
  # opencode keeps its own artifacts in the real ~/.config/opencode; stow must
  # skip them (.stow-local-ignore), never back them up and never link over them
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
  expect_ok "opencode.jsonc not stowed (machine-generated)" \
    bash -c "[ -f '$fake/.config/opencode/opencode.jsonc' ] && [ ! -L '$fake/.config/opencode/opencode.jsonc' ]"
  expect_ok "untouched: opencode artifacts" bash -c "
    [ -d '$fake/.config/opencode/node_modules' ] &&
    [ \"\$(cat '$fake/.config/opencode/package.json')\" = '{}' ] &&
    [ ! -L '$fake/.config/opencode/package.json' ]"
  expect_ok "repo artifacts not linked into \$HOME node_modules" \
    bash -c "[ -z \"\$(ls -A '$fake/.config/opencode/node_modules')\" ]"
  for f in README.md AGENTS.md libs.list .stow-local-ignore .git .gitignore .devcontainer \
           .agents scripts shell sourcecraft zsh vim tmux termux gnome tests .github; do
    expect_ok "not leaked: $f" bash -c "[ ! -e '$fake/$f' ] && [ ! -L '$fake/$f' ]"
  done
  [ "$test_pj" -eq 1 ] && rm -f "$repo_pj"
  [ "$test_nm" -eq 1 ] && rm -rf "$repo_nm"
  stow -D -d "$REPO_ROOT" -t "$fake" .
  rm -rf "$fake"
else
  echo "  skip - stow not installed"
fi

echo "== integration: sourcecraft model catalog -> opencode config =="
if command -v python3 >/dev/null 2>&1; then
  fake="$(mktemp -d)"
  mkdir -p "$fake/.cache/sourcecraft" "$fake/.config/opencode" "$fake/.dotfiles"
  cat >"$fake/.cache/sourcecraft/models-v3-test.json" <<'JSON'
{"data":[
 {"id":"default","name":"SourceCraft Default","external":true,"context_length":1048576,
  "max_output_tokens":32768,
  "architecture":{"input_modalities":["text"],"output_modalities":["text"]},
  "reasoning":{"default_effort":"high","supported_efforts":["none","high"]}},
 {"id":"kimi-k3","name":"Kimi K3","external":true,"context_length":1000000,
  "max_output_tokens":32768,
  "architecture":{"input_modalities":["text","image"],"output_modalities":["text"]},
  "reasoning":{"default_effort":"high","supported_efforts":["none","low","high","max"]}},
 {"id":"deepseek-v4.1-flash","name":"DeepSeek V4.1 Flash","external":false,
  "context_length":512000,"max_output_tokens":32768,
  "architecture":{"input_modalities":["text","image"],"output_modalities":["text"]},
  "reasoning":{"default_effort":"high","supported_efforts":["none","high"]}}
]}
JSON
  printf '{"schema":"https://opencode.ai/config.json","custom":{"keep":true}}\n' \
    >"$fake/.config/opencode/opencode.jsonc"
  HOME="$fake" python3 "$REPO_ROOT/sourcecraft/update-models" >/dev/null
  if HOME="$fake" python3 - <<'EOF' 2>/dev/null
import json, os
cfg = json.load(open(os.path.expanduser("~/.config/opencode/opencode.jsonc")))
p = cfg["provider"]
assert p["sourcecraft-external"]["models"]["kimi-k3"]["attachment"] is True
assert p["sourcecraft-external"]["options"]["apiKey"] == "{env:SOURCECRAFT_IPC_API_KEY}"
assert p["sourcecraft"]["models"]["default"]["limit"]["context"] == 1048576  # default stays internal
assert "deepseek-v4.1-flash" in p["sourcecraft"]["models"]
assert "kimi-k3" not in p["sourcecraft"]["models"]
assert p["sourcecraft"]["models"]["deepseek-v4.1-flash"]["variants"]["none"] == {"reasoningEffort": "none"}
assert cfg["custom"] == {"keep": True}
assert cfg["$schema"] == "https://opencode.ai/config.json"
EOF
  then ok "generator maps catalog into providers, keeps user keys"; else bad "generator mapping"; fi
  before="$(md5sum "$fake/.config/opencode/opencode.jsonc" | cut -d' ' -f1)"
  HOME="$fake" python3 "$REPO_ROOT/sourcecraft/update-models" >/dev/null
  after="$(md5sum "$fake/.config/opencode/opencode.jsonc" | cut -d' ' -f1)"
  expect_ok "generator is idempotent" bash -c "[ '$before' = '$after' ]"
  # a symlink into the dotfiles repo is replaced by the generated file
  printf '{"schema":"x"}\n' >"$fake/.dotfiles/old.jsonc"
  ln -sfn "$fake/.dotfiles/old.jsonc" "$fake/.config/opencode/opencode.jsonc"
  HOME="$fake" python3 "$REPO_ROOT/sourcecraft/update-models" >/dev/null
  expect_ok "stowed symlink replaced by generated config" \
    bash -c "[ ! -L '$fake/.config/opencode/opencode.jsonc' ] && [ -f '$fake/.config/opencode/opencode.jsonc' ]"
  rm -rf "$fake"
else
  echo "  skip - python3 not installed"
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

echo "== sanity: opencode.jsonc is generated, not stowed =="
expect_ok "ubuntu.sh does not back up opencode.jsonc anymore" \
  bash -c "! grep -q 'backup_once.*opencode/opencode.jsonc' '$REPO_ROOT/scripts/ubuntu.sh'"
expect_ok "stow ignore covers opencode.jsonc" \
  bash -c "grep -q 'opencode\\\\.jsonc' '$REPO_ROOT/.stow-local-ignore'"
expect_ok "install.sh regenerates the provider config" \
  bash -c "grep -q 'update-models' '$REPO_ROOT/sourcecraft/install.sh'"

echo "== sanity: .stow-local-ignore covers opencode artifacts and .agents =="
expect_ok "ignores node_modules" \
  bash -c "grep -q '^node_modules$' '$REPO_ROOT/.stow-local-ignore'"
expect_ok "ignores package.json" \
  bash -c "grep -q '^package\.json$' '$REPO_ROOT/.stow-local-ignore'"
expect_ok "ignores .agents" \
  bash -c "grep -q '^\.agents$' '$REPO_ROOT/.stow-local-ignore'"

echo "== sanity: sourcecraft zsh plugin is off by default =="
expect_ok "toggle.sh is executable" \
  bash -c "[ -x '$REPO_ROOT/sourcecraft/toggle.sh' ]"
expect_ok "zsh/install.sh does not link sourcecraft plugin" \
  bash -c "! grep -q 'custom/plugins/sourcecraft' '$REPO_ROOT/zsh/install.sh'"
expect_ok "sourcecraft plugin is not enabled in .zshrc" \
  bash -c "! grep -Eq '^[[:space:]]+sourcecraft[[:space:]]*$' '$REPO_ROOT/.zshrc'"
expect_ok "sourcecraft plugin file guards on src binary" \
  bash -c "grep -q 'sourcecraft/bin/src' '$REPO_ROOT/zsh/custom/plugins/sourcecraft/sourcecraft.plugin.zsh'"

echo "== sanity: sourcecraft install.sh =="
expect_ok "auth check uses src auth status, not quota" \
  bash -c "grep -q 'auth status' '$REPO_ROOT/sourcecraft/install.sh' && ! grep -q 'quota' '$REPO_ROOT/sourcecraft/install.sh'"
expect_ok "auth check is wrapped in timeout" \
  bash -c "grep -q 'timeout' '$REPO_ROOT/sourcecraft/install.sh'"
expect_ok "unit template sets PATH placeholder" \
  bash -c "grep -q '^Environment=PATH=@PATH@$' '$REPO_ROOT/sourcecraft/sourcecraft-ipc.service.in'"
expect_ok "unit template has EXTRA_ENV placeholder for display vars" \
  bash -c "grep -q '^@EXTRA_ENV@$' '$REPO_ROOT/sourcecraft/sourcecraft-ipc.service.in'"
expect_ok "install.sh substitutes unit PATH (WSL browser detection)" \
  bash -c "grep -q '@PATH@|' '$REPO_ROOT/sourcecraft/install.sh' && grep -q 'cmd.exe' '$REPO_ROOT/sourcecraft/install.sh'"
expect_ok "install.sh passes display env to unit (native Linux)" \
  bash -c "grep -q '@EXTRA_ENV@|' '$REPO_ROOT/sourcecraft/install.sh' && grep -q 'WAYLAND_DISPLAY' '$REPO_ROOT/sourcecraft/install.sh'"

echo "== integration: toggle.sh disable =="
if command -v python3 >/dev/null 2>&1; then
  fake="$(mktemp -d)"
  mkdir -p "$fake/.config/opencode" "$fake/.oh-my-zsh/custom/plugins" \
    "$fake/.config/systemd/user" "$fake/.config/sourcecraft-ipc" "$fake/.cache/sourcecraft"
  cat >"$fake/.config/opencode/opencode.jsonc" <<'JSON'
{"$schema":"https://opencode.ai/config.json","provider":{"sourcecraft":{"name":"SourceCraft"},"sourcecraft-external":{"name":"External"},"custom":{"name":"Keep"}},"model":"custom/x"}
JSON
  ln -s "$REPO_ROOT/zsh/custom/plugins/sourcecraft" "$fake/.oh-my-zsh/custom/plugins/sourcecraft"
  cat >"$fake/.zshrc" <<'ZRC'
plugins=(
  copy
  qrcode
  sourcecraft
)

plugins+=(zoxide)
ZRC
  printf 'unit\n' >"$fake/.config/systemd/user/sourcecraft-ipc.service"
  printf 'key\n' >"$fake/.config/sourcecraft-ipc/key"
  expect_ok "toggle disable exits 0" \
    bash -c "HOME='$fake' '$REPO_ROOT/sourcecraft/toggle.sh' disable"
  if HOME="$fake" python3 - <<'EOF' 2>/dev/null
import json, os
cfg = json.load(open(os.path.expanduser("~/.config/opencode/opencode.jsonc")))
p = cfg["provider"]
assert "sourcecraft" not in p and "sourcecraft-external" not in p
assert p["custom"] == {"name": "Keep"}
assert cfg["model"] == "custom/x"
assert cfg["$schema"] == "https://opencode.ai/config.json"
EOF
  then ok "disable strips only sourcecraft providers"; else bad "disable provider strip"; fi
  expect_ok "disable removes the systemd unit file" \
    bash -c "[ ! -e '$fake/.config/systemd/user/sourcecraft-ipc.service' ]"
  expect_ok "disable unlinks the omz plugin" \
    bash -c "[ ! -e '$fake/.oh-my-zsh/custom/plugins/sourcecraft' ]"
  expect_ok "disable removes the plugin from plugins=(...)" \
    bash -c "! grep -Eq '^[[:space:]]+sourcecraft[[:space:]]*$' '$fake/.zshrc'"
  expect_ok "disable keeps other plugins" \
    bash -c "grep -q '  copy' '$fake/.zshrc' && grep -q 'plugins+=(zoxide)' '$fake/.zshrc'"
  expect_ok "disable keeps data without --purge" \
    bash -c "[ -f '$fake/.config/sourcecraft-ipc/key' ]"
  HOME="$fake" "$REPO_ROOT/sourcecraft/toggle.sh" disable --purge >/dev/null
  expect_ok "disable --purge removes key dir and model cache" \
    bash -c "[ ! -e '$fake/.config/sourcecraft-ipc' ] && [ ! -e '$fake/.cache/sourcecraft' ]"
  # a config with nothing but SourceCraft is removed entirely
  cat >"$fake/.config/opencode/opencode.jsonc" <<'JSON'
{"$schema":"https://opencode.ai/config.json","provider":{"sourcecraft":{"name":"SourceCraft"}}}
JSON
  HOME="$fake" "$REPO_ROOT/sourcecraft/toggle.sh" disable >/dev/null
  expect_ok "only-sourcecraft config is removed entirely" \
    bash -c "[ ! -e '$fake/.config/opencode/opencode.jsonc' ]"
  expect_ok "status exits 0 on a clean machine" \
    bash -c "HOME='$fake' '$REPO_ROOT/sourcecraft/toggle.sh' status"
  rm -rf "$fake"
else
  echo "  skip - python3 not installed"
fi

echo
echo "passed: $pass, failed: $fail"
[ "$fail" -eq 0 ]
