# Fish completion for adr (Agent Docker Runner CLI)

complete -c adr -n "not __fish_seen_subcommand_from build run update status fix-owner completions config version help" -l help -d 'Show help'
complete -c adr -n "not __fish_seen_subcommand_from build run update status fix-owner completions config version help" -s h -d 'Show help'
complete -c adr -n "not __fish_seen_subcommand_from build run update status fix-owner completions config version help" -l version -d 'Print installed version'
complete -c adr -n "not __fish_seen_subcommand_from build run update status fix-owner completions config version help" -s v -d 'Print installed version'

# Build command completions
complete -c adr -n "__fish_use_subcommand; and __fish_seen_subcommand_from build" -l tag -d 'Use a custom tag instead of latest' -r
complete -c adr -n "__fish_use_subcommand; and __fish_seen_subcommand_from build" -l no-cache -d 'Build without using cached layers'
complete -c adr -n "__fish_use_subcommand; and __fish_seen_subcommand_from build" -s h -d 'Show help'
complete -c adr -n "__fish_use_subcommand; and __fish_seen_subcommand_from build" -l help -d 'Show help'

# Build command agent completions
complete -c adr -n "__fish_seen_subcommand_from build" -f -a "pi" -d "Pi coding agent"
complete -c adr -n "__fish_seen_subcommand_from build" -f -a "opencode" -d "Opencode platform"
complete -c adr -n "__fish_seen_subcommand_from build" -f -a "claude" -d "Claude Code by Anthropic"
complete -c adr -n "__fish_seen_subcommand_from build" -f -a "codex" -d "OpenAI Codex CLI"

# Run command completions
complete -c adr -n "__fish_use_subcommand; and __fish_seen_subcommand_from run" -l workspace -d 'Host directory mounted as /workspace' -r -F
complete -c adr -n "__fish_use_subcommand; and __fish_seen_subcommand_from run" -s w -d 'Host directory mounted as /workspace' -r -F
complete -c adr -n "__fish_use_subcommand; and __fish_seen_subcommand_from run" -l config -d 'Override the agent config directory' -r -F
complete -c adr -n "__fish_use_subcommand; and __fish_seen_subcommand_from run" -s c -d 'Override the agent config directory' -r -F
complete -c adr -n "__fish_use_subcommand; and __fish_seen_subcommand_from run" -l config-file -d 'Claude only: path to .claude.json' -r -F
complete -c adr -n "__fish_use_subcommand; and __fish_seen_subcommand_from run" -l prompt -d 'One-shot prompt; implies --headless' -r
complete -c adr -n "__fish_use_subcommand; and __fish_seen_subcommand_from run" -l headless -d 'Non-interactive mode; requires --prompt'
complete -c adr -n "__fish_use_subcommand; and __fish_seen_subcommand_from run" -l shell -d 'Drop into bash inside the container for debugging'
complete -c adr -n "__fish_use_subcommand; and __fish_seen_subcommand_from run" -l tag -d 'Use a pinned image tag instead of latest' -r
complete -c adr -n "__fish_use_subcommand; and __fish_seen_subcommand_from run" -l model -d 'Override the model at runtime' -r
complete -c adr -n "__fish_use_subcommand; and __fish_seen_subcommand_from run" -s h -d 'Show help'
complete -c adr -n "__fish_use_subcommand; and __fish_seen_subcommand_from run" -l help -d 'Show help'

# Run command agent completions
complete -c adr -n "__fish_seen_subcommand_from run" -f -a "pi" -d "Pi coding agent"
complete -c adr -n "__fish_seen_subcommand_from run" -f -a "opencode" -d "Opencode platform"
complete -c adr -n "__fish_seen_subcommand_from run" -f -a "claude" -d "Claude Code by Anthropic"
complete -c adr -n "__fish_seen_subcommand_from run" -f -a "codex" -d "OpenAI Codex CLI"

# Update command completions
complete -c adr -n "__fish_use_subcommand; and __fish_seen_subcommand_from update" -l no-cache -d 'Rebuild with fresh layers'
complete -c adr -n "__fish_use_subcommand; and __fish_seen_subcommand_from update" -s h -d 'Show help'
complete -c adr -n "__fish_use_subcommand; and __fish_seen_subcommand_from update" -l help -d 'Show help'

