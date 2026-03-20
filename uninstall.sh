#!/usr/bin/env bash
#
# uninstall.sh — Remove adr installation from the host system.
#
# This script removes everything that install.sh placed on disk:
#   - ~/.local/bin/adr
#   - ~/.local/share/adr/* (including the split cli/ runtime tree)
#
# It does NOT remove:
#   - ~/.config/adr/config (global user config)
#   - Any project-level .adr files
#   - Docker images already built (coding-agent/*)
#
# Usage:
#   ./uninstall.sh          # prompts for confirmation
#   ./uninstall.sh --yes    # skips the prompt, proceeds directly
#

set -euo pipefail

# === Constants ===
ADR_BIN="${HOME}/.local/bin/adr"
ADR_SHARE="${HOME}/.local/share/adr"
ADR_CLI_DIR="${ADR_SHARE}/cli"
ADR_CONFIG="${HOME}/.config/adr/config"

# Global flags
SKIP_PROMPT=false

# === Parse arguments ===
while [[ $# -gt 0 ]]; do
    case "$1" in
        --yes)
            SKIP_PROMPT=true
            shift
            ;;
        *)
            echo "Error: Unknown option '$1'"
            echo "Usage: $0 [--yes]"
            exit 1
            ;;
    esac
done

# === Check if adr appears to be installed ===
check_installed() {
    local installed=false
    
    # Check main executable
    if [[ -f "$ADR_BIN" ]]; then
        installed=true
    fi

    if [[ -d "$ADR_CLI_DIR" ]]; then
        installed=true
    fi
    
    # Check share directory (fallback check)
    if [[ ! -d "$ADR_SHARE" ]] && [[ "$installed" == "false" ]]; then
        echo "adr does not appear to be installed."
        exit 0
    fi
}

# === Prompt for confirmation ===
prompt_confirmation() {
    if [[ "$SKIP_PROMPT" == "true" ]]; then
        return 0
    fi
    
    echo "Remove adr? This will delete ${ADR_BIN} and ${ADR_SHARE}/."
    echo "Your ${ADR_CONFIG} and Docker images are kept. [y/N]"
    read -r response
    
    case "$response" in
        [Yy]|[Yy][Ee][Ss])
            return 0
            ;;
        *)
            echo "Aborted."
            exit 0
            ;;
    esac
}

# === Remove installed files ===
remove_files() {
    # Remove the executable
    if [[ -f "$ADR_BIN" ]]; then
        rm -f "$ADR_BIN"
        echo "Removed ${ADR_BIN}"
    fi
    
    # Remove the share directory entirely
    if [[ -d "$ADR_SHARE" ]]; then
        rm -rf "$ADR_SHARE"
        echo "Removed ${ADR_SHARE}/"
    fi
}

# === Main execution ===
main() {
    check_installed
    prompt_confirmation
    remove_files
    
    echo "adr has been uninstalled successfully."
}

main
