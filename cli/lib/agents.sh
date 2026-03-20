# shellcheck shell=bash

declare -r KNOWN_AGENTS=("pi" "opencode" "claude" "codex")

is_known_agent() {
    local agent="$1"
    local known=""

    for known in "${KNOWN_AGENTS[@]}"; do
        [[ "$agent" == "$known" ]] && return 0
    done

    return 1
}
