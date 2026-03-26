---
name: agent-docker-runner-assistant
description: Assistant for the agent-docker-runner repository. Knows the project purpose, how to build and run agents in Docker containers via the `adr` CLI (build, run, update, status, fix-owner, completions, config), all utility scripts (implement-feature.sh, task-monitor.sh, session-monitor.sh, setup.sh, link-skills.sh), project conventions, and the spec/task workflow. Use when working in or contributing to this repository.
---

# Agent Docker Runner Assistant

This project runs coding agents (pi, opencode, claude, codex) inside isolated Docker containers via the `adr` CLI — a unified command-line interface for building, running, and managing agent containers.

## Project Layout

```
agent-docker-runner/
├── agents/           # Per-agent Dockerfiles and entrypoints
│   ├── claude/
│   ├── codex/
│   ├── opencode/
│   └── pi/
├── cli/              # ADR CLI runtime (installed to ~/.local/share/adr)
│   ├── adr           # Main CLI executable
│   ├── main.sh       # Command dispatcher
│   ├── lib/          # Shared libraries (agents, config, docker)
│   └── commands/     # Command implementations (build, run, status, etc.)
├── config-examples/  # Example configs for each agent
├── scripts/          # Utility and workflow scripts
├── skills/           # Agent skills (this repo ships its own skills)
├── specification/    # Project specs (not runtime code)
├── tasks/            # Generated task lists per feature
├── bin/spec          # Spec-driven development CLI
├── install.sh        # Install adr to ~/.local/bin
└── VERSION           # Version file for installed adr
```

## ADR CLI Commands

The `adr` command provides a unified interface for managing agent containers. After installation via `./install.sh`, it's available at `~/.local/bin/adr`.

### `adr build [agent] [OPTIONS]`
Builds a Docker image named `coding-agent/<agent>:<tag>`.

```bash
adr build pi                    # Build latest
adr build claude --tag 1.2.3   # Pin a version
adr build opencode --no-cache  # Force clean rebuild
adr build                       # Interactive: prompts to build all agents
```

**Options:**
| Option | Default | Notes |
|---|---|---|
| `--tag TAG` | `latest` (from config) | Custom image tag |
| `--no-cache` | false | Build without using cached layers |
| `-h, --help` | — | Show help message |

**Agents:** `pi`, `opencode`, `claude`, `codex`. Add new agents by creating `agents/<name>/Dockerfile` + `entrypoint.sh` and adding the name to `KNOWN_AGENTS` in `cli/lib/agents.sh`.

### `adr run [agent] [OPTIONS]`
Runs an agent container. Mounts current dir (or `--workspace DIR`) as `/workspace`.

```bash
adr run pi                                        # Interactive TUI, cwd as workspace
adr run --workspace ~/projects/myapp opencode     # Specify workspace
adr run --prompt "Write tests for src/" claude    # Headless one-shot task
adr run --model anthropic/claude-sonnet-4 pi      # Select model
adr run --tag 1.2.3 claude                        # Use pinned image
adr run --shell claude                            # Drop into bash for debugging
adr run --config ~/custom-config opencode         # Override config dir
```

**Options:**
| Option | Default | Notes |
|---|---|---|
| `--workspace DIR` or `-w DIR` | `$PWD` | Host workspace dir, mounted as `/workspace` |
| `--config DIR` or `-c DIR` | agent default (`~/.pi/`, `~/.config/opencode/`, `~/.claude/`, `~/.codex/`) | Config dir (read-only, staged into container) |
| `--config-file FILE` | `~/.claude.json` | Claude only: path to pre-approved keys file |
| `--prompt TEXT` | — | Implies `--headless` |
| `--headless` | false | Non-interactive mode; requires `--prompt` |
| `--shell` | false | Debug: open bash instead of agent |
| `--tag TAG` | `latest` (from config) | Docker image tag |
| `--model MODEL` | agent default | `provider/model` for pi/opencode/codex; alias/name for claude |

If no agent is specified, uses `ADR_AGENT` from `.adr` project file or global config (`~/.config/adr/config`). Run `adr status` to see available agents.

### `adr update [agent]`
Rebuilds images, pulling the latest agent version.

