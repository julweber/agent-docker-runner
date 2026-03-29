#compdef adr
# Zsh completion for adr (Agent Docker Runner CLI)

_adr_completions() {
    local curcontext="$curcontext" state line
    
    # Known agents
    local -a agents=(
        "pi:Pi coding agent"
        "opencode:Opencode platform"
        "claude:Claude Code by Anthropic"
        "codex:OpenAI Codex CLI"
    )
    
    # Top-level commands
    local -a commands=(
        "build:Build Docker image(s) for an agent"
        "run:Run an agent in an isolated container"
        "update:Rebuild image(s), pulling the latest agent version"
        "status:Show which agent images are built"
        "fix-owner:Fix workspace file ownership (Linux only)"
        "completions:Print shell completion script or install it"
        "config:Show or set configuration defaults"
        "version:Print installed version"
        "help:Print usage information"
    )
    
    # Config keys for `adr config set`
    local -a config_keys=(
        "ADR_TAG:Default image tag for build and run"
        "ADR_AGENT:Default agent for adr run (no agent argument)"
        "ADR_MODEL_PI:Default model when running pi"
        "ADR_MODEL_CLAUDE:Default model when running claude"
        "ADR_MODEL_OPENCODE:Default model when running opencode"
        "ADR_MODEL_CODEX:Default model when running codex"
    )
    
    # Shell names for `adr completions`
    local -a shells=(
        "bash:Print bash completion script"
        "zsh:Print zsh completion script"
        "fish:Print fish completion script"
        "install:Auto-detect shell and install completions"
    )
    
    # Global options for top-level
    _arguments -C \
        "(-1 *):: :_adr_main_commands"
}

_adr_main_commands() {
    local commands=(
        "build:Build Docker image(s) for an agent"
        "run:Run an agent in an isolated container"
        "update:Rebuild image(s), pulling the latest agent version"
        "status:Show which agent images are built"
        "fix-owner:Fix workspace file ownership (Linux only)"
        "completions:Print shell completion script or install it"
        "config:Show or set configuration defaults"
        "version:Print installed version"
        "help:Print usage information"
    )
    
    _describe 'commands' commands
}

_adr_build() {
    local -a agents=(
        "pi:Pi coding agent"
        "opencode:Opencode platform"
        "claude:Claude Code by Anthropic"
        "codex:OpenAI Codex CLI"
    )
    
    _arguments -C \
        "--tag[Use a custom tag instead of latest]:TAG:" \
        "--no-cache[Build without using cached layers]" \
        "-h[Show help]" \
        "--help[Show help]" \
        "::agent :_adr_agents"
}

_adr_run() {
    local -a agents=(
        "pi:Pi coding agent"
        "opencode:Opencode platform"
        "claude:Claude Code by Anthropic"
        "codex:OpenAI Codex CLI"
    )

    _arguments -C \
        "--workspace[Host directory mounted as /workspace]:DIR:_files -/" \
        "-w[Host directory mounted as /workspace]:DIR:_files -/" \
        "--config[Override the agent config directory]:DIR:_files -/" \
        "-c[Override the agent config directory]:DIR:_files -/" \
        "--config-file[Claude only: path to .claude.json]:FILE:_files" \
        "--prompt[One-shot prompt; implies --headless]:TEXT:" \
        "--headless[Non-interactive mode]" \
        "--shell[Drop into bash inside the container]" \
        "--tag[Use a pinned image tag instead of latest]:TAG:" \
        "--model[Override the model at runtime]:MODEL:" \
        "-e[Set an environment variable]:KEY=VALUE:" \
        "--env[Set an environment variable]:KEY=VALUE:" \
        "--env-file[Load environment variables from a file]:FILE:_files" \
        "-h[Show help]" \
        "--help[Show help]" \
        "::agent :_adr_agents"
}

_adr_update() {
    local -a agents=(
        "pi:Pi coding agent"
        "opencode:Opencode platform"
        "claude:Claude Code by Anthropic"
        "codex:OpenAI Codex CLI"
    )
    
    _arguments -C \
        "--no-cache[Rebuild with fresh layers]" \
        "-h[Show help]" \
        "--help[Show help]" \
        "::agent :_adr_agents"
}

_adr_status() {
    _arguments -C
}

_adr_fix_owner() {
    _arguments -C \
        "::directory:_files -/"
}

_adr_completions_cmd() {
    local -a shells=(
        "bash:Print bash completion script"
        "zsh:Print zsh completion script"
        "fish:Print fish completion script"
        "install:Auto-detect shell and install completions"
    )
    
    _arguments -C \
        "::shell :_describe 'shells' shells"
}

_adr_config() {
    local -a config_keys=(
        "ADR_TAG:Default image tag for build and run"
        "ADR_AGENT:Default agent for adr run (no agent argument)"
        "ADR_MODEL_PI:Default model when running pi"
        "ADR_MODEL_CLAUDE:Default model when running claude"
        "ADR_MODEL_OPENCODE:Default model when running opencode"
        "ADR_MODEL_CODEX:Default model when running codex"
    )
    
    _arguments -C \
        "::subcommand :_describe 'subcommands' \"(set)'Set a config key'"
}

_adr_config_set() {
    local -a config_keys=(
        "ADR_TAG=Default image tag for build and run"
        "ADR_AGENT=Default agent for adr run (no agent argument)"
        "ADR_MODEL_PI=Default model when running pi"
        "ADR_MODEL_CLAUDE=Default model when running claude"
        "ADR_MODEL_OPENCODE=Default model when running opencode"
        "ADR_MODEL_CODEX=Default model when running codex"
    )
    
    _arguments -C \
        "--project[Write to project .adr file]" \
        "::key=value :_describe 'config keys' config_keys"
}

_adr_version() {
    _arguments -C
}

_adr_help() {
    local commands=(
        "build:Build Docker image(s) for an agent"
        "run:Run an agent in an isolated container"
        "update:Rebuild image(s), pulling the latest agent version"
        "status:Show which agent images are built"
        "fix-owner:Fix workspace file ownership (Linux only)"
        "completions:Print shell completion script or install it"
        "config:Show or set configuration defaults"
        "version:Print installed version"
        "help:Print usage information"
    )
    
    _arguments -C \
        "::command :_describe 'commands' commands"
}

_adr_agents() {
    local -a agents=(
        "pi:Pi coding agent"
        "opencode:Opencode platform"
        "claude:Claude Code by Anthropic"
        "codex:OpenAI Codex CLI"
    )
    
    _describe 'agents' agents
}

# Main dispatch based on command position
case "${words[1]}" in
    build)
        _adr_build
        ;;
    run)
        _adr_run
        ;;
    update)
        _adr_update
        ;;
    status)
        _adr_status
        ;;
    fix-owner)
        _adr_fix_owner
        ;;
    completions)
        _adr_completions_cmd
        ;;
    config)
        case "${words[2]}" in
            set)
                _adr_config_set
                ;;
            *)
                _arguments -C
                ;;
        esac
        ;;
    version)
        _adr_version
        ;;
    help)
        _adr_help
        ;;
    *)
        _adr_main_commands
        ;;
esac

compdef _adr_completions adr
