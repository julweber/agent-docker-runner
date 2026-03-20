FROM node:lts-slim

# Install gosu for clean privilege dropping in the entrypoint,
# plus common standard tools: curl, wget, jq, python3, pip, uv, yq
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      gosu \
      curl \
      wget \
      git \
      jq \
      python3 \
      python3-pip \
      python3-venv \
 && pip3 install --break-system-packages uv \
 && curl -fsSL https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 \
      -o /usr/local/bin/yq \
 && chmod +x /usr/local/bin/yq \
 && rm -rf /var/lib/apt/lists/*

# Prepare workspace and config directories owned by node
RUN mkdir -p /workspace && chown node:node /workspace
RUN mkdir -p /home/node/.claude && chown -R node:node /home/node/.claude

# Install Claude Code as the node user so all files (binary + supporting data)
# land in /home/node/.local/ where the install script expects them.
USER node
RUN curl -fsSL https://claude.ai/install.sh | bash
USER root

# Add the node user's local bin to PATH so gosu node can find the claude binary.
ENV PATH="/home/node/.local/bin:$PATH"

# Copy entrypoint.
# The build context is agents/claude/ (i.e. `docker build … agents/claude/`), so
# entrypoint.sh must live at agents/claude/entrypoint.sh on the host.
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Entrypoint runs as root so it can read the config mount and drop privileges.
# gosu node is used inside entrypoint.sh to switch to the node user.
ENV HOME=/home/node

WORKDIR /workspace

ENTRYPOINT ["/entrypoint.sh"]
