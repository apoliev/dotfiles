---
name: devcontainer-sandbox
description: Build a hardened devcontainer sandbox for safely running AI coding agents (opencode harness) in any project, regardless of its stack. Use when the user asks to create a devcontainer, agent sandbox, isolated environment for opencode/agents, or to isolate agent work from the host.
---

# Devcontainer agent sandbox

Create a Docker-based sandbox in which coding agents (opencode as harness) can
work on any project without being able to damage the host. The container is
the security boundary — not tool-level permission prompts.

The sandbox is stack-agnostic: detect what the project needs, then generate
its `.devcontainer/` around that. Always install mise so tools can be added
later with one command (`mise use`). Default shell is bash.

## Workflow

### 1. Recon the project (mandatory, before asking anything)

Read whatever exists of: `README.md`, `AGENTS.md` / `CLAUDE.md` / `CONTRIBUTING.md`,
`.github/workflows/*` (CI reveals the real build/test setup), and every
dependency manifest:

| Manifest | Stack | mise tool |
| --- | --- | --- |
| `package.json` / lockfiles | Node.js | `node` |
| `pyproject.toml`, `requirements*.txt`, `setup.py` | Python | `python` |
| `go.mod` | Go | `go` |
| `Cargo.toml` | Rust | `rust` |
| `Gemfile` | Ruby | `ruby` |
| `pom.xml` / `build.gradle*` | Java | `java` |
| `composer.json` | PHP | `php` |
| `*.csproj` / `*.sln` | .NET | `dotnet` |
| `mix.exs` | Elixir | `elixir` |

Also check: `mise.toml` / `.tool-versions` / `.config/mise/config.toml`
(existing tool pinning — reuse it), `Dockerfile` (system deps), docs for
native libs (postgres/mysql clients, imagemagick, ffmpeg, ...), services the
tests need. Existing mise config wins: `COPY` it, don't invent versions.

From this derive two lists: **apt system packages** (compilers, native lib
-dev packages, CLI utilities) and **mise tools** (language runtimes +
`opencode = "latest"`). When a native build fails on a missing `-dev` lib,
add it — build-essential/pkg-config are cheap defaults.

### 2. Interview the user (defaults in parentheses)

- Shell: **bash** (default — ask only to offer alternatives like zsh/fish).
- opencode auth: read-only bind-mount of host
  `~/.local/share/opencode/auth.json` (recommended) vs env vars vs manual
  `opencode auth login` in the container.
- Push access for agents: none — local commits only, no `~/.ssh`/gh
  credentials mounted (recommended). Push from the host.
- Hardening: `--cap-drop=ALL` + `no-new-privileges`, no docker.sock
  (recommended). All privileged work happens at image build time; sudo is
  intentionally broken in the container.
- Secrets: only via `remoteEnv` mappings and `{env:VAR}` interpolation —
  never hardcoded in committed files. If a token was ever committed, tell
  the user to rotate it.

### 3. Write the four files (templates below) into `.devcontainer/`

### 4. Repo integration

- Add `.devcontainer/*.sh` to the CI shellcheck file list.

### 5. Verify (checklist at the bottom), then remind the user to restart
opencode if config changed.

## Isolation model

- The repo is bind-mounted **inside** the container user's `$HOME`
  (`target=/home/<user>/<reponame>`), and `workspaceFolder` is that same
  path. Agents get a realistic environment; nothing on the host is touched.
- Container user UID/GID **must match the host user's UID/GID** so the
  bind-mounted repo stays writable without capabilities.
- Credential files (auth.json etc.) are bind-mounted **read-only**; secrets
  never enter the image.
- No docker.sock, no `~/.ssh`, no gh config → agents cannot push or reach
  the docker daemon. Local commits still work (git identity via env/config).
- Network stays open — model APIs and package downloads need it.
- Inside the sandbox set opencode `permission: {edit/bash/webfetch: allow}`
  via an overlay config (`OPENCODE_CONFIG` env): asking for confirmation is
  pointless when the container already bounds the blast radius.

## Templates

Parameterize: `<USER>` (container user, e.g. `agent` or `vscode`),
`<UID>`/`<GID>` (host user ids), `<REPO>` (folder name), `<PKG LIST>`
(apt packages from recon), mise tools from recon.

