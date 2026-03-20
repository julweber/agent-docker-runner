# shellcheck shell=bash

show_update_help() {
    cat <<'EOF'
Usage: adr update [options] [<agent>]

Rebuild image(s), pulling the latest agent version.

Options:
  --no-cache      Rebuild with fresh layers (default behavior)

If no <agent> is specified, rebuilds all images that are already present locally.
EOF
}

cmd_update_help() {
    show_update_help
}

cmd_update_single() {
    local agent="$1"
    local tag="$2"

    build_agent_image "$agent" "$tag" true
}

cmd_update_all() {
    local rebuilt_count=0
    local skipped_count=0
    local tag="${ADR_TAG:-latest}"
    local agent=""

    echo "Discovering locally built agent images..."

    for agent in "${KNOWN_AGENTS[@]}"; do
        if image_exists "$agent" "$tag"; then
            echo ""
            echo "--- Updating $agent ---"
            if cmd_update_single "$agent" "$tag"; then
                ((rebuilt_count++)) || true
            else
                echo "Warning: Failed to update $agent, continuing with other agents." >&2
            fi
        else
            echo "Skipping $agent (not built)"
            ((skipped_count++)) || true
        fi
    done

    echo ""
    if [[ $rebuilt_count -eq 0 && $skipped_count -gt 0 ]]; then
        echo "No images to update. Run 'adr build <agent>' to build an image first."
    else
        echo "Update summary: $rebuilt_count rebuilt, $skipped_count skipped."
    fi
}

cmd_update() {
    local tag="${ADR_TAG:-latest}"
    local agent=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --no-cache)
                shift
                ;;
            --help|-h)
                cmd_update_help
                exit 0
                ;;
            -*)
                echo "Error: Unknown option '$1'" >&2
                exit 1
                ;;
            *)
                agent="$1"
                shift
                ;;
        esac
    done

    if [[ -z "$agent" ]]; then
        cmd_update_all
    else
        if ! is_known_agent "$agent"; then
            echo "Error: Unknown agent '$agent'. Supported agents: ${KNOWN_AGENTS[*]}" >&2
            exit 1
        fi

        cmd_update_single "$agent" "$tag"
    fi
}