```bash
adr update pi              # Rebuild single agent with fresh layers
adr update                 # Interactive: rebuilds all locally built images
```

**Options:**
| Option | Default | Notes |
|---|---|---|
| `--no-cache` | true | Rebuild with fresh layers (default behavior) |
| `-h, --help` | — | Show help message |

If no agent is specified, rebuilds all images that are already present locally.

### `adr status`
Shows which agent images are built and their details.

```bash
adr status
```

Displays a table with Agent, Image, Tag, Size, and Built time for each known agent (pi, opencode, claude, codex).

### `adr fix-owner [dir]`
Fixes file ownership on Linux when the container (UID 1000) creates files your host user can't access.

```bash
adr fix-owner              # Fix current directory
adr fix-owner /path/dir    # Fix specific directory
```

Changes ownership of all files in the target directory to the current user's UID:GID.

### `adr completions <shell> | install`
Prints shell completion scripts or auto-installs them.

```bash
adr completions bash       # Print bash completion script
adr completions zsh        # Print zsh completion script
adr completions fish       # Print fish completion script
adr completions install    # Auto-detect shell and install completions
```

**Arguments:** `bash`, `zsh`, `fish`, or `install` for auto-install.

### `adr config [subcommand]`
Shows or sets configuration defaults.

```bash
adr config                      # Show effective merged configuration
adr config set ADR_AGENT=pi     # Set global config (~/.config/adr/config)
adr config set --project ADR_TAG=v2  # Set project config (.adr file)
```

**Subcommands:**
| Subcommand | Description |
|---|---|
| (none) or `show` | Print effective merged configuration |
| `set KEY=VALUE` | Set a key in global config |
| `set --project KEY=VALUE` | Set a key in project `.adr` file |

**Config Keys:** `ADR_TAG`, `ADR_AGENT`, `ADR_MODEL_PI`, `ADR_MODEL_CLAUDE`, `ADR_MODEL_OPENCODE`, `ADR_MODEL_CODEX`.

### `adr version`
Prints the installed version.

```bash
adr version
```

Reads from `~/.local/share/adr/VERSION`.

## Config & Security

- **Config locations:**
  - Global config: `~/.config/adr/config` (user defaults)
  - Project config: `.adr` in project root (overrides global)
  - Builtin defaults: lowest priority (e.g., `ADR_TAG=latest`)

- **Staged configs:** Config dirs are **staged** (world-readable temp copy) before the container starts, because `--cap-drop ALL` prevents root from reading files owned by other users. The entrypoint copies them as the `node` user.

- **Security flags:** `--cap-drop ALL` + `--cap-add SETUID,SETGID` + `--security-opt no-new-privileges`

- **Workspace access:** Only `/workspace` is writable from the host; everything else is ephemeral.

- **Claude requirements:** Claude Code requires **two** config files: `~/.claude/settings.json` (API key) and `~/.claude.json` (pre-approved keys list — must contain the exact same key). Use `--config-file` to specify the pre-approved keys file location.

## Adding a New Agent

1. `agents/<name>/Dockerfile` — install agent, create non-root user, `WORKDIR /workspace`, `ENTRYPOINT`
2. `agents/<name>/entrypoint.sh` — handle env vars: `AGENT_HEADLESS`, `AGENT_PROMPT`, `AGENT_SHELL`, `AGENT_PROVIDER`, `AGENT_MODEL`
3. Add name to `KNOWN_AGENTS` array in `cli/lib/agents.sh` (one-line change)
4. Add config example under `config-examples/<name>/`
5. Document in `README.md`

The ADR CLI automatically discovers new agents via the `KNOWN_AGENTS` array — no manual changes to individual commands needed.

## Platform Notes

- **Linux:** Container runs as UID 1000 (`node`). If your UID differs, use `chmod o+w <workspace>` or `adr fix-owner`.
- **macOS:** Docker Desktop VirtioFS handles ownership transparently — no action needed.
- **Local LLMs:** `host.docker.internal` is pre-configured on Linux via `--add-host=host.docker.internal:host-gateway` so Ollama/LM Studio endpoints work without extra config.
