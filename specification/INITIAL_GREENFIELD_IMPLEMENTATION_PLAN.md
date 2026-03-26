# Agent Docker Runner — Implementation Plan

## Overview

A bash-based toolchain that launches coding agents (starting with `pi`) inside
isolated Docker containers. The agent process can only write to a single
host-mounted workspace directory. Configuration (API keys, agent config files,
extensions, skills, …) is supplied via a dedicated config directory.

---

## Repository Structure

```
agent-docker-runner/
  cli/                        # ADR CLI installation (adr executable + commands/)
    adr                       # Main CLI entry point
    main.sh                   # CLI dispatcher
    commands/
      build.sh                # Build agent images
      run.sh                  # Run agents in containers
      update.sh               # Rebuild agents with latest versions
      status.sh               # Show built agent images
      fix-owner.sh            # Fix workspace ownership
      config.sh               # Manage configuration
      completions.sh          # Shell completion scripts
    lib/                      # Shared library functions
  agents/
    pi/
      Dockerfile                # Builds the coding-agent/pi image
      entrypoint.sh             # Container start logic (mode detection, pi invocation)
  config-examples/
    pi/                         # Template: mirrors ~/.pi/ — mount to /home/agent/.pi
      agent/
        settings.json.example   #   default model, theme, etc.
        models.json.example     #   Custom providers/models (see models.json section)
  README.md
```

### `config-examples/` — Purpose

This directory is **documentation and a starting point only**. It is not used
at runtime. Users should copy it (or individual files from it) to a location of
their choice, rename the files (dropping the `.example` suffix), fill in real
values, and then point `adr run` at that directory via `-c / --config`.

