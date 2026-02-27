# Agent Docker Runner

Run coding agents (pi, opencode, claude) inside isolated Docker containers — one
command to launch, one directory to share.

---

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) installed and running.
- The agent image must be built first (see [Building images](#building-images)).
- No other dependencies — bash is all you need on the host.

---

## Supported Agents

| Agent | Description | Config dir |
|---|---|---|
| `pi` | [pi coding agent](https://github.com/mariozechner/pi-coding-agent) | `~/.pi/` |
| `opencode` | [opencode](https://opencode.ai) | `~/.config/opencode/` |
| `claude` | [Claude Code](https://claude.ai/code) by Anthropic | `~/.claude/` |

---

## Quick Start

### pi

```bash
# 1. Build the image
./build.sh pi

# 2. Set up ~/.pi/ (if you don't already have one)
cp -r config-examples/pi/ ~/.pi
# Edit ~/.pi/agent/settings.json — add your API key(s) / configure provider

# 3. Launch an interactive session in the current directory
./run.sh pi
```

### opencode

```bash
# 1. Build the image
./build.sh opencode

# 2. Set up ~/.config/opencode/ (if you don't already have one)
mkdir -p ~/.config/opencode
cp config-examples/opencode/opencode.json.example ~/.config/opencode/opencode.json
# Edit ~/.config/opencode/opencode.json — add your API key(s) / configure provider

# 3. Launch an interactive session in the current directory
./run.sh opencode
```

### claude

```bash
# 1. Build the image
./build.sh claude

# 2. Set up ~/.claude/ (if you don't already have one)
mkdir -p ~/.claude
cp config-examples/claude/settings.json.example ~/.claude/settings.json
# Edit ~/.claude/settings.json — add your Anthropic API key under "env"

# 3. Set up ~/.claude.json — pre-approves the API key so Claude Code doesn't prompt
cp config-examples/claude/.claude.json.example ~/.claude.json
# Edit ~/.claude.json — replace the placeholder with your real key
# (must match the key in settings.json exactly)

# 4. Launch an interactive session in the current directory
./run.sh claude
```

Your current directory is mounted as `/workspace` — the agent can read and write files there.

> **Already using these agents on the host?** Your existing config at `~/.pi/`,
> `~/.config/opencode/`, or `~/.claude/` is picked up automatically — just
> build the image and run.

---

## Config Directories

Each agent reads its config from its native config home on the host. Use `-c`
to override with a different directory.

| Agent | Default config path |
|---|---|
| `pi` | `~/.pi/` |
| `opencode` | `~/.config/opencode/` |
| `claude` | `~/.claude/` |

### pi (`~/.pi/`)

```
~/.pi/
  agent/
    settings.json          # Default model, theme, and other pi settings
    models.json            # Custom providers/models (Ollama, LM Studio, OpenRouter, …)
  extensions/              # Pi extensions — persist across container recreations
```

> `agent/models.json` and `extensions/` are optional. Only `agent/settings.json`
> is needed for basic use.

### opencode (`~/.config/opencode/`)

```
~/.config/opencode/
  opencode.json            # Provider config, model definitions, API keys
```

### claude (`~/.claude/` + `~/.claude.json`)

Claude Code uses **two** config files:

| File | Location | Purpose |
|---|---|---|
| `settings.json` | `~/.claude/` | Claude Code settings — API key, env vars |
| `.claude.json` | `~/.claude.json` | Pre-approves the API key |

```
~/.claude/
  settings.json            # Claude Code settings — use the "env" block for your API key

~/.claude.json             # Pre-approves the API key (run.sh reads this automatically)
```

**`settings.json`** minimal example (see `config-examples/claude/settings.json.example`):
```json
{
  "env": {
    "ANTHROPIC_API_KEY": "sk-ant-api03-..."
  }
}
```

**`~/.claude.json`** minimal example (see `config-examples/claude/.claude.json.example`):
```json
{
  "customApiKeyResponses": {
    "approved": [
      "sk-ant-api03-YOUR-FULL-API-KEY-HERE"
    ],
    "rejected": []
  }
}
```

The `approved` list must contain the **full API key** — the same value set in
`settings.json`. This tells Claude Code the key has already been accepted and
prevents the interactive *"Do you want to use this API key?"* prompt that would
block container startup, especially in headless mode.

`run.sh` reads `~/.claude.json` by default. Use `--config-file` to point to a
different location.

### How Config Works

The config directory is staged into a temporary world-readable location (to work around
`--cap-drop ALL` blocking reads from the root process). The entrypoint then copies it into
the agent's config home inside the container and drops privileges before launching the agent.

---

## Common Usage Examples

```bash
# Interactive TUI session with a specific workspace
./run.sh -w ~/projects/myapp pi
./run.sh -w ~/projects/myapp opencode
./run.sh -w ~/projects/myapp claude

# Headless: give the agent a one-shot task and exit (--prompt implies --headless)
./run.sh -w ~/projects/myapp \
  --prompt "Write tests for all untested functions in src/" pi

./run.sh -w ~/projects/myapp \
  --prompt "Write tests for all untested functions in src/" opencode

./run.sh -w ~/projects/myapp \
  --prompt "Write tests for all untested functions in src/" claude

# Use a specific model (for pi, "provider/model" selects both)
./run.sh -w ~/projects/myapp --model anthropic/claude-sonnet-4 pi
./run.sh -w ~/projects/myapp --model anthropic/claude-sonnet-4 opencode
./run.sh -w ~/projects/myapp --model sonnet claude

# Use a pinned image version
./run.sh -w ~/projects/myapp --tag 1.2.3 claude

# Debug: drop into a shell inside the container
./run.sh -w ~/projects/myapp --shell claude

# Override config directory (e.g. for a separate project-specific config)
./run.sh -w ~/projects/myapp -c ~/my-custom-config claude
```

---

## Building Images

```bash
# Build latest
./build.sh pi
./build.sh opencode
./build.sh claude

# Build a specific version tag
./build.sh --tag 1.2.3 claude

# Force a clean rebuild
./build.sh --no-cache claude
```

Images are named `coding-agent/<agent>:<tag>` and stay local — nothing is pushed to a registry.

---

## Custom Models and Local LLMs

### pi

Copy `config-examples/pi/agent/models.json.example` to
`~/.pi/agent/models.json`, configure the provider you want
(Ollama, LM Studio, OpenRouter, …), and run as normal.

Pi hot-reloads `models.json` when you open `/model` — no container restart needed.

### opencode

Copy `config-examples/opencode/opencode.json.example` to
`~/.config/opencode/opencode.json` and configure the providers and models
you want. Pass `--model provider/model` to select one at runtime.

### claude

Claude Code connects to Anthropic's API by default. Set `ANTHROPIC_API_KEY` in
`~/.claude/settings.json` under the `"env"` key, and add the same
key to the `customApiKeyResponses.approved` list in
`~/.claude.json`. Pass `--model` with a short alias
(`sonnet`, `opus`) or a full model name (`claude-sonnet-4-6`).

`host.docker.internal` is automatically configured for Linux (via
`--add-host=host.docker.internal:host-gateway`) so local LLM servers (Ollama,
LM Studio) are reachable without extra setup on any platform.

---

## Full CLI Reference

### `run.sh`

```
Usage: ./run.sh [OPTIONS] <agent>

Arguments:
  agent                   Agent to run. Currently supported: pi, opencode, claude

Options:
  -w, --workspace DIR     Host directory mounted as /workspace inside the
                          container. Defaults to current working directory ($PWD).
  -c, --config DIR        Path to config directory for the agent.
                          Defaults to the agent's native config home:
                            pi:       ~/.pi/
                            opencode: ~/.config/opencode/
                            claude:   ~/.claude/
                          Mounted read-only to a staging path and copied into
                          the agent's config directory at container startup.
                          Must exist on the host.
      --config-file FILE  Path to a .claude.json file copied to ~/.claude.json
                          inside the container.  Pre-approves the API key so
                          Claude Code does not prompt on startup.
                          Defaults to ~/.claude.json on the host.
                          Only accepted for the claude agent.
      --prompt TEXT       Prompt to pass to the agent. Implies --headless.
      --headless          Run in headless / non-interactive mode (no TUI).
                          Requires --prompt. Implied by --prompt.
      --shell             Drop into bash instead of running the agent (debug).
      --tag TAG           Docker image tag to use. Default: latest.
      --model MODEL       Model to use.
                          For pi, use "provider/model" to also select the
                          provider (e.g. anthropic/claude-sonnet-4). The part
                          before the first "/" is the provider; everything after
                          is the model ID (e.g. evo/qwen/qwen3-coder-next).
                          opencode: "provider/model" format (e.g. anthropic/claude-sonnet-4).
                          claude:   alias (e.g. sonnet, opus) or full name (e.g. claude-sonnet-4-6).
  -h, --help              Show this help text.
```

### `build.sh`

```
Usage: ./build.sh [OPTIONS] <agent>

Arguments:
  agent                   Agent to build. Currently supported: pi, opencode, claude

Options:
      --tag TAG           Docker image tag to apply. Default: latest.
                          Example: --tag 1.2.3 -> builds coding-agent/claude:1.2.3
      --no-cache          Pass --no-cache to docker build.
  -h, --help              Show this help text.
```

### `fix_owner.sh`

```
Usage: ./fix_owner.sh [directory]

Changes ownership of all files in a directory recursively to the current user.

Arguments:
  directory               Target directory (defaults to current directory)

This script is useful on Linux when the container runs as UID 1000 and creates
files that are owned by that UID on the host. If your host user has a different
UID, use this script to fix ownership.
```

---

## Platform Notes

### Linux — file ownership

The container runs as the `node` user (UID 1000). Files the agent creates in `/workspace`
will be owned by UID 1000 on the host. If your host user has a different UID, make the
workspace directory group/world-writable:

```bash
chmod o+w ~/projects/myapp
```

Alternatively, use the `fix_owner.sh` script to change ownership of all files in a directory
recursively to your current user:

```bash
# Fix ownership in current directory
./fix_owner.sh

# Or specify a target directory
./fix_owner.sh /path/to/workspace
```

### macOS — no special action needed

Docker Desktop's VirtioFS layer remaps file ownership transparently.

---

## Security Model

Each agent runs in an isolated container with minimal privileges. It can only read and write
files inside `/workspace` on the host — nothing else is accessible. Secrets (API keys, config)
are staged from your config directory and are never baked into Docker image layers.

| Control | Value |
|---|---|
| Network | Full outbound access (agent needs to call AI APIs) |
| Filesystem | Only `/workspace` is writable from the host's perspective |
| Capabilities | `--cap-drop ALL` with `--cap-add SETUID,SETGID` for privilege dropping |
| Privilege escalation | `--security-opt no-new-privileges` |
| Container filesystem (non-workspace) | Writable by `node` user (UID 1000, not root) — ephemeral, discarded on exit |
| Secrets | Staged from host config directory, copied to container at startup |
| Claude permissions | `--dangerously-skip-permissions` is always passed — the container is the sandbox |

### Why staging is needed

Because `--cap-drop ALL` removes all capabilities including `CAP_DAC_OVERRIDE`, the root
process cannot read files from a read-only mount if they're owned by a different user.
The solution: stage config to a temporary world-readable location, then copy it as the
non-root `node` user (who owns the agent's config home inside the container).

---

## Adding More Agents

1. Create `agents/<name>/Dockerfile` — install the agent, create a non-root user,
   set WORKDIR to `/workspace`, set ENTRYPOINT.
2. Create `agents/<name>/entrypoint.sh` — translate `AGENT_HEADLESS`,
   `AGENT_PROMPT`, `AGENT_SHELL`, `AGENT_PROVIDER`, `AGENT_MODEL` env vars into
   the agent's own CLI flags.
3. Add the agent name to `KNOWN_AGENTS` in **both** `build.sh` and `run.sh`
   (one-line change in each).
4. Document the config layout in `README.md` and add an example under
   `config-examples/<name>/`.

`run.sh` needs no structural changes — it is agent-agnostic by design.

---

## Project Structure

```
agent-docker-runner/
├── agents/               # Agent-specific Dockerfiles and entrypoints
│   ├── claude/
│   │   ├── Dockerfile
│   │   └── entrypoint.sh
│   ├── opencode/
│   │   ├── Dockerfile
│   │   └── entrypoint.sh
│   └── pi/
│       ├── Dockerfile
│       └── entrypoint.sh
├── config-examples/      # Example configuration files for each agent
│   ├── claude/
│   ├── opencode/
│   └── pi/
├── build.sh              # Script to build agent images
├── run.sh                # Script to run agents in containers
├── fix_owner.sh          # Script to fix file ownership on Linux
└── specification/        # Project specifications (not used)
```
