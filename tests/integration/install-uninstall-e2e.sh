#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly REPO_ROOT
TEST_ROOT="$(mktemp -d /tmp/adr-install-e2e.XXXXXX)"
readonly TEST_ROOT
readonly TEST_HOME="${TEST_ROOT}/home"
readonly TEST_PATH="${TEST_HOME}/.local/bin:/usr/local/bin:/usr/bin:/bin"
readonly LOG_DIR="${TEST_ROOT}/logs"
readonly WORKSPACE_ROOT="${TEST_ROOT}/workspaces"
readonly AGENTS=("pi" "opencode" "claude" "codex")

cleanup() {
    local agent=""
    local image=""
    local container_ids=""
    local -a container_id_array=()

    for agent in "${AGENTS[@]}"; do
        image="coding-agent/${agent}:latest"
        container_ids="$(docker ps -aq --filter "ancestor=${image}" 2>/dev/null || true)"
        if [[ -n "$container_ids" ]]; then
            mapfile -t container_id_array <<< "$container_ids"
            docker rm -f "${container_id_array[@]}" >/dev/null 2>&1 || true
        fi
    done

    rm -rf "$TEST_ROOT"
}

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

log() {
    echo "==> $*"
}

assert_file_exists() {
    local path="$1"

    [[ -e "$path" ]] || fail "Expected path to exist: $path"
}

assert_not_exists() {
    local path="$1"

    [[ ! -e "$path" ]] || fail "Expected path to be absent: $path"
}

assert_command_succeeds() {
    local description="$1"
    shift

    log "$description"
    "$@" || fail "Command failed: $description"
}

require_command() {
    local cmd="$1"

    command -v "$cmd" >/dev/null 2>&1 || fail "Required command not found: $cmd"
}

setup_environment() {
    mkdir -p "$TEST_HOME/.local/bin" "$TEST_HOME/.config" "$TEST_HOME/.local/share"
    mkdir -p "$LOG_DIR" "$WORKSPACE_ROOT"

    mkdir -p "$TEST_HOME/.pi"
    mkdir -p "$TEST_HOME/.config/opencode"
    mkdir -p "$TEST_HOME/.claude"
    mkdir -p "$TEST_HOME/.codex"
    printf '{}\n' > "$TEST_HOME/.claude.json"
}

run_in_test_home() {
    env \
        HOME="$TEST_HOME" \
        XDG_CONFIG_HOME="$TEST_HOME/.config" \
        XDG_DATA_HOME="$TEST_HOME/.local/share" \
        PATH="$TEST_PATH" \
        "$@"
}

assert_installed_layout() {
    assert_file_exists "$TEST_HOME/.local/bin/adr"
    assert_file_exists "$TEST_HOME/.local/share/adr/cli/main.sh"
    assert_file_exists "$TEST_HOME/.local/share/adr/cli/lib/config.sh"
    assert_file_exists "$TEST_HOME/.local/share/adr/cli/commands/run.sh"

    local resolved_adr=""
    resolved_adr="$(run_in_test_home bash -lc 'command -v adr')"
    [[ "$resolved_adr" == "$TEST_HOME/.local/bin/adr" ]] || \
        fail "Expected installed adr on PATH, got: ${resolved_adr}"
}

build_all_agents() {
    local agent=""

    for agent in "${AGENTS[@]}"; do
        assert_command_succeeds \
            "Build ${agent} image via installed adr" \
            run_in_test_home adr build "$agent"
        assert_command_succeeds \
            "Verify ${agent} image exists" \
            docker image inspect "coding-agent/${agent}:latest"
    done
}

wait_for_container_start() {
    local agent="$1"
    local deadline="$2"
    local container_id=""

    while (( SECONDS < deadline )); do
        container_id="$(docker ps --filter "ancestor=coding-agent/${agent}:latest" --format '{{.ID}}' | head -n 1)"
        if [[ -n "$container_id" ]]; then
            echo "$container_id"
            return 0
        fi
        sleep 1
    done

    return 1
}

start_and_stop_agent_once() {
    local agent="$1"
    local workspace="${WORKSPACE_ROOT}/${agent}"
    local log_file="${LOG_DIR}/${agent}.log"
    local pid=""
    local container_id=""
    local deadline=0

    mkdir -p "$workspace"

    log "Start ${agent} via installed adr"
    run_in_test_home script -qec "adr run ${agent} --shell --workspace ${workspace}" /dev/null \
        >"$log_file" 2>&1 &
    pid=$!

    deadline=$((SECONDS + 60))
    if ! container_id="$(wait_for_container_start "$agent" "$deadline")"; then
        kill "$pid" >/dev/null 2>&1 || true
        wait "$pid" >/dev/null 2>&1 || true
        echo "---- ${agent} log ----" >&2
        cat "$log_file" >&2 || true
        fail "Timed out waiting for ${agent} container to start"
    fi

    log "Observed ${agent} container ${container_id}; stopping it"
    docker stop "$container_id" >/dev/null || fail "Failed to stop ${agent} container ${container_id}"
    wait "$pid" >/dev/null 2>&1 || true
}

verify_images_preserved() {
    local agent=""

    for agent in "${AGENTS[@]}"; do
        assert_command_succeeds \
            "Verify ${agent} image remains after uninstall" \
            docker image inspect "coding-agent/${agent}:latest"
    done
}

main() {
    trap cleanup EXIT

    require_command docker
    require_command script
    docker info >/dev/null 2>&1 || fail "Docker daemon is not reachable"

    setup_environment

    assert_command_succeeds "Install adr into isolated HOME" \
        run_in_test_home "$REPO_ROOT/install.sh"
    assert_installed_layout

    assert_command_succeeds "Installed adr help works" run_in_test_home adr --help
    assert_command_succeeds "Installed adr version works" run_in_test_home adr version

    build_all_agents

    local agent=""
    for agent in "${AGENTS[@]}"; do
        start_and_stop_agent_once "$agent"
    done

    assert_command_succeeds "Uninstall adr from isolated HOME" \
        run_in_test_home "$REPO_ROOT/uninstall.sh" --yes

    assert_not_exists "$TEST_HOME/.local/bin/adr"
    assert_not_exists "$TEST_HOME/.local/share/adr"

    verify_images_preserved

    log "Install/build/run/uninstall integration test passed"
}

main "$@"