The config directory is mounted read-only directly into the container at the
agent's config path (e.g. `~/.pi/` → `/home/agent/.pi` for pi). API keys and
other environment variables must be placed inside the agent's own config files
(e.g. pi reads them from its `settings.json` or the user can set them via the
agent's built-in provider configuration).

Example workflow:
```bash
cp -r config-examples/pi/ ~/.agent-pi-config
# Edit files inside ~/.agent-pi-config/ (add config options to settings.json, etc.)
adr run -c ~/.agent-pi-config pi
```

### `config-examples/pi/agent/settings.json.example` contents

The file `config-examples/pi/agent/settings.json.example` must contain exactly
the following content (serves as a ready-to-copy reference with sensible
defaults pointing at the LM Studio provider defined in `models.json.example`):

```json
{
  "lastChangelogVersion": "0.55.1",
  "defaultProvider": "lmstudio",
  "defaultModel": "qwen/qwen3-coder-next",
  "defaultThinkingLevel": "minimal",
  "theme": "dark",
  "packages": [
  ],
  "enabledModels": [
  ],
  "images": {
    "blockImages": false
  }
}
```

Users should copy this file (dropping the `.example` suffix) and edit
`defaultProvider` / `defaultModel` to match whichever provider they configure
in `models.json` (or a built-in provider such as `anthropic` or `openai`).

---

### `config-examples/pi/agent/models.json.example` contents

Pi supports adding custom providers and models (Ollama, vLLM, LM Studio,
proxies, OpenRouter, Vercel AI Gateway, …) via `~/.pi/agent/models.json`
(i.e. `/home/agent/.pi/agent/models.json` inside the container).

Place your file at `<config-dir>/pi/agent/models.json` — it is covered by the
single `pi/` → `/home/agent/.pi` mount.

The file `config-examples/pi/agent/models.json.example` must contain exactly
the following content (serves as a ready-to-copy reference with two common
provider setups — local Ollama , LM Studio and OpenRouter):

```json
{
  "providers": {
    "lmstudio": {
      "baseUrl": "http://host.docker.internal:1234/v1",
      "api": "openai-completions",
      "apiKey": "not-required",
      "models": [
        {
          "id": "qwen/qwen3-coder-next",
          "name": "qwen3-coder-next (LMStudio)",
          "reasoning": false,
          "input": ["text"],
          "contextWindow": 128000,
          "maxTokens": 16000,
          "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 }
        }
      ]
    },
    "ollama": {
      "baseUrl": "http://host.docker.internal:11434/v1",
      "api": "openai-completions",
      "apiKey": "not-required",
      "models": [
        {
          "id": "llama3.1:8b",
          "name": "Llama 3.1 8B (Local)",
          "reasoning": false,
          "input": ["text"],
          "contextWindow": 128000,
          "maxTokens": 32000,
          "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 }
        }
      ]
    },
    "openrouter": {
      "baseUrl": "https://openrouter.ai/api/v1",
      "apiKey": "OPENROUTER_API_KEY",
      "api": "openai-completions",
      "models": [
        { "id": "anthropic/claude-sonnet-4" }
      ]
    }
  }
}
```


**`host.docker.internal` on Linux**: Docker Desktop (macOS/Windows) provides
this hostname automatically. On Linux it is not set by default. `adr run` must
add `--add-host=host.docker.internal:host-gateway` to the `docker run` command
unconditionally — it is a no-op on macOS/Windows and makes local LLM providers
(Ollama, LM Studio) reachable on Linux without any extra user configuration.

**Hot-reload**: pi reloads `models.json` every time you open `/model` — no container restart required.

---

## `adr build` — CLI Interface

Use `adr build` to build agent images (see [`adr build`](#adr-build--cli-interface) section).

### Usage
```
Usage: adr build [OPTIONS] <agent>

Arguments:
  agent                   Agent to build. Currently supported: pi

Options:
      --tag TAG           Docker image tag to apply. Default: latest.
                          Example: --tag 1.2.3 → builds coding-agent/pi:1.2.3
      --no-cache          Pass --no-cache to docker build.
  -h, --help              Show this help text.
```

### Examples
```bash
# Build with default tag (latest)
adr build pi

# Build with a specific version tag
adr build --tag 1.2.3 pi

# Force a clean rebuild (no layer cache)
adr build --no-cache pi
```

### `adr build` — Script Conventions

All bash scripts (`cli/commands/build.sh`, `cli/commands/run.sh`, `agents/pi/entrypoint.sh`) must follow
these conventions:

```bash
#!/usr/bin/env bash
set -euo pipefail
```

- `set -e`: exit immediately on any command failure.
- `set -u`: treat unset variables as errors.
- `set -o pipefail`: a pipeline fails if any command in it fails.
- Use `#!/usr/bin/env bash` (portable; works on macOS and Linux).
- Print error messages to stderr: `echo "Error: ..." >&2`.
- Exit with a non-zero code on validation failures.

### `adr build` — Internal Logic

```
0. The CLI resolves the agent path to ~/.local/share/adr/agents/<agent>/:
   ADR_AGENT_PATH="${ADR_DATA_DIR}/agents/${AGENT}/"
   (where ADR_DATA_DIR defaults to ~/.local/share/adr)

1. Parse arguments (while loop over $@).
   Collect: AGENT, TAG (default: "latest"), NO_CACHE.

2. Validate:
   - AGENT must be provided and must be in KNOWN_AGENTS=("pi").
     (No filesystem check — the hardcoded list is the single source of truth.)
     
3. Build docker build command:
     docker build
       [ --no-cache ]                 (if --no-cache was given)
       -t coding-agent/<agent>:<tag>
       "${ADR_AGENT_PATH}"

4. Execute the command.
   Exit with docker's exit code.
```

---

## `adr run` — CLI Interface

### Usage
```
Usage: adr run [OPTIONS] <agent>

Arguments:
  agent                   Agent to run. Currently supported: pi

Options:
  -w, --workspace DIR     Host directory mounted as /workspace inside the
                          container. Defaults to current working directory ($PWD).
  -c, --config DIR        (Required) Path to config directory for the agent.
                          Mirrors ~/.<agent>/ — mounted read-only to
                          /home/agent/.<agent> inside the container.
                          Must exist on the host; `adr run` exits with an error otherwise.
      --prompt TEXT        Prompt to pass to the agent. Must be used together
                          with --headless. The agent processes the prompt and exits.
      --headless          Run in headless / non-interactive mode (no TUI).
                          Requires --prompt.
      --shell             Drop into bash instead of running the agent (debug).
      --tag TAG           Docker image tag to use. Default: latest.
                          Example: --tag 1.2.3 → uses coding-agent/pi:1.2.3
  -h, --help              Show this help text.
```

### Examples
```bash
# Interactive TUI session with explicit workspace and config (config is required)
adr run -w ~/projects/myapp -c ~/.agent-pi-config pi

# Headless: give the agent a task, agent exits when done
adr run -w ~/projects/myapp -c ~/.agent-pi-config --headless --prompt "Fix all TypeScript errors in src/" pi

# Note: --prompt has no short form. Pi itself uses -p/--print internally;
# to avoid confusion `adr run` does not expose a -p short flag for --prompt.

# With config directory (API keys + pi config)
adr run -w ~/projects/myapp -c ~/.agent-pi-config pi

# Use a pinned image version
adr run -w ~/projects/myapp --tag 1.2.3 pi

# Debug: open a shell inside the container
adr run -w ~/projects/myapp -c ~/.agent-pi-config --shell pi
```

---

## Config Directory Layout

Passed via `-c / --config` (required). The config directory is mounted
read-only into the container at the agent's own config path. For `pi` that is
`/home/agent/.pi`, so the contents of `<config-dir>` must mirror `~/.pi/`
on the host.

```
<config-dir>/           # For pi: mirrors ~/.pi/ → mounted to /home/agent/.pi:ro
  agent/
    settings.json       # pi agent settings (API keys, default model, …)
    models.json         # Custom providers & models (Ollama, OpenRouter, …)
                        # Pi hot-reloads this when you open /model.
  extensions/           # Pi extensions installed via `pi install npm:…`
                        # Place here to persist across container recreations.
```

When additional agents are added (e.g. opencode), their config directory
mirrors `~/.<agent>/` on the host and is mounted to `/home/agent/.<agent>`
inside the container — the same pattern.

---

## Docker Image: `coding-agent/pi`

### Build command
```bash
# Via adr build (recommended)
adr build pi
adr build --tag 1.2.3 pi

# Manually
docker build -t coding-agent/pi:latest agents/pi/
docker build -t coding-agent/pi:1.2.3 agents/pi/
```

### `agents/pi/Dockerfile` — Key Decisions

| Aspect | Decision | Reason |
|---|---|---|
| Base image | `node:lts-slim` | Small, glibc (needed by some native addons), has npm |
| pi installation | `npm install -g @mariozechner/pi-coding-agent` | Standard npm global install |
| User | Fixed `agent` user with UID **1001**, GID **1001** | Predictable UID for `--user` flag at runtime; avoids collision with the base image's `node` user (UID 1000) |
| Home directory | `/home/agent` | Standard location; pi config lives at `/home/agent/.pi` |
| WORKDIR | `/workspace` | Maps to the mounted host directory |
| ENTRYPOINT | `/entrypoint.sh` | Allows mode detection and argument assembly |

### `agents/pi/Dockerfile` — Skeleton

```dockerfile
FROM node:lts-slim

# Create agent user at UID/GID 1001 (leaves the base image's node user at 1000 intact)
RUN groupadd -g 1001 agent \
 && useradd -m -u 1001 -g 1001 -s /bin/bash agent

# Install pi globally (as root — goes into /usr/local/lib/node_modules)
RUN npm install -g @mariozechner/pi-coding-agent

# Prepare workspace directory (mount point)
RUN mkdir -p /workspace && chown agent:agent /workspace

# Copy entrypoint.
# The build context is agents/pi/ (i.e. `docker build … agents/pi/`), so
# entrypoint.sh must live at agents/pi/entrypoint.sh on the host — COPY
# resolves relative to that context directory, not the repo root.
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER agent
ENV HOME=/home/agent

WORKDIR /workspace

ENTRYPOINT ["/entrypoint.sh"]
# No CMD instruction — intentional. `adr run` communicates all intent to
# entrypoint.sh via environment variables (AGENT_SHELL, AGENT_HEADLESS,
# AGENT_PROMPT), so no default arguments are needed or expected.
```

#### Why a fixed UID 1001?
At runtime, `adr run` always passes `--user 1001:1001` (the pre-created `agent`
user). This means:
- The user **exists in /etc/passwd** → tools that require a real user (e.g.
  shells, some npm scripts) don't complain.
- UID 1001 avoids a conflict with the base image's built-in `node` user
  (UID 1000) — no need to delete or modify it.
- Files written to `/workspace` are owned by UID 1001.
- On **Linux**: the host user should either have UID 1001 or the workspace
  directory must be group/world-writable. Documented in README.
- On **macOS** (Docker Desktop): the VirtioFS/osxfs layer transparently remaps
  ownership, so no issue arises in practice.

---

## `agents/pi/entrypoint.sh` — Logic

```
1. If AGENT_SHELL=1 (set by `adr run` when --shell is given):
     exec bash
     (stops here)

2. Build the pi argument list (bash array, e.g. PI_ARGS=()):
   a. If AGENT_HEADLESS=1 (set by `adr run` when --headless --prompt is given):
        add --print to PI_ARGS
        append "$AGENT_PROMPT" as the final element (double-quoted to preserve
        spaces and special characters)
   b. Otherwise: PI_ARGS stays empty (interactive TUI mode, no extra flags).
      Expanding an empty bash array (`"${PI_ARGS[@]}"`) produces zero
      arguments — this is intentional and correct; do NOT add a length
      guard around the exec.

3. Always execute pi with the constructed arguments:
   ```bash
   exec pi "${PI_ARGS[@]+"${PI_ARGS[@]}"}"
   ```
   (always reaches this line; step 1 is the only early exit)
   The safe expansion is required because `set -u` treats an empty array as
   unbound in some bash versions — this idiom expands to zero arguments when
   the array is empty and works correctly when it is non-empty.
```

`adr run` communicates intent to the entrypoint via environment variables
(`AGENT_SHELL`, `AGENT_HEADLESS`, `AGENT_PROMPT`) rather than command-line
args, to keep the entrypoint simple and avoid argument-parsing conflicts with
pi's own flags.

---

## `adr run` — Internal Logic (step by step)

```
0a. Capture the invocation directory (before changing into the CLI's working context):
    INVOKE_DIR=$PWD
    This must happen as the very first line — before any path resolution — so that the
    default WORKSPACE resolves to the directory the user was in when they
    called `adr run`, not the CLI's own installation directory.

0b. Resolve ADR installation paths:
    ADR_CLI_DIR="${HOME}/.local/share/adr/cli" (or from environment)
    Ensures commands like build.sh and run.sh are loaded from the correct location.

1. Parse arguments (while loop over $@).
   Collect: AGENT, WORKSPACE (default: $INVOKE_DIR — captured in step 0a),
            CONFIG_DIR, PROMPT, HEADLESS, SHELL_MODE, TAG (default: "latest").

2. Validate:
   - AGENT must be provided and must be in KNOWN_AGENTS=("pi").
     (No filesystem check — the hardcoded list is the single source of truth.)
   - WORKSPACE must exist as a directory (fail with a clear error if not;
     prevents typos silently creating dirs).
   - CONFIG_DIR must be provided — `-c / --config` is required (error if omitted).
   - CONFIG_DIR must exist as a directory on the host (error if not).
   - If --headless is set, --prompt must also be set (error otherwise).
   - If --prompt is set, --headless must also be set (error otherwise).
   - --shell and --headless/--prompt are mutually exclusive (error otherwise).
   - Corresponding Docker image (coding-agent/<agent>:<tag>) must exist
     locally (docker image inspect). If not, print helpful error with the
     build command.

3. Resolve absolute paths:
   - WORKSPACE=$(cd "$WORKSPACE" && pwd)
   - CONFIG_DIR=$(cd "$CONFIG_DIR" && pwd)  (always set — required flag)

4. Determine TTY flags (use a bash array to avoid quoting issues):
   - If HEADLESS:               TTY_FLAGS=(-i)        # no TTY needed
   - Else (SHELL_MODE or interactive TUI mode): TTY_FLAGS=(-i -t)  # allocate a TTY

5. Build the docker run command using a bash array (avoids quoting/splitting
   issues with paths that contain spaces):

   CMD=(docker run --rm)
   CMD+=("${TTY_FLAGS[@]}")
   CMD+=(--user 1001:1001)
   CMD+=(--cap-drop ALL)
   CMD+=(--security-opt no-new-privileges)
   CMD+=(--network bridge)                              # explicit; gives full outbound access
   CMD+=(--add-host=host.docker.internal:host-gateway)  # makes host reachable on Linux (no-op on macOS)
   CMD+=(-v "$WORKSPACE:/workspace")
   CMD+=(-v "$CONFIG_DIR:/home/agent/.$AGENT:ro")       # always added; -c is required, existence validated in step 2
   [ --shell ]    → CMD+=(--env AGENT_SHELL=1)
   [ --headless ] → CMD+=(--env AGENT_HEADLESS=1)
   [ --prompt ]   → CMD+=(--env "AGENT_PROMPT=$PROMPT")

   CMD+=(coding-agent/$AGENT:$TAG)    ← IMAGE, always last

6. Execute the command:
   exec "${CMD[@]}"
   (replaces the shell process; exit code propagates automatically)
```

---

## Security Posture

| Control              | Value                                                                                     |
| ----------------------| -------------------------------------------------------------------------------------------|
| Network              | Full outbound access (agent needs to call AI APIs)                                        |
| Filesystem           | Only `/workspace` is writable from the host's perspective                                 |
| Capabilities         | `--cap-drop ALL`                                                                          |
| Privilege escalation | `--security-opt no-new-privileges`                                                        |
| Container filesystem (non-workspace) | Writable by the `agent` user (UID 1001, not root) — pi writes npm cache, temp files, and session data inside the container; all ephemeral and discarded when the container exits |
| Secrets              | Passed via mounted config directory (`:ro`), never written to image layers                |
| Config mounts        | Always `:ro` (read-only)                                                                  |

---

## Pi-Specific Behaviour Notes

From `pi --help`:

| pi flag          | When used by entrypoint                                   |
| ------------------| -----------------------------------------------------------|
| `--print` / `-p` | Headless mode: process prompt and exit                    |
| Positional arg   | The prompt text, appended last when `AGENT_PROMPT` is set |

Pi reads config from `~/.pi/` which inside the container resolves to
`/home/agent/.pi` — this is exactly what we mount from `<config-dir>/pi/`.
The `<config-dir>/pi/` directory is intended to be a drop-in mirror of `~/.pi/`
on the host, so users can copy or symlink their existing pi config directly.

API keys and provider credentials are configured inside the agent's own config
files (e.g. pi's `settings.json`) located in `<config-dir>/` — which is
mounted to `/home/agent/.pi` inside the container. No separate env-file is
used; all configuration flows through the mounted config directory.

---

## Extensibility: Adding a New Agent

1. Create `agents/<name>/Dockerfile` — install the agent, create `agent` user
   at UID 1001 (GID 1001), set WORKDIR to `/workspace`, set ENTRYPOINT.
2. Create `agents/<name>/entrypoint.sh` — translate `AGENT_HEADLESS`,
   `AGENT_PROMPT`, `AGENT_SHELL` env vars into the agent's own CLI flags.
3. Add the agent name to the `KNOWN_AGENTS` list in **both** `adr build` and
   `adr run` (one-line change in each).
4. Document the config directory layout in `README.md` and add an example to
   `config-examples/<name>/` (mirroring `~/.<name>/` on the host).
   The config directory is passed directly as `-c <dir>` and mounted to
   `/home/agent/.<name>` — no structural change to `adr run` is needed.

`adr run` itself needs **no structural changes** — it is agent-agnostic by
design. The image name (`coding-agent/<name>:<tag>`) and config subdir
(`<config-dir>/<name>/` → `/home/agent/.<name>`) are derived from the agent
name automatically.

---

## README Content Plan

Goal: enable a user to go from zero to a running agent session in under five
minutes, then find everything they need for day-to-day use without leaving the
README.

---

### 1. Header / one-line description
> "Run pi (and other coding agents) inside isolated Docker containers — one
> command to launch, one directory to share."

---

### 2. Prerequisites
- Docker installed and running (link to docs.docker.com/get-docker/).
- The agent image must be built first (see section 3).
- No other dependencies — bash is all you need on the host.

---

### 3. Quick start (copy-pasteable)
Show the absolute minimum to get a working session.

```bash
# 1. Clone and build the image
git clone <repo-url> agent-docker-runner
cd agent-docker-runner
adr build pi

# 2. Create a config directory from the example (mirrors ~/.pi/)
cp -r config-examples/pi/ ~/.agent-pi-config
# Edit ~/.agent-pi-config/agent/settings.json — add your API key(s)

# 3. Launch an interactive session in the current directory
adr run -c ~/.agent-pi-config pi
```

Add a one-line note: "Your current directory is mounted as /workspace — the
agent can read and write files there."

---

### 4. Config directory
A config directory is **required** — `adr run` will error if `-c` is not
provided or if the directory does not exist. It mirrors `~/.<agent>/` on the
host and is mounted read-only to `/home/agent/.<agent>` inside the container.

(Setup steps are shown in Quick Start above.)

Show the annotated layout of `<config-dir>/` (for pi, mirrors `~/.pi/`):
```
~/.agent-pi-config/     # mounted to /home/agent/.pi:ro
  agent/
    settings.json       # default model, and other pi settings
    models.json         # Custom providers/models (Ollama, OpenRouter, …)
  extensions/           # Pi extensions (pi install npm:…) — placed here so
                        # they persist across container recreations.
```

Note: `agent/models.json` and `extensions/` are optional. Only
`agent/settings.json` is needed for basic use.

---

### 5. Common usage examples
Concrete, runnable examples covering the main use cases:

```bash
# Interactive TUI session with a specific workspace
adr run -w ~/projects/myapp -c ~/.agent-pi-config pi

# Headless: give the agent a one-shot task and exit
adr run -w ~/projects/myapp -c ~/.agent-pi-config \
  --headless --prompt "Write tests for all untested functions in src/" pi

# Use a pinned image version
adr run -w ~/projects/myapp -c ~/.agent-pi-config --tag 1.2.3 pi

# Debug: drop into a shell inside the container
adr run -w ~/projects/myapp -c ~/.agent-pi-config --shell pi
```

---

### 6. Building images
```bash
# Build latest
adr build pi

# Build a specific version tag
adr build --tag 1.2.3 pi

# Force a clean rebuild
adr build --no-cache pi
```

Note: the image is named `coding-agent/pi:<tag>` and stays local — nothing is
pushed to a registry.

---

### 7. Custom models and local LLMs
Briefly explain `models.json`: copy
`config-examples/pi/agent/models.json.example` to
`~/.agent-pi-config/agent/models.json`, uncomment the provider you want
(Ollama, OpenRouter, …), and run as normal. Pi hot-reloads the file when you
open `/model` — no container restart needed.

---

### 8. Full CLI reference
Reproduce the Usage blocks verbatim for both `adr run` and `adr build`.

---

### 9. Platform notes

**Linux — file ownership:**
The container runs as UID 1001. Files the agent creates in `/workspace` will
be owned by UID 1001 on the host. If your host user has a different UID, make
the workspace directory group/world-writable:
```bash
chmod o+w ~/projects/myapp
```
Or ensure your host user has UID 1001 if that matches your setup.

**macOS — no special action needed:**
Docker Desktop's VirtioFS layer remaps file ownership transparently.

---

### 10. Security model (brief)
One short paragraph + the security table from the Security Posture section.
Reassure the user that the agent cannot touch anything outside the workspace
directory on the host, cannot escalate privileges, and secrets are never baked
into images.

---

### 11. Adding more agents
Point to the Extensibility section of the implementation plan (or repeat the
4-step summary inline). Keep it short — this is a power-user note.
