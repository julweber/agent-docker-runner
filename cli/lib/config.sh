# shellcheck shell=bash

# Built-in defaults (lowest priority)
declare -r DEFAULT_ADR_TAG="latest"
declare -A BUILTIN_CONFIG=(
    [ADR_TAG]="$DEFAULT_ADR_TAG"
    [ADR_AGENT]=""
    [ADR_MODEL_PI]=""
    [ADR_MODEL_CLAUDE]=""
    [ADR_MODEL_OPENCODE]=""
    [ADR_MODEL_CODEX]=""
)

declare -A GLOBAL_CONFIG=()
declare -A PROJECT_CONFIG=()
declare -A EFFECTIVE_CONFIG=()

cfg_load_global_config() {
    local global_config_file="${HOME}/.config/adr/config"
    local key=""
    local value=""

    if [[ ! -f "$global_config_file" ]]; then
        return 0
    fi

    while IFS='=' read -r key value || [[ -n "$key" ]]; do
        [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
        key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        case "$key" in
            ADR_TAG|ADR_AGENT|ADR_MODEL_PI|ADR_MODEL_CLAUDE|ADR_MODEL_OPENCODE|ADR_MODEL_CODEX)
                GLOBAL_CONFIG["$key"]="$value"
                ;;
        esac
    done < "$global_config_file"
}

cfg_load_project_config() {
    local current_dir="$PWD"
    local adr_file=""
    local parent_dir=""
    local key=""
    local value=""

    while true; do
        if [[ -f "${current_dir}/.adr" ]]; then
            adr_file="${current_dir}/.adr"
            break
        fi

        parent_dir=$(dirname "$current_dir")
        if [[ "$parent_dir" == "$current_dir" ]]; then
            break
        fi
        current_dir="$parent_dir"
    done

    if [[ -z "$adr_file" ]]; then
        return 0
    fi

    while IFS='=' read -r key value || [[ -n "$key" ]]; do
        [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
        key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        case "$key" in
            ADR_TAG|ADR_AGENT|ADR_MODEL_PI|ADR_MODEL_CLAUDE|ADR_MODEL_OPENCODE|ADR_MODEL_CODEX)
                PROJECT_CONFIG["$key"]="$value"
                ;;
        esac
    done < "$adr_file"
}

cfg_merge_configs() {
    local key=""

    for key in "${!BUILTIN_CONFIG[@]}"; do
        EFFECTIVE_CONFIG["$key"]="${BUILTIN_CONFIG[$key]}"
    done

    for key in "${!GLOBAL_CONFIG[@]}"; do
        EFFECTIVE_CONFIG["$key"]="${GLOBAL_CONFIG[$key]}"
    done

    for key in "${!PROJECT_CONFIG[@]}"; do
        EFFECTIVE_CONFIG["$key"]="${PROJECT_CONFIG[$key]}"
    done
}

cfg_get() {
    local key="$1"
    local builtin_default="${BUILTIN_CONFIG[$key]:-}"

    echo "${EFFECTIVE_CONFIG[$key]:-$builtin_default}"
}

cfg_get_source() {
    local key="$1"

    if [[ -n "${PROJECT_CONFIG[$key]+x}" ]]; then
        echo ".adr"
    elif [[ -n "${GLOBAL_CONFIG[$key]+x}" ]]; then
        echo "$HOME/.config/adr/config"
    else
        echo "(default)"
    fi
}

cfg_export_vars() {
    export ADR_TAG="${EFFECTIVE_CONFIG[ADR_TAG]:-$DEFAULT_ADR_TAG}"
    export ADR_AGENT="${EFFECTIVE_CONFIG[ADR_AGENT]}"
    export ADR_MODEL_PI="${EFFECTIVE_CONFIG[ADR_MODEL_PI]}"
    export ADR_MODEL_CLAUDE="${EFFECTIVE_CONFIG[ADR_MODEL_CLAUDE]}"
    export ADR_MODEL_OPENCODE="${EFFECTIVE_CONFIG[ADR_MODEL_OPENCODE]}"
    export ADR_MODEL_CODEX="${EFFECTIVE_CONFIG[ADR_MODEL_CODEX]}"
}

cfg_get_default_agent() {
    local agent="${EFFECTIVE_CONFIG[ADR_AGENT]:-}"
    local known=""

    if [[ -z "$agent" ]]; then
        echo ""
        return 0
    fi

    for known in "${KNOWN_AGENTS[@]}"; do
        if [[ "$agent" == "$known" ]]; then
            echo "$agent"
            return 0
        fi
    done

    echo "$agent"
}

cfg_init() {
    cfg_load_global_config
    cfg_load_project_config
    cfg_merge_configs
}
