# shellcheck shell=bash

resolve_build_context() {
    local agent="$1"
    local repo_context="${ADR_CLI_DIR}/../agents/${agent}"
    local installed_context="${HOME}/.local/share/adr/agents/${agent}"

    if [[ -d "$repo_context" && -f "${repo_context}/Dockerfile" ]]; then
        (cd "$repo_context" && pwd)
        return 0
    fi

    if [[ -d "$installed_context" && -f "${installed_context}/Dockerfile" ]]; then
        echo "$installed_context"
        return 0
    fi

    return 1
}

docker_available() {
    docker info >/dev/null 2>&1
}

image_exists() {
    local agent="$1"
    local tag="$2"

    docker image inspect "coding-agent/${agent}:${tag}" >/dev/null 2>&1
}

get_image_created() {
    local agent="$1"
    local tag="$2"

    docker image inspect --format '{{.Created}}' "coding-agent/${agent}:${tag}" 2>/dev/null
}

get_image_info() {
    local agent="$1"
    local tag="${2:-latest}"
    local output=""
    local repo=""
    local image_tag=""
    local size=""
    local created=""

    output=$(docker image ls --format '{{.ID}}|{{.Repository}}|{{.Tag}}|{{.Size}}|{{.CreatedAt}}' "coding-agent/${agent}:${tag}" 2>/dev/null)

    if [[ -z "$output" ]]; then
        echo "NOT_FOUND"
        return
    fi

    IFS='|' read -r _ repo image_tag size created <<< "$output"
    echo "FOUND|$repo|$image_tag|$size|$created"
}

build_agent_image() {
    local agent="$1"
    local tag="$2"
    local no_cache="$3"
    local image_name="coding-agent/${agent}:${tag}"
    local build_context=""
    local docker_opts=("-t" "$image_name")

    if ! build_context=$(resolve_build_context "$agent"); then
        echo "Error: Build context not found for agent '$agent'" >&2
        echo "       Checked '${ADR_CLI_DIR}/../agents/${agent}' and '${HOME}/.local/share/adr/agents/${agent}'." >&2
        return 1
    fi

    if [[ "$no_cache" == true ]]; then
        docker_opts+=("--no-cache")
    fi
    docker_opts+=("$build_context")

    echo "Building $image_name..."

    if docker build "${docker_opts[@]}"; then
        echo "Image $image_name built successfully."
        return 0
    fi

    if ! docker_available; then
        echo "Error: Cannot reach Docker daemon. Is the Docker daemon running?" >&2
    else
        echo "Build failed with non-zero exit code." >&2
    fi

    return 1
}

prompt_build_missing_image() {
    local agent="$1"
    local tag="$2"
    local response=""

    echo "Image coding-agent/${agent}:${tag} not found. Build it now? [Y/n]"
    read -r -p "" response

    case "$response" in
        [Nn]*)
            echo "Please build the image manually: adr build ${agent} --tag ${tag}"
            return 1
            ;;
        ""|[Yy]*)
            build_agent_image "$agent" "$tag" false
            return $?
            ;;
        *)
            echo "Please answer 'y' or 'n'." >&2
            return 1
            ;;
    esac
}
