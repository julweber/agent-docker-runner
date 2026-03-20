# shellcheck shell=bash

cmd_help() {
    local command="${2:-}"

    if [[ -z "$command" ]]; then
        show_help
        exit 0
    fi

    case "$command" in
        build)
            echo "Usage: adr build [options] [<agent>]"
            echo ""
            echo "Build Docker image(s) for an agent."
            echo ""
            echo "Options:"
            echo "  --tag TAG       Use a custom tag instead of 'latest'"
            echo "  --no-cache      Build without using cached layers"
            echo ""
            echo "If no <agent> is specified, prompts to build all agents."
            ;;
        run)
            echo "Usage: adr run [options] [<agent>]"
            echo ""
            echo "Run an agent in an isolated container."
            echo ""
            echo "Options:"
            echo "  --workspace DIR   Host directory mounted as /workspace (default: $PWD)"
            echo "  --config DIR      Override the agent's config directory. If not specified,"
            echo "                    uses default config locations per agent:"
            echo "                      pi:       ~/.pi/"
            echo "                      opencode: ~/.config/opencode/"
            echo "                      claude:   ~/.claude/"
            echo "                      codex:    ~/.codex/"
            echo "  --config-file FILE   Claude only: path to .claude.json"
            echo "                    Defaults to ~/.claude.json on the host."
            echo "  --prompt TEXT     One-shot prompt; implies --headless"
            echo "  --headless        Non-interactive mode; requires --prompt"
            echo "  --shell           Drop into bash inside the container for debugging"
            echo "  --tag TAG         Use a pinned image tag instead of 'latest'"
            echo "  --model MODEL     Override the model at runtime"
            ;;
        update)
            echo "Usage: adr update [options] [<agent>]"
            echo ""
            echo "Rebuild image(s), pulling the latest agent version."
            echo ""
            echo "Options:"
            echo "  --no-cache      Rebuild with fresh layers (default behavior)"
            echo ""
            echo "If no <agent> is specified, rebuilds all images that are already present locally."
            ;;
        status)
            echo "Usage: adr status"
            echo ""
            echo "Show which agent images are built and their details."
            echo ""
            echo "Displays a table with Agent, Image, Tag, Size, and Built time for each known agent."
            ;;
        fix-owner)
            echo "Usage: adr fix-owner [DIR]"
            echo ""
            echo "Fix workspace file ownership (Linux only)."
            echo ""
            echo "Changes ownership of files in DIR recursively to the current user."
            echo "Defaults to $PWD if not specified."
            ;;
        completions)
            echo "Usage: adr completions <shell> | install"
            echo ""
            echo "Print shell completion script or auto-install it."
            echo ""
            echo "Arguments:"
            echo "  bash    Print bash completion script"
            echo "  zsh     Print zsh completion script"
            echo "  fish    Print fish completion script"
            echo "  install Auto-detect shell and install completions"
            ;;
        config)
            echo "Usage: adr config [subcommand]"
            echo ""
            echo "Show or set configuration defaults."
            echo ""
            echo "Subcommands:"
            echo "  (none)    Print effective merged configuration"
            echo "  set KEY=VALUE   Set a key in global config (~/.config/adr/config)"
            echo "  set --project KEY=VALUE   Set a key in project .adr file"
            ;;
        version)
            echo "Usage: adr version"
            echo ""
            echo "Print installed version."
            echo ""
            echo "Reads the VERSION file from ~/.local/share/adr/VERSION and prints 'adr <version>'."
            ;;
        help)
            echo "Usage: adr help [command]"
            echo ""
            echo "Print usage information."
            echo ""
            echo "Arguments:"
            echo "  (none)    Show command summary for all commands"
            echo "  <command> Print detailed options for the specified command"
            ;;
        *)
            echo "Error: Unknown command '$command'" >&2
            echo "Run 'adr help' for usage." >&2
            exit 1
            ;;
    esac
}
