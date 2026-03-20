# shellcheck shell=bash

show_run_help() {
    cat <<'EOF'
Usage: adr run [options] [<agent>]

Run an agent in an isolated container.

Options:
  --workspace DIR   Host directory mounted as /workspace (default: $PWD)
  --config DIR      Override the agent's config directory. If not specified,
                    uses default config locations per agent:
                      pi:       ~/.pi/
                      opencode: ~/.config/opencode/
                      claude:   ~/.claude/
                      codex:    ~/.codex/
  --config-file FILE    Claude only: path to .claude.json
                        Defaults to ~/.claude.json on the host.
  --prompt TEXT     One-shot prompt; implies --headless
  --headless        Non-interactive mode; requires --prompt
  --shell           Drop into bash inside the container for debugging
  --tag TAG         Use a pinned image tag instead of 'latest'
  --model MODEL     Override the model at runtime

If no <agent> is specified, uses ADR_AGENT from .adr file or global config.
EOF
}

cmd_run_help() {
    show_run_help
}

default_config_dir_for_agent() {
    local agent="$1"

    case "$agent" in
        pi) echo "$HOME/.pi" ;;
        opencode) echo "$HOME/.config/opencode" ;;
        claude) echo "$HOME/.claude" ;;
        codex) echo "$HOME/.codex" ;;
    esac
}

