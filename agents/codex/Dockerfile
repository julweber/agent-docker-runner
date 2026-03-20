FROM node:lts-slim

# Install Codex CLI globally (npm package ships a prebuilt Rust binary)
RUN npm install -g @openai/codex

# Install gosu for clean privilege dropping in the entrypoint,
# plus common standard tools: curl, wget, jq, python3, pip, uv, yq
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      gosu \
      curl \
      wget \
      git \
      jq \
      shellcheck \
      python3 \
      python3-pip \
      python3-venv \
 && pip3 install --break-system-packages uv \
 && curl -fsSL https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 \
      -o /usr/local/bin/yq \
 && chmod +x /usr/local/bin/yq \
 && rm -rf /var/lib/apt/lists/*

# Prepare workspace directory (mount point)
RUN mkdir -p /workspace && chown node:node /workspace

# Pre-create ~/.codex owned by node so the entrypoint can copy config into it
# as the node user (no chown needed, no CAP_CHOWN).
# ~/.codex holds config.toml, auth.json, and other Codex state.
RUN mkdir -p /home/node/.codex && chown node:node /home/node/.codex

# Copy entrypoint.
# The build context is agents/codex/ (i.e. `docker build … agents/codex/`), so
# entrypoint.sh must live at agents/codex/entrypoint.sh on the host.
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Entrypoint runs as root so it can read the config mount and drop privileges.
# gosu node is used inside entrypoint.sh to switch to the node user.
ENV HOME=/home/node

WORKDIR /workspace

ENTRYPOINT ["/entrypoint.sh"]
