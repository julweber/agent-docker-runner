#!/usr/bin/env bash
set -euo pipefail

cd "$(cd "$(dirname "$0")" && pwd)"

KNOWN_AGENTS=("pi" "opencode" "claude")

TAG="latest"
NO_CACHE=""
AGENT=""

usage() {
  cat <<EOF
Usage: ./build.sh [OPTIONS] <agent>

Arguments:
  agent                   Agent to build. Currently supported: pi, opencode

Options:
      --tag TAG           Docker image tag to apply. Default: latest.
                          Example: --tag 1.2.3 -> builds coding-agent/pi:1.2.3
      --no-cache          Pass --no-cache to docker build.
  -h, --help              Show this help text.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --tag)
      TAG="$2"
      shift 2
      ;;
    --no-cache)
      NO_CACHE="--no-cache"
      shift
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

CMD=(docker build)
[[ -n "$NO_CACHE" ]] && CMD+=(--no-cache)
CMD+=(-t "coding-agent/$AGENT:$TAG")
CMD+=("agents/$AGENT/")

exec "${CMD[@]}"
