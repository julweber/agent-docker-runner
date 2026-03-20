---
name: agent-docker-runner-assistant
description: Assistant for the agent-docker-runner repository. Knows the project purpose, how to build and run agents in Docker containers, all CLI scripts (run.sh, build.sh, fix_owner.sh, implement-feature.sh, task-monitor.sh, session-monitor.sh, setup.sh, link-skills.sh), project conventions, and the spec/task workflow. Use when working in or contributing to this repository.
---

# Agent Docker Runner Assistant

This project runs coding agents (pi, opencode, claude) inside isolated Docker containers — one command to launch, one directory to share.

## Project Layout

```
agent-docker-runner/
├── agents/           # Per-agent Dockerfiles and entrypoints
│   ├── claude/
│   ├── opencode/
│   └── pi/
├── config-examples/  # Example configs for each agent
├── scripts/          # Utility and workflow scripts
├── skills/           # Agent skills (this repo ships its own skills)
├── specification/    # Project specs (not runtime code)
├── tasks/            # Generated task lists per feature
├── build.sh          # Build a Docker image for an agent
├── run.sh            # Run an agent inside Docker
└── fix_owner.sh      # Fix Linux file-ownership issues
```

## Core Scripts

### `./build.sh <agent> [OPTIONS]`
Builds a Docker image named `coding-agent/<agent>:<tag>`.

```bash
./build.sh pi                    # Build latest
./build.sh claude --tag 1.2.3   # Pin a version
./build.sh opencode --no-cache  # Force clean rebuild
```

Agents: `pi`, `opencode`, `claude`. Add new agents by creating `agents/<name>/Dockerfile` + `entrypoint.sh` and registering the name in `KNOWN_AGENTS` in both `build.sh` and `run.sh`.

### `./run.sh <agent> [OPTIONS]`
Runs an agent container. Mounts current dir (or `-w DIR`) as `/workspace`.

```bash
./run.sh pi                                        # Interactive TUI, cwd as workspace
./run.sh -w ~/projects/myapp opencode              # Specify workspace
./run.sh --prompt "Write tests for src/" claude    # Headless one-shot task
./run.sh --model anthropic/claude-sonnet-4 pi      # Select model
./run.sh --tag 1.2.3 claude                        # Use pinned image
./run.sh --shell claude                            # Drop into bash for debugging
./run.sh -c ~/custom-config opencode               # Override config dir
```

Key flags:
| Flag | Default | Notes |
|---|---|---|
| `-w DIR` | `$PWD` | Host workspace dir, mounted as `/workspace` |
| `-c DIR` | agent default (`~/.pi/`, `~/.config/opencode/`, `~/.claude/`) | Config dir (read-only, staged into container) |
| `--prompt TEXT` | — | Implies `--headless` |
| `--headless` | false | Non-interactive mode |
| `--shell` | false | Debug: open bash instead of agent |
| `--tag TAG` | `latest` | Docker image tag |
| `--model MODEL` | agent default | `provider/model` for pi/opencode; alias/name for claude |
| `--config-file FILE` | `~/.claude.json` | Claude only: pre-approves API key |

### `./fix_owner.sh [directory]`
Fixes file ownership on Linux when the container (UID 1000) creates files your host user can't access.

```bash
./fix_owner.sh            # Fix current directory
./fix_owner.sh /path/dir  # Fix specific directory
```

## Config & Security

- Config dirs are **staged** (world-readable temp copy) before the container starts, because `--cap-drop ALL` prevents root from reading files owned by other users. The entrypoint copies them as the `node` user.
- `--cap-drop ALL` + `--cap-add SETUID,SETGID` + `--security-opt no-new-privileges`
- Only `/workspace` is writable from the host; everything else is ephemeral.
- Claude requires **two** config files: `~/.claude/settings.json` (API key) and `~/.claude.json` (pre-approved keys list — must contain the exact same key).

## Adding a New Agent

1. `agents/<name>/Dockerfile` — install agent, create non-root user, `WORKDIR /workspace`, `ENTRYPOINT`
2. `agents/<name>/entrypoint.sh` — handle env vars: `AGENT_HEADLESS`, `AGENT_PROMPT`, `AGENT_SHELL`, `AGENT_PROVIDER`, `AGENT_MODEL`
3. Add name to `KNOWN_AGENTS` in `build.sh` and `run.sh` (one-line change each)
4. Add config example under `config-examples/<name>/`
5. Document in `README.md`

## Platform Notes

- **Linux**: Container runs as UID 1000 (`node`). If your UID differs, use `chmod o+w <workspace>` or `./fix_owner.sh`.
- **macOS**: Docker Desktop VirtioFS handles ownership transparently — no action needed.
- **Local LLMs**: `host.docker.internal` is pre-configured on Linux via `--add-host=host.docker.internal:host-gateway` so Ollama/LM Studio endpoints work without extra config.
