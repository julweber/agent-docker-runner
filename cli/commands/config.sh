# shellcheck shell=bash

cmd_config_show() {
    local keys=("ADR_TAG" "ADR_AGENT" "ADR_MODEL_PI" "ADR_MODEL_CLAUDE" "ADR_MODEL_OPENCODE" "ADR_MODEL_CODEX")
    local key=""
    local value=""
    local source=""

    cat <<'EOF'
Effective configuration (merged):

EOF

    for key in "${keys[@]}"; do
        value=$(cfg_get "$key")
        source=$(cfg_get_source "$key")
        printf '%-25s %s\n' "$key=$value" "$source"
    done
}

cmd_config_set() {
    local global_file="${HOME}/.config/adr/config"
    local project_file="$PWD/.adr"
    local is_project=false
    local arg=""
    local key=""
    local value=""
    local target_dir=""
    local tmp_file=""
    local found=false
    local line=""
    local existing_key=""

    if [[ $# -eq 0 ]]; then
        echo "Error: Expected KEY=VALUE format" >&2
        exit 1
    fi

    arg="$1"
    shift

    if [[ "$arg" == "--project" ]]; then
        is_project=true
        if [[ $# -eq 0 ]]; then
            echo "Error: Expected KEY=VALUE format" >&2
            exit 1
        fi
        arg="$1"
    fi

    if [[ ! "$arg" =~ = ]]; then
        echo "Error: Expected KEY=VALUE format" >&2
        exit 1
    fi

    key="${arg%%=*}"
    value="${arg#*=}"

    case "$key" in
        ADR_TAG|ADR_AGENT|ADR_MODEL_PI|ADR_MODEL_CLAUDE|ADR_MODEL_OPENCODE|ADR_MODEL_CODEX)
            ;;
        *)
            echo "Error: Unknown config key '$key'" >&2
            exit 1
            ;;
    esac

    if $is_project; then
        target_dir=$(dirname "$project_file")
        mkdir -p "$target_dir"

        if [[ -f "$project_file" ]]; then
            tmp_file=$(mktemp)
            found=false
            while IFS= read -r line || [[ -n "$line" ]]; do
                existing_key="${line%%=*}"
                if [[ "$existing_key" == "$key" ]]; then
                    echo "$arg" >> "$tmp_file"
                    found=true
                else
                    echo "$line" >> "$tmp_file"
                fi
            done < "$project_file"

            if ! $found; then
                echo "$arg" >> "$tmp_file"
            fi

            mv "$tmp_file" "$project_file"
        else
            echo "$arg" > "$project_file"
        fi

        echo "Set $key=$value in $project_file"
    else
        target_dir=$(dirname "$global_file")
        mkdir -p "$target_dir"

        if [[ -f "$global_file" ]]; then
            tmp_file=$(mktemp)
            found=false
            while IFS= read -r line || [[ -n "$line" ]]; do
                existing_key="${line%%=*}"
                if [[ "$existing_key" == "$key" ]]; then
                    echo "$arg" >> "$tmp_file"
                    found=true
                else
                    echo "$line" >> "$tmp_file"
                fi
            done < "$global_file"

            if ! $found; then
                echo "$arg" >> "$tmp_file"
            fi

            mv "$tmp_file" "$global_file"
        else
            echo "$arg" > "$global_file"
        fi

        echo "Set $key=$value in ~/.config/adr/config"
    fi
}

cmd_config() {
    local subcommand="${1:-}"
    shift || true

    case "$subcommand" in
        show|"")
            cmd_config_show
            ;;
        set)
            cmd_config_set "$@"
            ;;
        *)
            echo "Error: Unknown subcommand '$subcommand'" >&2
            echo "Usage: adr config [show|set KEY=VALUE|--project KEY=VALUE]" >&2
            exit 1
            ;;
    esac
}