### `.devcontainer/Dockerfile`

```dockerfile
FROM ubuntu:24.04   # or debian:stable-slim / alpine if the project demands

ARG USERNAME=<USER>
ARG USER_UID=<UID>
ARG USER_GID=<GID>

ENV DEBIAN_FRONTEND=noninteractive

# System packages for the detected toolchain (compilers, -dev libs, CLIs).
RUN apt-get update \
    && apt-get install -y --no-install-recommends <PKG LIST> curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Non-root user matching host uid; bash is the default shell.
# ubuntu:24.04 ships a default 'ubuntu' user with uid/gid 1000 — remove it.
RUN set -eux; \
    if id -u ubuntu >/dev/null 2>&1; then userdel --remove ubuntu; fi; \
    groupadd --gid "$USER_GID" "$USERNAME"; \
    useradd --uid "$USER_UID" --gid "$USER_GID" -m -s /bin/bash "$USERNAME"

# mise (always): SHA-256-verified download as root, install as user.
RUN set -eux; \
    api="$(curl -fsSL https://api.github.com/repos/jdx/mise/releases/latest)"; \
    version="$(printf '%s' "$api" | grep -m1 '"tag_name"' | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')"; \
    expected="$(printf '%s' "$api" | grep -A40 '"name": "install.sh"' | grep '"digest"' \
               | head -n1 | sed -E 's/.*sha256:([0-9a-f]{64}).*/\1/')"; \
    curl -fsSL -o /tmp/mise-install.sh \
      "https://github.com/jdx/mise/releases/download/${version}/install.sh"; \
    if [ -n "$expected" ]; then \
      echo "${expected}  /tmp/mise-install.sh" | sha256sum -c -; \
    fi

# Tool layer baked into the image so rebuilds don't re-download tools.
# If the project HAS a mise config (mise.toml / .config/mise/config.toml /
# .tool-versions): COPY it to /opt/mise/config.toml.
# Otherwise write a minimal one from the detected stack, e.g.:
RUN mkdir -p /opt/mise && printf '%s\n' \
    '[tools]' \
    'opencode = "latest"' \
    'node = "lts"' \
    > /opt/mise/config.toml

# Env vars are scoped to these RUNs only; retry for transient GitHub errors.
USER "$USERNAME"
RUN HOME="/home/${USERNAME}" MISE_INSTALL_PATH="/home/${USERNAME}/.local/bin/mise" \
    bash /tmp/mise-install.sh
RUN set -eux; \
    ok=0; \
    for attempt in 1 2 3; do \
      if HOME="/home/${USERNAME}" MISE_GLOBAL_CONFIG_FILE=/opt/mise/config.toml \
         "/home/${USERNAME}/.local/bin/mise" install; then ok=1; break; fi; \
      echo "mise install attempt ${attempt} failed, retrying..."; \
      sleep 10; \
    done; \
    [ "$ok" = 1 ]

# Pre-create mount targets that will hold read-only file bind-mounts (docker
# needs an existing file target). Example for opencode auth:
RUN mkdir -p "/home/${USERNAME}/.local/share/opencode" \
    && touch "/home/${USERNAME}/.local/share/opencode/auth.json"

ENV PATH="/home/${USERNAME}/.local/bin:/home/${USERNAME}/.local/share/mise/shims:${PATH}"
```

mise is the tool-adding mechanism inside the sandbox: anything missing later
is `mise use -g <tool>`, not a rebuild. Only system-level (apt) packages need
an image rebuild.

### `.devcontainer/devcontainer.json`

