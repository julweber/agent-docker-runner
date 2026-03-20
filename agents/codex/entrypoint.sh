#!/usr/bin/env bash
set -euo pipefail

# Running as root here so we can read the host-mounted config directory
# regardless of its ownership on the host. We copy it into the node home,
# hand ownership to the node user, then drop privileges via gosu before
# executing any user-facing process.

# Copy read-only config mount into ~/.codex/
# This handles config.toml, auth.json, AGENTS.md, and any other Codex config.
if [[ -d /mnt/agent-config-ro ]]; then
  # Run the copy as the node user — the staged mount is world-readable so
  # node can read it, and node owns /home/node/.codex so it can write into it.
  # This avoids needing CAP_CHOWN (dropped via --cap-drop ALL).
  gosu node cp -r /mnt/agent-config-ro/. /home/node/.codex/
fi

# If AGENT_SHELL=1, drop into bash as the node user
if [[ "${AGENT_SHELL:-}" == "1" ]]; then
  exec gosu node bash
fi

# ── Sandbox & approval defaults ──────────────────────────────────────────────
# The Docker container is the sandbox, so we default to danger-full-access and
# never-ask-for-approval. Both can be overridden via environment variables.
SANDBOX="${AGENT_SANDBOX:-danger-full-access}"
APPROVAL="${AGENT_APPROVAL:-never}"

# ── Build argument list ───────────────────────────────────────────────────────
CODEX_ARGS=(
  --sandbox "${SANDBOX}"
  --ask-for-approval "${APPROVAL}"
)

if [[ -n "${AGENT_MODEL:-}" ]]; then
  CODEX_ARGS+=(--model "${AGENT_MODEL}")
fi

# ── Headless / non-interactive mode ──────────────────────────────────────────
# `codex exec` streams progress to stderr and writes only the final agent
# message to stdout. CODEX_API_KEY is the recommended auth mechanism for exec.
# Pass it (and OPENAI_API_KEY as fallback) via `docker run -e CODEX_API_KEY=…`.
# gosu preserves the calling environment, so any -e flags flow through as-is.
if [[ "${AGENT_HEADLESS:-}" == "1" ]]; then
  # Workspace may not be a git repo; skip the check that would otherwise abort.
  # This flag is only valid for `codex exec`, not the TUI.
  CODEX_ARGS+=(--skip-git-repo-check)
  echo "## Running codex (headless) with parameters ##"
  echo "codex exec ${CODEX_ARGS[*]} <prompt>"
  exec gosu node codex exec "${CODEX_ARGS[@]}" "${AGENT_PROMPT}"
fi

# ── Interactive TUI mode ──────────────────────────────────────────────────────
# In interactive mode OPENAI_API_KEY or a stored auth.json is used for auth.
echo "## Running codex (TUI) with parameters ##"
echo "codex ${CODEX_ARGS[*]}"
exec gosu node codex "${CODEX_ARGS[@]}"
