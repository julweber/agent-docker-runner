# Bash completion for adr (Agent Docker Runner CLI)
# Usage: source this file or run `adr completions bash`

_adr_completions() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local prev="${COMP_WORDS[COMP_CWORD-1]}"
    
    # List of top-level commands
    local commands="build run update status fix-owner completions config version help"
    
    # List of known agents
    local agents="pi opencode claude codex"
    
    # Config keys for `adr config set`
    local config_keys="ADR_TAG= ADR_AGENT= ADR_MODEL_PI= ADR_MODEL_CLAUDE= ADR_MODEL_OPENCODE= ADR_MODEL_CODEX="
    
    # Shell names for `adr completions`
    local shells="bash zsh fish install"
    
    case "${COMP_WORDS[1]}" in
        build|run|update)
            # After build/run/update, offer agent names (unless --help or flags follow)
            if [[ "$cur" == -* ]]; then
                # Complete flags for these commands
                COMPREPLY=( $(compgen -W "--tag --no-cache --workspace --config --config-file --prompt --headless --shell --model --env --env-file --help -h -w -c -e" -- "$cur") )
            else
                COMPREPLY=( $(compgen -W "$agents" -- "$cur") )
            fi
            ;;
        fix-owner)
            # fix-owner takes a directory, let bash complete directories
            if [[ "$cur" == -* ]]; then
                COMPREPLY=()  # No flags for fix-owner
            else
                COMPREPLY=( $(compgen -d -- "$cur") )
            fi
            ;;
        completions)
            # After `adr completions`, offer shell names
            if [[ "$cur" == -* ]]; then
                COMPREPLY=()  # No flags for completions
            else
                COMPREPLY=( $(compgen -W "$shells" -- "$cur") )
            fi
            ;;
        config)
            case "${COMP_WORDS[2]}" in
                set)
                    # After `adr config set`, offer config keys (with = suffix for better UX)
                    if [[ "$cur" == -* ]]; then
                        COMPREPLY=()  # No flags for config set
                    else
                        COMPREPLY=( $(compgen -W "$config_keys" -- "$cur") )
                    fi
                    ;;
                *)
                    # Just `adr config`, offer subcommands
                    if [[ "$cur" == -* ]]; then
                        COMPREPLY=()  # No flags for config show
                    else
                        COMPREPLY=( $(compgen -W "set --project" -- "$cur") )
                    fi
                    ;;
            esac
            ;;
        version|status)
            # These commands take no arguments
            COMPREPLY=()
            ;;
        help)
            # After `adr help`, offer command names
            if [[ "$cur" == -* ]]; then
                COMPREPLY=()  # No flags for help
            else
                COMPREPLY=( $(compgen -W "$commands $agents" -- "$cur") )
            fi
            ;;
        "")
            # Top-level completion: offer commands
            if [[ "$cur" == -* ]]; then
                COMPREPLY=( $(compgen -W "--help --version -h -v" -- "$cur") )
            else
                COMPREPLY=( $(compgen -W "$commands" -- "$cur") )
            fi
            ;;
        *)
            # Unknown command, no completions
            COMPREPLY=()
            ;;
    esac
}

complete -F _adr_completions adr
