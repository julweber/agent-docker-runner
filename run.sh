#!/usr/bin/env bash
set -euo pipefail

INVOKE_DIR=$PWD

cd "$(cd "$(dirname "$0")" && pwd)"

KNOWN_AGENTS=("pi" "opencode" "claude")

WORKSPACE="$INVOKE_DIR"
CONFIG_DIR=""
CONFIG_FILE=""
PROMPT=""
HEADLESS=0
SHELL_MODE=0
TAG="latest"
AGENT=""
MODEL=""

usage() {
  cat <<EOF
Usage: ./run.sh [OPTIONS] <agent>

Arguments:
  agent                   Agent to run. Currently supported: pi, opencode, claude

Options:
  -w, --workspace DIR     Host directory mounted as /workspace inside the
                          container. Defaults to current working directory.
  -c, --config DIR        Path to config directory for the agent.
                          Defaults to the agent's native config home:
                            pi:       ~/.pi/
                            opencode: ~/.config/opencode/
                            claude:   ~/.claude/
                          Mounted read-only to a staging path and copied into
                          the agent's config directory at container startup.
                          Must exist on the host.
      --config-file FILE  Path to a .claude.json file that is copied to
                          ~/.claude.json inside the container.  Pre-approves the
                          API key so Claude Code does not prompt on startup.
                          Defaults to ~/.claude.json on the host.
                          Only accepted for the claude agent.
      --prompt TEXT       Prompt to pass to the agent. Implies --headless.
      --headless          Run in headless / non-interactive mode (no TUI).
                          Requires --prompt. Implied by --prompt.
      --shell             Drop into bash instead of running the agent (debug).
      --tag TAG           Docker image tag to use. Default: latest.
      --model MODEL       Model to use.
                          For pi, use "provider/model" to also select the
                          provider (e.g. anthropic/claude-sonnet-4). The part
                          before the first "/" is the provider; everything after
                          is the model ID (e.g. evo/qwen/qwen3-coder-next).
                          opencode: "provider/model" format (e.g. anthropic/claude-sonnet-4).
                          claude:   alias (e.g. sonnet, opus) or full name (e.g. claude-sonnet-4-6).
  -h, --help              Show this help text.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -w|--workspace)
      WORKSPACE="$2"
      shift 2
      ;;
    -c|--config)
      CONFIG_DIR="$2"
      shift 2
      ;;
    --config-file)
      CONFIG_FILE="$2"
      shift 2
      ;;
    --prompt)
      PROMPT="$2"
      shift 2
      ;;
    --headless)
      HEADLESS=1
      shift
      ;;
    --shell)
      SHELL_MODE=1
      shift
      ;;
    --tag)
      TAG="$2"
      shift 2
      ;;
    --model)
      MODEL="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    -*)
      echo "Error: Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      if [[ -n "$AGENT" ]]; then
        echo "Error: Unexpected argument: $1" >&2
        usage >&2
        exit 1
      fi
      AGENT="$1"
      shift
      ;;
  esac
done

# Validate agent
if [[ -z "$AGENT" ]]; then
  echo "Error: agent argument is required." >&2
  usage >&2
  exit 1
fi

VALID=0
for a in "${KNOWN_AGENTS[@]}"; do
  if [[ "$a" == "$AGENT" ]]; then
    VALID=1
    break
  fi
done

if [[ $VALID -eq 0 ]]; then
  echo "Error: Unknown agent '$AGENT'. Supported agents: ${KNOWN_AGENTS[*]}" >&2
  exit 1
fi

# Validate workspace
if [[ ! -d "$WORKSPACE" ]]; then
  echo "Error: workspace directory does not exist: $WORKSPACE" >&2
  exit 1
fi

# Default config directory per agent (matches the agent's native config home)
if [[ -z "$CONFIG_DIR" ]]; then
  case "$AGENT" in
    pi)       CONFIG_DIR="$HOME/.pi" ;;
    opencode) CONFIG_DIR="$HOME/.config/opencode" ;;
    claude)   CONFIG_DIR="$HOME/.claude" ;;
  esac
fi

if [[ ! -d "$CONFIG_DIR" ]]; then
  echo "Error: config directory does not exist: $CONFIG_DIR" >&2
  echo "       Pass -c to specify a different location, or create the directory." >&2
  exit 1
fi

# Validate / resolve --config-file (claude only)
if [[ -n "$CONFIG_FILE" && "$AGENT" != "claude" ]]; then
  echo "Error: --config-file is only supported for the 'claude' agent." >&2
  exit 1
fi

if [[ -n "$CONFIG_FILE" && ! -f "$CONFIG_FILE" ]]; then
  echo "Error: config file does not exist: $CONFIG_FILE" >&2
  exit 1
fi

