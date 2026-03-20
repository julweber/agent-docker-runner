# shellcheck shell=bash

show_version() {
    local version_file="${HOME}/.local/share/adr/VERSION"
    local version=""

    if [[ -f "$version_file" ]]; then
        version=$(<"$version_file")
        echo "adr ${version}"
    else
        echo "adr (unknown version) — reinstall with install.sh"
    fi
}

show_help() {
    cat <<EOF
Usage: adr <command> [options]

Commands:
  build [agent]         Build Docker image(s) for an agent
  run [agent]           Run an agent in an isolated container
  update [agent]        Rebuild image(s), pulling the latest agent version
  status                Show which agent images are built
  fix-owner [dir]       Fix workspace file ownership (Linux only)
  completions <shell>   Print shell completion script
  config                Show or set configuration defaults
  version               Print installed version

Run 'adr help <command>' for detailed options.
EOF
}

main() {
    local cmd="${1:-}"

    cfg_init
    cfg_export_vars

    case "$cmd" in
        --version|-v)
            show_version
            exit 0
            ;;
        --help|-h)
            cmd_help ""
            exit 0
            ;;
    esac

    case "$cmd" in
        build)
            cmd_build "${@:2}"
            ;;
        run)
            cmd_run "${@:2}"
            ;;
        update)
            cmd_update "${@:2}"
            ;;
        status)
            cmd_status
            ;;
        fix-owner)
            cmd_fix_owner "${@:2}"
            ;;
        completions)
            cmd_completions "${@:2}"
            ;;
        config)
            cmd_config "${@:2}"
            ;;
        version)
            show_version
            exit 0
            ;;
        help)
            cmd_help "$@"
            ;;
        *)
            echo "Error: Unknown command '$cmd'" >&2
            echo "Run 'adr --help' for usage." >&2
            exit 1
            ;;
    esac
}
