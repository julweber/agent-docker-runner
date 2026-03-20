FROM node:lts-slim

# Install opencode globally (as root — goes into /usr/local/lib/node_modules)
RUN npm install -g opencode-ai

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

# Pre-create the XDG config and data directories owned by node so the
# entrypoint can copy the staged config into them as the node user.
# ~/.config/opencode  — opencode.json, MCP settings, tui.json, etc.
# ~/.local/share/opencode — session database, logs
RUN mkdir -p /home/node/.config/opencode \
 && mkdir -p /home/node/.local/share/opencode \
 && chown -R node:node /home/node/.config \
 && chown -R node:node /home/node/.local

# Copy entrypoint.
# The build context is agents/opencode/ (i.e. `docker build … agents/opencode/`),
# so entrypoint.sh must live at agents/opencode/entrypoint.sh on the host.
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Entrypoint runs as root so it can read the config mount and drop privileges.
# gosu node is used inside entrypoint.sh to switch to the node user.
ENV HOME=/home/node

WORKDIR /workspace

ENTRYPOINT ["/entrypoint.sh"]
