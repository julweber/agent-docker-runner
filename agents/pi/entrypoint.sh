#!/usr/bin/env bash
set -euo pipefail

# Running as root here so we can read the host-mounted config directory
# regardless of its ownership on the host. We copy it into the node home,
# hand ownership to the node user, then drop privileges via gosu before
# executing any user-facing process.

# Copy read-only config mount into the node home directory.
if [[ -d /mnt/agent-config-ro ]]; then
  # Run the copy as the node user — the staged mount is world-readable so
  # node can read it, and node owns /home/node/.pi so it can write into it.
  # This avoids needing CAP_CHOWN (dropped via --cap-drop ALL).
  gosu node cp -r /mnt/agent-config-ro/. /home/node/.pi/
fi

# If AGENT_SHELL=1, drop into bash as the node user
if [[ "${AGENT_SHELL:-}" == "1" ]]; then
  exec gosu node bash
fi

# Build pi argument list
# use no-session for now
  # TODO: support session persistence later
PI_ARGS=("--no-session")

if [[ -n "${AGENT_PROVIDER:-}" ]]; then
  PI_ARGS+=(--provider "${AGENT_PROVIDER}")
fi

if [[ -n "${AGENT_MODEL:-}" ]]; then
  PI_ARGS+=(--model "${AGENT_MODEL}")
fi

if [[ "${AGENT_HEADLESS:-}" == "1" ]]; then
  PI_ARGS+=(--print)
  PI_ARGS+=("${AGENT_PROMPT}")
fi

echo "## Running agent with parameters ##"
echo "pi ${PI_ARGS[*]}"
exec gosu node pi "${PI_ARGS[@]}"
