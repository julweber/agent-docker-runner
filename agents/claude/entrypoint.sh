#!/usr/bin/env bash
set -euo pipefail

# Running as root here so we can read the host-mounted config directory
# regardless of its ownership on the host. We copy it into the node home,
# hand ownership to the node user, then drop privileges via gosu before
# executing any user-facing process.

# Copy read-only config mount into ~/.claude/
if [[ -d /mnt/agent-config-ro ]]; then
  # Run the copy as the node user — the staged mount is world-readable so
  # node can read it, and node owns /home/node/.claude so it can write into it.
  # This avoids needing CAP_CHOWN (dropped via --cap-drop ALL).
  gosu node cp -r /mnt/agent-config-ro/. /home/node/.claude/
fi

# Copy ~/.claude.json (global Claude Code config, distinct from ~/.claude/).
# This file pre-approves the API key so Claude Code does not interactively
# prompt "Do you want to use this API key?" on startup.
if [[ -f /mnt/claude-json-ro/.claude.json ]]; then
  gosu node cp /mnt/claude-json-ro/.claude.json /home/node/.claude.json
fi

# If AGENT_SHELL=1, drop into bash as the node user
if [[ "${AGENT_SHELL:-}" == "1" ]]; then
  exec gosu node bash
fi

# Build claude argument list.
# --dangerously-skip-permissions is always set: the container is the sandbox.
CLAUDE_ARGS=(--dangerously-skip-permissions)

if [[ -n "${AGENT_MODEL:-}" ]]; then
  CLAUDE_ARGS+=(--model "${AGENT_MODEL}")
fi

if [[ "${AGENT_HEADLESS:-}" == "1" ]]; then
  CLAUDE_ARGS+=(--print)
  echo "## Running claude (headless) with parameters ##"
  echo "claude ${CLAUDE_ARGS[*]} ${AGENT_PROMPT}"
  exec gosu node claude "${CLAUDE_ARGS[@]}" "${AGENT_PROMPT}"
fi

# Interactive TUI mode
echo "## Running claude (TUI) with parameters ##"
echo "claude ${CLAUDE_ARGS[*]}"
exec gosu node claude "${CLAUDE_ARGS[@]}"