# Update command agent completions
complete -c adr -n "__fish_seen_subcommand_from update" -f -a "pi" -d "Pi coding agent"
complete -c adr -n "__fish_seen_subcommand_from update" -f -a "opencode" -d "Opencode platform"
complete -c adr -n "__fish_seen_subcommand_from update" -f -a "claude" -d "Claude Code by Anthropic"
complete -c adr -n "__fish_seen_subcommand_from update" -f -a "codex" -d "OpenAI Codex CLI"

# Status command - no additional flags or arguments
complete -c adr -n "__fish_use_subcommand; and __fish_seen_subcommand_from status" -s h -d 'Show help'
complete -c adr -n "__fish_use_subcommand; and __fish_seen_subcommand_from status" -l help -d 'Show help'

# Fix-owner command completions
complete -c adr -n "__fish_use_subcommand; and __fish_seen_subcommand_from fix-owner" -s h -d 'Show help'
complete -c adr -n "__fish_use_subcommand; and __fish_seen_subcommand_from fix-owner" -l help -d 'Show help'

# Completions command completions
complete -c adr -n "__fish_use_subcommand; and __fish_seen_subcommand_from completions" -f -a "bash" -d "Print bash completion script"
complete -c adr -n "__fish_use_subcommand; and __fish_seen_subcommand_from completions" -f -a "zsh" -d "Print zsh completion script"
complete -c adr -n "__fish_use_subcommand; and __fish_seen_subcommand_from completions" -f -a "fish" -d "Print fish completion script"
complete -c adr -n "__fish_use_subcommand; and __fish_seen_subcommand_from completions" -f -a "install" -d "Auto-detect shell and install completions"

# Config command completions
complete -c adr -n "__fish_use_subcommand; and __fish_seen_subcommand_from config" -f -a "set" -d "Set a configuration key"
complete -c adr -n "__fish_use_subcommand; and __fish_seen_subcommand_from config" -s h -d 'Show help'
complete -c adr -n "__fish_use_subcommand; and __fish_seen_subcommand_from config" -l help -d 'Show help'

# Config set command completions
complete -c adr -n "__fish_seen_subcommand_from config; and not __fish_seen_subcommand_from set" -f -a "set" -d "Set a configuration key"
complete -c adr -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set" -l project -d 'Write to project .adr file'

# Config set argument completions (KEY=VALUE format)
complete -c adr -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set" -f -a "ADR_TAG=" -d 'Default image tag for build and run'
complete -c adr -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set" -f -a "ADR_AGENT=" -d 'Default agent for adr run (no agent argument)'
complete -c adr -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set" -f -a "ADR_MODEL_PI=" -d 'Default model when running pi'
complete -c adr -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set" -f -a "ADR_MODEL_CLAUDE=" -d 'Default model when running claude'
complete -c adr -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set" -f -a "ADR_MODEL_OPENCODE=" -d 'Default model when running opencode'
complete -c adr -n "__fish_seen_subcommand_from config; and __fish_seen_subcommand_from set" -f -a "ADR_MODEL_CODEX=" -d 'Default model when running codex'

# Version command - no additional flags or arguments
complete -c adr -n "__fish_use_subcommand; and __fish_seen_subcommand_from version" -s h -d 'Show help'
complete -c adr -n "__fish_use_subcommand; and __fish_seen_subcommand_from version" -l help -d 'Show help'

# Help command completions
complete -c adr -n "__fish_use_subcommand; and __fish_seen_subcommand_from help" -f -a "build" -d "Build Docker image(s) for an agent"
complete -c adr -n "__fish_use_subcommand; and __fish_seen_subcommand_from help" -f -a "run" -d "Run an agent in an isolated container"
complete -c adr -n "__fish_use_subcommand; and __fish_seen_subcommand_from help" -f -a "update" -d "Rebuild image(s), pulling the latest agent version"
complete -c adr -n "__fish_use_subcommand; and __fish_seen_subcommand_from help" -f -a "status" -d "Show which agent images are built"
complete -c adr -n "__fish_use_subcommand; and __fish_seen_subcommand_from help" -f -a "fix-owner" -d "Fix workspace file ownership (Linux only)"
complete -c adr -n "__fish_use_subcommand; and __fish_seen_subcommand_from help" -f -a "completions" -d "Print shell completion script or install it"
complete -c adr -n "__fish_use_subcommand; and __fish_seen_subcommand_from help" -f -a "config" -d "Show or set configuration defaults"
complete -c adr -n "__fish_use_subcommand; and __fish_seen_subcommand_from help" -f -a "version" -d "Print installed version"
complete -c adr -n "__fish_use_subcommand; and __fish_seen_subcommand_from help" -f -a "help" -d "Print usage information"
