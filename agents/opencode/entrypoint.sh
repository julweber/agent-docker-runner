#!/usr/bin/env bash
set -euo pipefail

# Running as root here so we can read the host-mounted config directory
# regardless of its ownership on the host. We copy it into the node home,
# hand ownership to the node user, then drop privileges via gosu before
# executing any user-facing process.

# Copy read-only config mount into the node XDG config directory.
if [[ -d /mnt/agent-config-ro ]]; then
  # Run the copy as the node user — the staged mount is world-readable so
  # node can read it, and node owns /home/node/.config/opencode so it can
  # write into it. This avoids needing CAP_CHOWN (dropped via --cap-drop ALL).
  gosu node cp -r /mnt/agent-config-ro/. /home/node/.config/opencode/
fi

# If AGENT_SHELL=1, drop into bash as the node user
if [[ "${AGENT_SHELL:-}" == "1" ]]; then
  exec gosu node bash
fi

# Build opencode argument list
OPENCODE_ARGS=()

if [[ -n "${AGENT_MODEL:-}" ]]; then
  OPENCODE_ARGS+=(-m "${AGENT_MODEL}")
fi

if [[ "${AGENT_HEADLESS:-}" == "1" ]]; then
  # Headless mode: use `opencode run` with the prompt as positional argument
  echo "## Running agent (headless) with parameters ##"
  echo "opencode run ${OPENCODE_ARGS[*]} ${AGENT_PROMPT}"
  exec gosu node opencode run "${OPENCODE_ARGS[@]}" "${AGENT_PROMPT}"
fi

# Interactive TUI mode
echo "## Running agent (TUI) with parameters ##"
echo "opencode ${OPENCODE_ARGS[*]}"
exec gosu node opencode "${OPENCODE_ARGS[@]}"