```jsonc
{
  "name": "<project> sandbox",
  "build": { "dockerfile": "Dockerfile", "context": ".." },
  "remoteUser": "<USER>",
  "updateRemoteUserUID": false,
  "workspaceFolder": "/home/<USER>/<REPO>",
  "workspaceMount": "source=${localWorkspaceFolder},target=/home/<USER>/<REPO>,type=bind",
  "runArgs": [
    "--cap-drop=ALL",
    "--security-opt=no-new-privileges",
    "--init"
  ],
  "mounts": [
    "source=${localEnv:HOME}/.local/share/opencode/auth.json,target=/home/<USER>/.local/share/opencode/auth.json,type=bind,readonly"
  ],
  "remoteEnv": {
    "PATH": "/home/<USER>/.local/bin:/home/<USER>/.local/share/mise/shims:${containerEnv:PATH}",
    "GIT_AUTHOR_NAME": "${localEnv:GIT_AUTHOR_NAME}",
    "GIT_AUTHOR_EMAIL": "${localEnv:GIT_AUTHOR_EMAIL}",
    "OPENCODE_CONFIG": "/home/<USER>/<REPO>/.devcontainer/opencode.sandbox.jsonc"
  },
  "postCreateCommand": "bash .devcontainer/post-create.sh"
}
```

Every host secret is passed by explicit mapping only, e.g.
`"TOKEN": "${localEnv:TOKEN}"`. Add a comment above
`runArgs` stating the isolation model.

### `.devcontainer/post-create.sh`

Conventions: `set -e`, resolve own dir with
`DIR="$(dirname "$(readlink -f "$0")")"`, idempotent, no sudo.

```bash
#!/bin/bash
set -e
DIR="$(dirname "$(readlink -f "$0")")"
REPO_ROOT="$(dirname "$DIR")"

git config --global --add safe.directory "$REPO_ROOT"

# git identity for local commits (env override, sane fallback)
[ -n "$(git config --global user.name)" ] ||
  git config --global user.name "${GIT_AUTHOR_NAME:-$(id -un)}"
[ -n "$(git config --global user.email)" ] ||
  git config --global user.email "${GIT_AUTHOR_EMAIL:-$(id -un)@localhost}"

command -v mise >/dev/null 2>&1 && mise reshim

# Project bootstrap from recon — examples:
#   [ -f package-lock.json ] && npm ci
#   [ -f Cargo.toml ] && cargo fetch
#   [ -f Gemfile ] && bundle install
#   [ -f pyproject.toml ] && pip install -e .

# Sanity-check the harness
command -v opencode >/dev/null 2>&1 && opencode --version
```

### `.devcontainer/opencode.sandbox.jsonc`

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "permission": {
    "edit": "allow",
    "bash": "allow",
    "webfetch": "allow"
  }
}
```

## Gotchas (learned the hard way)

- `ubuntu:24.04` already contains user `ubuntu` with uid/gid 1000 → `userdel`
  before creating the sandbox user.
- BuildKit does **not** set `HOME` for `RUN` under a non-root `USER` → pass
  `HOME=/home/<USER>` explicitly on every user RUN.
- Running the mise installer as root creates root-owned `~/.local` → install
  as the container user (download/verify may stay root).
- File bind-mounts need the target to exist **as a file** — `touch` a
  placeholder in the image, or docker creates a directory and the mount fails.
- `--security-opt=no-new-privileges` breaks sudo by design → everything
  privileged (apt, user creation) happens at build time, never runtime.
- Transient GitHub network errors are common (git refs, attestation API) →
  wrap `mise install` in a retry loop.
- `MISE_GLOBAL_CONFIG_FILE` must be scoped to the build RUN only, or runtime
  mise will read the build-time config instead of the project one.
- Native builds inside the container fail on missing `-dev` libraries —
  that is what the apt list from recon is for.
- Docker build context = repo root → keep `.git`/`node_modules` out or accept
  a fat context.

## Verification checklist

1. Host: project tests/lint, `shellcheck .devcontainer/*.sh`, `bash -n`.
2. `docker build -f .devcontainer/Dockerfile -t <project>-sandbox .`
3. Run post-create in a container with the exact devcontainer runArgs and
   mounts (repo + read-only auth), then assert: `opencode --version` works,
   detected toolchain works (`node -v` / `go version` / ...), project tests
   pass **inside**.
4. Negative tests inside the container:
   - writing to the read-only credential mount fails (`Read-only file system`);
   - `git push --dry-run` fails (no ssh keys);
   - `/var/run/docker.sock` does not exist.
5. Launch: VS Code "Reopen in Container" or
   `npx @devcontainers/cli up --workspace-folder <repo>`.
