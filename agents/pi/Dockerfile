FROM node:lts-slim

# Install pi globally (as root — goes into /usr/local/lib/node_modules)
RUN npm install -g @mariozechner/pi-coding-agent

# make node modules writable (fix for pi mcp extension)
RUN chown -R node:node /usr/local/lib/node_modules && chown -R node:node /usr/local/bin

# Install gosu for clean privilege dropping in the entrypoint,
# plus common standard tools: curl, wget, jq, python3, pip, uv, yq
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      gosu \
      curl \
      wget \
      jq \
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

# Pre-create the config directory owned by node so the entrypoint can copy
# the staged config into it as the node user (no chown needed, no CAP_CHOWN).
RUN mkdir -p /home/node/.pi && chown node:node /home/node/.pi

# Copy entrypoint.
# The build context is agents/pi/ (i.e. `docker build … agents/pi/`), so
# entrypoint.sh must live at agents/pi/entrypoint.sh on the host — COPY
# resolves relative to that context directory, not the repo root.
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Entrypoint runs as root so it can read the config mount and drop privileges.
# gosu node is used inside entrypoint.sh to switch to the node user.
ENV HOME=/home/node

WORKDIR /workspace

ENTRYPOINT ["/entrypoint.sh"]
