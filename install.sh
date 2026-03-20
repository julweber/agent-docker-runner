#!/usr/bin/env bash
#
# install.sh - Install adr to the host system
#
# This script installs `adr` onto the host system and makes it available in PATH.
# The script is safe to re-run as an upgrade mechanism (idempotent).
#
# What gets installed:
#   ~/.local/bin/adr                - Main CLI executable
#   ~/.local/share/adr/cli/*        - Sourced CLI modules
#   ~/.local/share/adr/VERSION      - Version string file
#   ~/.local/share/adr/agents/*     - Agent Dockerfiles and entrypoints
#   ~/.local/share/adr/config-examples/* - Configuration examples
#
# What is NOT touched:
#   ~/.config/adr/config            - Global user config (preserved on upgrade)
#   Any project .adr files          - Project-level configs (preserved)
#
set -euo pipefail

# ==============================================================================
# CONSTANTS AND PATHS
# ==============================================================================
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
readonly SCRIPT_DIR
readonly LOCAL_BIN="${HOME}/.local/bin/adr"
readonly ADR_SHARE="${HOME}/.local/share/adr"
readonly CLI_DIR="${ADR_SHARE}/cli"
readonly VERSION_FILE="${ADR_SHARE}/VERSION"
readonly AGENTS_DIR="${ADR_SHARE}/agents"
readonly CONFIG_EXAMPLES_DIR="${ADR_SHARE}/config-examples"
readonly COMPLETIONS_DIR="${ADR_SHARE}/completions"

# ==============================================================================
# UTILITY FUNCTIONS
# ==============================================================================

# Print error message to stderr and exit with specified code
error() {
    echo "Error: $*" >&2
    exit "${1:-1}"
}

# Check if running in a CI/non-TTY environment (skip interactive prompts)
is_ci_or_no_tty() {
    [[ -z "$TERM" ]] || [[ "${CI:-}" == "true" ]] || ! tty -s
}

# ==============================================================================
# VALIDATION AND PREPARATION
# ==============================================================================

validate_source_files() {
    # Check that required source files exist in the repository
    local missing=()
    
    if [[ ! -f "${SCRIPT_DIR}/cli/adr" ]]; then
        missing+=("cli/adr")
    fi

    if [[ ! -f "${SCRIPT_DIR}/cli/main.sh" ]]; then
        missing+=("cli/main.sh")
    fi

    if [[ ! -d "${SCRIPT_DIR}/cli/lib" ]]; then
        missing+=("cli/lib/")
    fi

    if [[ ! -d "${SCRIPT_DIR}/cli/commands" ]]; then
        missing+=("cli/commands/")
    fi
    
    if [[ ! -d "${SCRIPT_DIR}/agents" ]]; then
        missing+=("agents/")
    fi
    
    if [[ ! -d "${SCRIPT_DIR}/config-examples" ]]; then
        missing+=("config-examples/")
    fi
    
    # Completions are optional at this stage - create placeholders if missing
    # Don't add to missing list, just note in copy_completions()
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        error "Missing required source files: ${missing[*]}"
    fi
}

check_existing_install() {
    # If adr already exists, check if we can overwrite it
    if [[ -f "$LOCAL_BIN" ]]; then
        # Check ownership - don't overwrite if owned by another user
        local owner
        owner=$(stat -c '%U' "$LOCAL_BIN" 2>/dev/null || stat -f '%Su' "$LOCAL_BIN" 2>/dev/null)
        if [[ "$owner" != "$(whoami)" ]]; then
            error "Cannot overwrite existing file '$LOCAL_BIN'. Remove it manually or check permissions."
        fi
    fi
}

prepare_target_directories() {
    # Create target directories with proper permissions
    mkdir -p "${HOME}/.local/bin" || \
        error "Failed to create ~/.local/bin (check permissions)"
    
    mkdir -p "$ADR_SHARE" || \
        error "Failed to create ~/.local/share/adr (check permissions)"

    mkdir -p "$CLI_DIR" || \
        error "Failed to create ~/.local/share/adr/cli (check permissions)"
    
    mkdir -p "$AGENTS_DIR" || \
        error "Failed to create ~/.local/share/adr/agents (check permissions)"
    
    mkdir -p "$CONFIG_EXAMPLES_DIR" || \
        error "Failed to create ~/.local/share/adr/config-examples (check permissions)"
    
    mkdir -p "$COMPLETIONS_DIR" || \
        error "Failed to create ~/.local/share/adr/completions (check permissions)"
}

# ==============================================================================
# INSTALLATION FUNCTIONS
# ==============================================================================