run_agent() {
    local agent="$1"
    local tag="$2"
    local workspace="$3"
    local config_dir="$4"
    local claude_config_file="$5"
    local prompt="$6"
    local headless="$7"
    local shell_mode="$8"
    local model_override="$9"
    local CMD=(docker run --rm)
    local STAGED_CONFIG=""
    local STAGED_CLAUDE_JSON=""
    local PROVIDER=""
    local image_name="coding-agent/${agent}:${tag}"

    if [[ -n "$config_dir" ]]; then
        config_dir=$(cd "$config_dir" && pwd)

        if [[ ! -d "$config_dir" ]]; then
            echo "Error: config directory does not exist: $config_dir" >&2
            exit 1
        fi
    fi

    if [[ "$headless" != true ]]; then
        CMD+=(-i -t)
    fi

    CMD+=(--cap-drop ALL)
    CMD+=(--cap-add SETUID)
    CMD+=(--cap-add SETGID)
    CMD+=(--security-opt no-new-privileges)
    CMD+=(--network bridge)
    CMD+=(--add-host=host.docker.internal:host-gateway)
    CMD+=(-v "${workspace}:/workspace")

    STAGED_CONFIG=$(mktemp -d)
    trap 'rm -rf "$STAGED_CONFIG"' EXIT

    if [[ -n "$config_dir" ]]; then
        cp -r "${config_dir}/." "$STAGED_CONFIG/"
        chmod -R a+rX "$STAGED_CONFIG"
        CMD+=(-v "${STAGED_CONFIG}:/mnt/agent-config-ro:ro")
    fi

    if [[ -n "$claude_config_file" ]]; then
        STAGED_CLAUDE_JSON=$(mktemp -d)
        trap 'rm -rf "$STAGED_CONFIG" "$STAGED_CLAUDE_JSON"' EXIT
        cp "$claude_config_file" "$STAGED_CLAUDE_JSON/.claude.json"
        chmod a+r "$STAGED_CLAUDE_JSON/.claude.json"
        CMD+=(-v "${STAGED_CLAUDE_JSON}/.claude.json:/mnt/claude-json-ro/.claude.json:ro")
    fi

    if [[ "$shell_mode" == true ]]; then
        CMD+=(--env AGENT_SHELL=1)
    fi

    if [[ "$headless" == true ]]; then
        CMD+=(--env AGENT_HEADLESS=1)
    fi

    if [[ "$agent" == "pi" && -n "$model_override" && "$model_override" == */* ]]; then
        PROVIDER="${model_override%%/*}"
        model_override="${model_override#*/}"
    fi

    if [[ -n "$PROVIDER" ]]; then
        CMD+=(--env "AGENT_PROVIDER=$PROVIDER")
    fi

    if [[ -n "$model_override" ]]; then
        CMD+=(--env "AGENT_MODEL=$model_override")
    fi

    if [[ -n "$prompt" ]]; then
        CMD+=(--env "AGENT_PROMPT=$prompt")
    fi

    if [[ "$agent" == "codex" ]]; then
        [[ -n "${CODEX_API_KEY:-}" ]] && CMD+=(--env "CODEX_API_KEY=$CODEX_API_KEY")
        [[ -n "${OPENAI_API_KEY:-}" ]] && CMD+=(--env "OPENAI_API_KEY=$OPENAI_API_KEY")
    fi

    CMD+=("$image_name")

    echo "## Starting docker container with command ##"
    echo "${CMD[@]}"
    exec "${CMD[@]}"
}

cmd_run() {
    local workspace="$PWD"
    local config_dir=""
    local claude_config_file=""
    local prompt=""
    local headless=false
    local shell_mode=false
    local tag="${ADR_TAG:-latest}"
    local model_override=""
    local agent=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --workspace|-w)
                if [[ $# -lt 2 ]]; then
                    echo "Error: --workspace requires a value" >&2
                    exit 1
                fi
                workspace=$(realpath -m "$2" | sed 's|/$||')
                shift 2
                ;;
            --config|-c)
                if [[ $# -lt 2 ]]; then
                    echo "Error: --config requires a value" >&2
                    exit 1
                fi
                config_dir="$2"
                shift 2
                ;;
            --config-file)
                if [[ $# -lt 2 ]]; then
                    echo "Error: --config-file requires a value" >&2
                    exit 1
                fi
                claude_config_file="$2"
                shift 2
                ;;
            --prompt)
                if [[ $# -lt 2 ]]; then
                    echo "Error: --prompt requires a value" >&2
                    exit 1
                fi
                prompt="$2"
                headless=true
                shift 2
                ;;
            --headless)
                headless=true
                shift
                ;;
            --shell)
                shell_mode=true
                shift
                ;;
            --tag)
                if [[ $# -lt 2 ]]; then
                    echo "Error: --tag requires a value" >&2
                    exit 1
                fi
                tag="$2"
                shift 2
                ;;
            --model)
                if [[ $# -lt 2 ]]; then
                    echo "Error: --model requires a value" >&2
                    exit 1
                fi
                model_override="$2"
                shift 2
                ;;
            --help|-h)
                cmd_run_help
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

    if [[ "$headless" == true && -z "$prompt" ]]; then
        echo "Error: --headless requires --prompt" >&2
        exit 1
    fi

    if [[ "$shell_mode" == true && ("$headless" == true || -n "$prompt") ]]; then
        echo "Error: --shell and --headless/--prompt are mutually exclusive" >&2
        exit 1
    fi

    if [[ -n "$claude_config_file" && "$agent" != "claude" ]]; then
        echo "Error: --config-file is only supported for the 'claude' agent" >&2
        exit 1
    fi

    if [[ -n "$claude_config_file" && ! -f "$claude_config_file" ]]; then
        echo "Error: config file does not exist: $claude_config_file" >&2
        exit 1
    fi

    if [[ -z "$agent" ]]; then
        agent=$(cfg_get_default_agent)
        if [[ -z "$agent" ]]; then
            echo "Error: No agent specified. Pass an agent name or create a .adr file with ADR_AGENT=<agent>. Run 'adr status' to see available agents." >&2
            exit 1
        fi
    fi

    if ! is_known_agent "$agent"; then
        echo "Error: Unknown agent '$agent'. Supported agents: ${KNOWN_AGENTS[*]}" >&2
        exit 1
    fi

    if [[ ! -d "$workspace" ]]; then
        echo "Error: workspace directory does not exist: $workspace" >&2
        exit 1
    fi

    if [[ -n "$config_dir" && ! -e "$config_dir" ]]; then
        echo "Error: config directory does not exist: $config_dir" >&2
        exit 1
    fi

    if ! image_exists "$agent" "$tag"; then
        if ! prompt_build_missing_image "$agent" "$tag"; then
            exit 1
        fi
    fi

    if [[ -z "$config_dir" ]]; then
        config_dir=$(default_config_dir_for_agent "$agent")

        if [[ ! -d "$config_dir" ]]; then
            echo "Error: config directory does not exist: $config_dir" >&2
            echo "       Pass --config to specify a different location, or create the directory." >&2
            exit 1
        fi
    fi

    if [[ "$agent" == "claude" && -z "$claude_config_file" ]]; then
        claude_config_file="$HOME/.claude.json"
        if [[ ! -f "$claude_config_file" ]]; then
            echo "Error: $claude_config_file not found." >&2
            echo "       Claude Code stores this file at ~/.claude.json." >&2
            echo "       See config-examples/claude/.claude.json.example." >&2
            echo "       You can also pass --config-file to point to a different location." >&2
            exit 1
        fi
    fi

    run_agent "$agent" "$tag" "$workspace" "$config_dir" "$claude_config_file" "$prompt" "$headless" "$shell_mode" "$model_override"
}
