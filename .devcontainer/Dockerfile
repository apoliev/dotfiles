# Sandbox image for the dotfiles repo. Mirrors scripts/ubuntu.sh — apt
# packages from libs.list, SHA-256-verified mise — but every privileged step
# happens at build time: the runtime user has no sudo and the container is
# started with --cap-drop=ALL / no-new-privileges (see devcontainer.json).

FROM ubuntu:24.04

ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=1000

ENV DEBIAN_FRONTEND=noninteractive

# System packages: exactly the host list from libs.list.
COPY libs.list /tmp/libs.list
RUN apt-get update \
    && xargs -a /tmp/libs.list apt-get install -y \
    && rm -rf /var/lib/apt/lists/*

# Non-root user; uid 1000 matches the host user so the bind-mounted repo
# stays writable without extra capabilities. ubuntu:24.04 ships a default
# 'ubuntu' user with uid/gid 1000 — remove it first.
RUN set -eux; \
    if id -u ubuntu >/dev/null 2>&1; then userdel --remove ubuntu; fi; \
    groupadd --gid "$USER_GID" "$USERNAME"; \
    useradd --uid "$USER_UID" --gid "$USER_GID" -m -s /usr/bin/zsh "$USERNAME"

# mise binary: same download + checksum flow as install_mise() in
# scripts/ubuntu.sh. Download and verification happen as root; the install
# itself runs as the user so ~/.local stays user-owned.
RUN set -eux; \
    api="$(curl -fsSL https://api.github.com/repos/jdx/mise/releases/latest)"; \
    version="$(printf '%s' "$api" | grep -m1 '"tag_name"' | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')"; \
    expected="$(printf '%s' "$api" | grep -A40 '"name": "install.sh"' | grep '"digest"' \
               | head -n1 | sed -E 's/.*sha256:([0-9a-f]{64}).*/\1/')"; \
    curl -fsSL -o /tmp/mise-install.sh \
      "https://github.com/jdx/mise/releases/download/${version}/install.sh"; \
    if [ -n "$expected" ]; then \
      echo "${expected}  /tmp/mise-install.sh" | sha256sum -c -; \
    else \
      echo "WARNING: no mise installer digest found — skipping verification"; \
    fi

# mise tools (opencode, node, python, ...) baked into the image layer. The
# repo's config is read from /opt so ~/.config stays clean for stow; the
# env vars are scoped to these RUNs only — at runtime mise uses the stowed
# config.
COPY .config/mise/config.toml /opt/mise/config.toml
USER "$USERNAME"
RUN HOME="/home/${USERNAME}" MISE_INSTALL_PATH="/home/${USERNAME}/.local/bin/mise" \
    bash /tmp/mise-install.sh
# Tool downloads occasionally fail on transient GitHub errors — retry.
RUN set -eux; \
    ok=0; \
    for attempt in 1 2 3; do \
      if HOME="/home/${USERNAME}" MISE_GLOBAL_CONFIG_FILE=/opt/mise/config.toml \
         "/home/${USERNAME}/.local/bin/mise" install; then ok=1; break; fi; \
      echo "mise install attempt ${attempt} failed, retrying..."; \
      sleep 10; \
    done; \
    [ "$ok" = 1 ]

# Mount target for the read-only opencode auth file (see devcontainer.json):
# must exist at container start, and must be a file, not a dir.
RUN mkdir -p "/home/${USERNAME}/.local/share/opencode" \
    && touch "/home/${USERNAME}/.local/share/opencode/auth.json"

ENV PATH="/home/${USERNAME}/.local/bin:/home/${USERNAME}/.local/share/mise/shims:${PATH}"
