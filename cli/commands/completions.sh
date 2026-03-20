# shellcheck shell=bash

show_completions_help() {
    cat <<'EOF'
Usage: adr completions <shell> | install

Print shell completion script or auto-install it.

Arguments:
  bash    Print bash completion script
  zsh     Print zsh completion script
  fish    Print fish completion script
  install Auto-detect shell and install completions
EOF
}

cmd_completions_help() {
    show_completions_help
}

completions_install_dir() {
    local shell="$1"

    case "$shell" in
        bash) echo "${HOME}/.bash_completion.d" ;;
        zsh) echo "${HOME}/.zsh/completions" ;;
        fish) echo "${HOME}/.config/fish/completions" ;;
    esac
}

completions_filename() {
    local shell="$1"

    case "$shell" in
        bash) echo "adr.bash" ;;
        zsh) echo "_adr" ;;
        fish) echo "adr.fish" ;;
    esac
}

completions_rc_hint() {
    local shell="$1"

    case "$shell" in
        bash)
            echo "Add this line to ~/.bashrc:"
            echo "  if [ -d \"\$HOME/.bash_completion.d\" ]; then"
            echo "    for f in \$HOME/.bash_completion.d/*; do source \"\$f\"; done"
            echo "  fi"
            ;;
        zsh)
            echo "Add this line to ~/.zshrc:"
            echo "  fpath=(~/.zsh/completions \$fpath)"
            echo "  autoload -U compinit && compinit"
            ;;
        fish)
            echo "Fish completions are auto-loaded from ~/.config/fish/completions/."
            echo "No rc file modification needed."
            ;;
    esac
}

detect_current_shell() {
    local shell_path="$SHELL"
    local shell_name=""

    if [[ -z "$shell_path" ]]; then
        echo "bash"
        return
    fi

    shell_name="${shell_path##*/}"

    case "$shell_name" in
        bash|sh) echo "bash" ;;
        zsh) echo "zsh" ;;
        fish) echo "fish" ;;
        *) echo "bash" ;;
    esac
}

cmd_completions_print() {
    local shell="$1"
    local installed_file="${HOME}/.local/share/adr/completions/adr.${shell}"
    local repo_file="${ADR_CLI_DIR}/../completions/adr.${shell}"

    case "$shell" in
        bash|zsh|fish)
            if [[ -f "$installed_file" ]]; then
                cat "$installed_file"
            elif [[ -f "$repo_file" ]]; then
                cat "$repo_file"
            else
                echo "Error: Completion script for $shell not found." >&2
                return 1
            fi
            ;;
        *)
            echo "Error: Unknown shell '$shell'. Supported: bash, zsh, fish" >&2
            return 1
            ;;
    esac
}

cmd_completions_install() {
    local shell="$1"
    local install_dir=""
    local filename=""
    local target_file=""
    local rc_hint=""

    case "$shell" in
        bash|zsh|fish)
            ;;
        *)
            echo "Error: Unknown shell '$shell'. Supported: bash, zsh, fish" >&2
            return 1
            ;;
    esac

    install_dir=$(completions_install_dir "$shell")
    filename=$(completions_filename "$shell")
    target_file="${install_dir}/${filename}"

    mkdir -p "$install_dir" || {
        echo "Error: Cannot create directory $install_dir" >&2
        return 1
    }

    if [[ -f "${HOME}/.local/share/adr/completions/${filename}" ]]; then
        cp "${HOME}/.local/share/adr/completions/${filename}" "$target_file"
    elif [[ -f "${ADR_CLI_DIR}/../completions/${filename}" ]]; then
        cp "${ADR_CLI_DIR}/../completions/${filename}" "$target_file"
    else
        echo "Error: Completion script for $shell not found." >&2
        return 1
    fi

    chmod a+r "$target_file"

    echo "Installed completions for ${shell} to: ${target_file}"
    echo ""

    rc_hint=$(completions_rc_hint "$shell")
    echo "$rc_hint"
}

cmd_completions() {
    local shell_or_action="${1:-}"
    local detected_shell=""

    case "$shell_or_action" in
        bash|zsh|fish)
            cmd_completions_print "$shell_or_action"
            ;;
        install)
            detected_shell=$(detect_current_shell)
            echo "Detected shell: ${detected_shell}"
            echo ""
            cmd_completions_install "$detected_shell"
            ;;
        --help|-h)
            cmd_completions_help
            exit 0
            ;;
        "")
            show_completions_help
            ;;
        *)
            echo "Error: Unknown shell '$shell_or_action'. Supported: bash, zsh, fish" >&2
            echo ""
            show_completions_help
            exit 1
            ;;
    esac
}