# Default to ~/.claude.json when --config-file is not given
if [[ "$AGENT" == "claude" && -z "$CONFIG_FILE" ]]; then
  CONFIG_FILE="$HOME/.claude.json"
  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: $CONFIG_FILE not found." >&2
    echo "       Claude Code stores this file at ~/.claude.json." >&2
    echo "       See config-examples/claude/.claude.json.example." >&2
    echo "       You can also pass --config-file to point to a different location." >&2
    exit 1
  fi
fi

# --prompt implies --headless
if [[ -n "$PROMPT" ]]; then
  HEADLESS=1
fi

if [[ $HEADLESS -eq 1 && -z "$PROMPT" ]]; then
  echo "Error: --headless requires --prompt." >&2
  exit 1
fi

# For the pi agent, split "provider/model" on the first "/" into separate
# AGENT_PROVIDER and AGENT_MODEL env vars (pi expects them separately).
# e.g. "evo/qwen/qwen3-coder-next" -> provider="evo", model="qwen/qwen3-coder-next"
PROVIDER=""
if [[ "$AGENT" == "pi" && -n "$MODEL" && "$MODEL" == */* ]]; then
  PROVIDER="${MODEL%%/*}"
  MODEL="${MODEL#*/}"
fi

# Validate shell and headless/prompt mutual exclusion
if [[ $SHELL_MODE -eq 1 && ($HEADLESS -eq 1 || -n "$PROMPT") ]]; then
  echo "Error: --shell and --headless/--prompt are mutually exclusive." >&2
  exit 1
fi

# Validate docker image exists
IMAGE="coding-agent/$AGENT:$TAG"
if ! docker image inspect "$IMAGE" > /dev/null 2>&1; then
  echo "Error: Docker image '$IMAGE' not found locally." >&2
  echo "Build it first with: ./build.sh $AGENT" >&2
  exit 1
fi

# Resolve absolute paths
WORKSPACE=$(cd "$WORKSPACE" && pwd)
CONFIG_DIR=$(cd "$CONFIG_DIR" && pwd)
if [[ -n "$CONFIG_FILE" ]]; then
  CONFIG_FILE=$(cd "$(dirname "$CONFIG_FILE")" && pwd)/$(basename "$CONFIG_FILE")
fi

# Stage the config into a world-readable temp directory so the container's
# root process (which has --cap-drop ALL, hence no CAP_DAC_OVERRIDE) can read
# it regardless of the host directory's ownership or permissions.
STAGED_CONFIG=$(mktemp -d)
trap 'rm -rf "$STAGED_CONFIG"' EXIT
cp -r "$CONFIG_DIR/." "$STAGED_CONFIG/"
chmod -R a+rX "$STAGED_CONFIG"

# Stage .claude.json separately (claude agent only)
STAGED_CLAUDE_JSON=""
if [[ -n "$CONFIG_FILE" ]]; then
  STAGED_CLAUDE_JSON=$(mktemp -d)
  trap 'rm -rf "$STAGED_CONFIG" "$STAGED_CLAUDE_JSON"' EXIT
  cp "$CONFIG_FILE" "$STAGED_CLAUDE_JSON/.claude.json"
  chmod a+r "$STAGED_CLAUDE_JSON/.claude.json"
fi

# Determine TTY flags
if [[ $HEADLESS -eq 1 ]]; then
  TTY_FLAGS=()
else
  TTY_FLAGS=(-i -t)
fi

# Build docker run command
CMD=(docker run --rm)
CMD+=("${TTY_FLAGS[@]}")
CMD+=(--cap-drop ALL)
CMD+=(--cap-add SETUID)
CMD+=(--cap-add SETGID)
CMD+=(--security-opt no-new-privileges)
CMD+=(--network bridge)
CMD+=(--add-host=host.docker.internal:host-gateway)
CMD+=(-v "$WORKSPACE:/workspace")
CMD+=(-v "$STAGED_CONFIG:/mnt/agent-config-ro:ro")

if [[ -n "$STAGED_CLAUDE_JSON" ]]; then
  CMD+=(-v "$STAGED_CLAUDE_JSON/.claude.json:/mnt/claude-json-ro/.claude.json:ro")
fi

if [[ $SHELL_MODE -eq 1 ]]; then
  CMD+=(--env AGENT_SHELL=1)
fi

if [[ $HEADLESS -eq 1 ]]; then
  CMD+=(--env AGENT_HEADLESS=1)
fi

if [[ -n "$PROMPT" ]]; then
  CMD+=(--env "AGENT_PROMPT=$PROMPT")
fi

if [[ -n "$PROVIDER" ]]; then
  CMD+=(--env "AGENT_PROVIDER=$PROVIDER")
fi

if [[ -n "$MODEL" ]]; then
  CMD+=(--env "AGENT_MODEL=$MODEL")
fi

CMD+=("$IMAGE")

echo "## Starting docker container with command ##"
echo "${CMD[@]}"

exec "${CMD[@]}"
