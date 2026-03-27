# shellcheck shell=bash

show_build_help() {
    cat <<'EOF'
Usage: adr build [options] [<agent>]

Build Docker image(s) for an agent.

Options:
  --tag TAG       Use a custom tag instead of 'latest'
  --no-cache      Build without using cached layers
  --yes           Skip confirmation prompt (for CI/CD)
  -h, --help      Show this help message

If no <agent> is specified, prompts to build all agents.
EOF
}

cmd_build_help() {
    show_build_help
}

cmd_build_all() {
    local tag="$1"
    local no_cache="$2"
    local yes_flag="$3"
    local response=""
    local success_count=0
    local fail_count=0
    local agent=""

    echo "Known agents: ${KNOWN_AGENTS[*]}"

    if [[ "$yes_flag" == true ]]; then
        response="y"
    else
        read -r -p "Build all agents? [y/N] " response
    fi

    case "$response" in
        [Yy]*)
            for agent in "${KNOWN_AGENTS[@]}"; do
                echo ""
                echo "--- Building $agent ---"
                if build_agent_image "$agent" "$tag" "$no_cache"; then
                    ((success_count++)) || true
                else
                    ((fail_count++)) || true
                fi
            done

            echo ""
            echo "Build summary: $success_count succeeded, $fail_count failed."
            if [[ $fail_count -gt 0 ]]; then
                return 1
            else
                return 0
            fi
            ;;
        *)
            echo "Cancelled."
            ;;
    esac
}

cmd_build() {
    local tag=""
    local no_cache=false
    local yes_flag=false
    local agent=""
    local tag_provided=false

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --tag)
                if [[ $# -lt 2 ]]; then
                    echo "Error: --tag requires a value" >&2
                    exit 1
                fi
                tag="$2"
                tag_provided=true
                shift 2
                ;;
            --no-cache)
                no_cache=true
                shift
                ;;
            --yes)
                yes_flag=true
                shift
                ;;
            --help|-h)
                cmd_build_help
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

    if [[ "$tag_provided" == true ]]; then
        if [[ -z "$tag" || ! "$tag" =~ [^[:space:]] ]]; then
            echo "Error: --tag requires a non-empty value" >&2
            exit 1
        fi
    fi

    local effective_tag="${tag:-$ADR_TAG}"

    if [[ -z "$agent" ]]; then
        cmd_build_all "$effective_tag" "$no_cache" "$yes_flag"
        return $?
    fi

    if ! is_known_agent "$agent"; then
        echo "Error: Unknown agent '$agent'. Supported agents: ${KNOWN_AGENTS[*]}" >&2
        exit 1
    fi

    build_agent_image "$agent" "$effective_tag" "$no_cache"
}