copy_cli() {
    cp "${SCRIPT_DIR}/cli/adr" "$LOCAL_BIN"
    chmod +x "$LOCAL_BIN"

    if command -v rsync &>/dev/null; then
        rsync -a \
            --exclude 'adr' \
            "${SCRIPT_DIR}/cli/" "$CLI_DIR/"
    else
        cp "${SCRIPT_DIR}/cli/main.sh" "$CLI_DIR/"
        mkdir -p "${CLI_DIR}/lib" "${CLI_DIR}/commands"
        cp -r "${SCRIPT_DIR}/cli/lib/." "${CLI_DIR}/lib/"
        cp -r "${SCRIPT_DIR}/cli/commands/." "${CLI_DIR}/commands/"
    fi
}

copy_agents() {
    # Copy entire agents directory tree using rsync or loop
    if command -v rsync &>/dev/null; then
        rsync -a "${SCRIPT_DIR}/agents/" "$AGENTS_DIR/"
    else
        # Fallback: copy each agent subdirectory individually
        for agent_dir in "${SCRIPT_DIR}/agents/"*; do
            if [[ -d "$agent_dir" ]]; then
                cp -r "$agent_dir" "$AGENTS_DIR/"
            fi
        done
    fi
}

copy_config_examples() {
    # Copy entire config-examples directory tree using rsync or loop
    if command -v rsync &>/dev/null; then
        rsync -a "${SCRIPT_DIR}/config-examples/" "$CONFIG_EXAMPLES_DIR/"
    else
        # Fallback: copy each agent subdirectory individually
        for config_dir in "${SCRIPT_DIR}/config-examples/"*; do
            if [[ -d "$config_dir" ]]; then
                cp -r "$config_dir" "$CONFIG_EXAMPLES_DIR/"
            fi
        done
    fi
}

copy_completions() {
    local completions_found=false
    
    # Try to find completion scripts in various locations
    if [[ -d "${SCRIPT_DIR}/completions" ]]; then
        cp "${SCRIPT_DIR}/completions/adr.bash" "$COMPLETIONS_DIR/"
        cp "${SCRIPT_DIR}/completions/adr.zsh" "$COMPLETIONS_DIR/"
        cp "${SCRIPT_DIR}/completions/adr.fish" "$COMPLETIONS_DIR/"
        completions_found=true
    elif [[ -d "${SCRIPT_DIR}/agents/pi/completions" ]]; then
        # Check if completions are in agents subdirectory (unlikely but possible)
        for shell in bash zsh fish; do
            local src="${SCRIPT_DIR}/agents/pi/completions/adr.${shell}"
            local dst="${COMPLETIONS_DIR}/adr.${shell}"
            if [[ -f "$src" ]]; then
                cp "$src" "$dst"
                completions_found=true
            fi
        done
    fi
    
    # If no completions found, create placeholder files with notes
    if ! $completions_found; then
        echo "# Placeholder - completion scripts will be added in future release" > "$COMPLETIONS_DIR/adr.bash"
        echo "# Placeholder - completion scripts will be added in future release" > "$COMPLETIONS_DIR/adr.zsh"
        echo "# Placeholder - completion scripts will be added in future release" > "$COMPLETIONS_DIR/adr.fish"
    fi
}

write_version_file() {
    local version="0.3.0"
    
    # Try to read VERSION from repository if it exists
    if [[ -f "${SCRIPT_DIR}/VERSION" ]]; then
        version=$(cat "${SCRIPT_DIR}/VERSION")
    fi
    
    echo "$version" > "$VERSION_FILE"
}

check_path() {
    # Check if ~/.local/bin is on PATH
    local path_dirs
    path_dirs=$(echo "$PATH" | tr ':' '\n')
    
    if ! echo "$path_dirs" | grep -q "${HOME}/.local/bin"; then
        echo ""
        echo "Warning: ~/.local/bin is not on your PATH."
        echo "Add the following line to your shell config file and restart:"
        echo "  export PATH=\"\$PATH:${HOME}/.local/bin\""
    fi
}

print_success_message() {
    echo "adr installed. Run 'adr status' to check your agents."
}

# ==============================================================================
# MAIN INSTALLATION FLOW
# ==============================================================================

main() {
    # Validate source files exist
    validate_source_files
    
    # Check for existing install and permissions
    check_existing_install
    
    # Prepare target directories (fail fast if any fail)
    prepare_target_directories
    
    # Copy all components atomically
    copy_cli
    copy_agents
    copy_config_examples
    copy_completions
    write_version_file
    
    # Check PATH and print reminder if needed
    check_path
    
    # Print success message (always, even in CI)
    print_success_message
}

# Run main with all arguments
main "$@"
