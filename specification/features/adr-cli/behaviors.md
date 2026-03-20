# ADR CLI - Behaviors

This document defines the behavioral requirements for `adr`, the installable
command-line interface for Agent Docker Runner.

## Overview

`adr` replaces the need to reference `./build.sh` and `./run.sh` from a cloned
repository. It is a single globally-installed executable that a developer can
call from any directory, any project, any terminal session — without knowing or
caring where the repository lives on disk.

The goal is to make running containerized coding agents as ergonomic as running
them directly, while preserving the full security model and all existing
options.

---

## Behavior 1: Installation via `install.sh`

**Description**: A single script installs `adr` onto the host system and makes
it available in `PATH`. The script is safe to re-run as an upgrade mechanism.

### Happy Path

- User runs `./install.sh` from a local clone of the repository (or pipes from
  `curl`)
- Script copies `cli/adr` to `~/.local/bin/adr` and sets execute permissions
- Script copies `agents/` tree to `~/.local/share/adr/agents/`
- Script copies `config-examples/` to `~/.local/share/adr/config-examples/`
- Script copies shell completion files to `~/.local/share/adr/completions/`
- Script writes the repository's current version string to
  `~/.local/share/adr/VERSION`
- Script checks whether `~/.local/bin` is on `PATH` and prints a one-line
  reminder if it is not
- On completion, script prints confirmation: `adr installed. Run 'adr status'
  to check your agents.`
- User opens a new shell and runs `adr --help` → help text is displayed

### Error Cases

- `~/.local/bin` or `~/.local/share/adr` cannot be created (permissions) →
  clear error message, non-zero exit, no partial installation
- `agents/` or `cli/adr` source file missing from the repository (incomplete
  clone) → error naming the missing path, non-zero exit

### Edge Cases

- Re-running `install.sh` over an existing installation → overwrites files
  silently; existing global config (`~/.config/adr/config`) and project `.adr`
  files are never touched
- `~/.local/bin/adr` already exists and is not owned by the current user →
  error: "Cannot overwrite existing file. Remove it manually or check
  permissions."
- `curl … | bash` install without a TTY (CI context) → skips any interactive
  prompts, prints a non-interactive summary

---

## Behavior 2: Uninstallation via `uninstall.sh`

**Description**: A companion script cleanly removes everything `install.sh`
placed on disk, without touching user configuration or project files.

### What Is Removed

- `~/.local/bin/adr`
- `~/.local/share/adr/` (entire tree: agents, config-examples, completions,
  VERSION)

### What Is Preserved

- `~/.config/adr/config` (global user config)
- Any project-level `.adr` files
- All Docker images already built (`coding-agent/*`)

### Happy Path

- User runs `./uninstall.sh`
- Script asks: `Remove adr? This will delete ~/.local/bin/adr and
  ~/.local/share/adr/. Your ~/.config/adr/config and Docker images are kept.
  [y/N]`
- User confirms → files removed, success message printed
- `adr` is no longer on `PATH`

### Edge Cases

- `adr` was never installed (files missing) → script exits cleanly with
  message: `adr does not appear to be installed.`
- `--yes` flag skips the confirmation prompt (for scripting)

---

## Behavior 3: `adr build <agent>`

**Description**: Builds the Docker image for the named agent. Delegates to the
same `docker build` logic as `build.sh`, using the Dockerfiles bundled into
`~/.local/share/adr/agents/`.

### Happy Path

- User runs `adr build pi`
- `adr` resolves the build context to `~/.local/share/adr/agents/pi/`
- Executes `docker build -t coding-agent/pi:latest ~/.local/share/adr/agents/pi/`
- Docker output streams to the terminal
- On success: `Image coding-agent/pi:latest built successfully.`

### Options

| Flag | Behaviour |
|---|---|
| `--tag TAG` | Applies the given tag instead of `latest` |
| `--no-cache` | Passes `--no-cache` to `docker build` |

### No Agent Argument — Build All

- User runs `adr build` with no agent name
- `adr` prints the list of known agents and asks: `Build all agents? [y/N]`
- On confirmation: builds each agent sequentially, printing a header before
  each
- One agent failing does not abort the remaining builds; final summary lists
  successes and failures

### Error Cases

- Unknown agent name → `Error: Unknown agent 'foo'. Supported agents: pi,
  opencode, claude, codex` with exit code 1
- Docker daemon not running → docker's error message is surfaced as-is; `adr`
  adds: `Is the Docker daemon running?`
- Build fails (non-zero docker exit) → error message, non-zero exit

### Edge Cases

- `--tag` with an empty string → error: `--tag requires a non-empty value`
- Rebuilding an existing image with the same tag → allowed, Docker replaces it
  silently

---

## Behavior 4: `adr run [agent]`

**Description**: Runs the named agent in a Docker container. Mirrors all
options of `run.sh`. The workspace defaults to `$PWD`.

### Happy Path

- User runs `adr run pi` from `~/projects/myapp`
- `adr` resolves workspace to `~/projects/myapp`, config to `~/.pi/`
- Checks that `coding-agent/pi:latest` exists locally
- Starts the container with the same `docker run` flags as `run.sh`
- Interactive TUI session begins

### Options

All options from `run.sh` are supported with identical semantics:

| Flag | Behaviour |
|---|---|
| `-w, --workspace DIR` | Host directory mounted as `/workspace`. Default: `$PWD`. |
| `-c, --config DIR` | Override the agent's config directory. |
| `--config-file FILE` | Claude only: path to `.claude.json`. |
| `--prompt TEXT` | One-shot prompt; implies `--headless`. |
| `--headless` | Non-interactive mode; requires `--prompt`. |
| `--shell` | Drop into bash inside the container for debugging. |
| `--tag TAG` | Use a pinned image tag instead of `latest`. |
| `--model MODEL` | Override the model at runtime. |

### No Agent Argument — Use Project Default

- User runs `adr run` (no agent) from a directory containing `.adr`
- `adr` reads the `.adr` file and finds `ADR_AGENT=pi`
- Proceeds as if `adr run pi` was called, applying all other defaults from the
  file
- If no `.adr` file exists and no agent is specified → error: `No agent
  specified. Pass an agent name or create a .adr file with ADR_AGENT=<agent>.
  Run 'adr status' to see available agents.`

### Auto-Build Prompt

- User runs `adr run pi` but `coding-agent/pi:latest` does not exist
- `adr` prints: `Image coding-agent/pi:latest not found. Build it now? [Y/n]`
- On confirmation (or Enter): runs `adr build pi` inline, then proceeds to run
- On rejection: prints the manual build command and exits 1

### Error Cases

- Workspace directory does not exist → `Error: workspace directory does not
  exist: /path/to/dir`
- Config directory does not exist → same error pattern as `run.sh`, with hint
  pointing to `config-examples/`
- `--headless` without `--prompt` → `Error: --headless requires --prompt`
- `--shell` combined with `--headless` or `--prompt` → `Error: --shell and
  --headless/--prompt are mutually exclusive`
- `--config-file` used with non-claude agent → `Error: --config-file is only
  supported for the 'claude' agent`

### Edge Cases

- `--workspace` path with trailing slash → normalised to absolute path without
  trailing slash
- `--model` with `pi` agent and `provider/model` format → provider and model
  split on first `/` and forwarded as separate env vars, exactly as `run.sh`
  does today

---

## Behavior 5: `adr update [agent]`

**Description**: Rebuilds agent image(s) with `--no-cache` to pick up the
latest agent version from the internet (npm, pip, etc.).

### Happy Path

- User runs `adr update pi`
- Equivalent to `adr build --no-cache pi`
- Docker pulls the latest base image layers and reinstalls the agent package
- Old `coding-agent/pi:latest` image is replaced

### No Agent Argument — Update All Built Images

- `adr update` with no argument
- `adr` discovers which images are present locally (via `docker image ls`)
- Rebuilds each present image sequentially with `--no-cache`
- Skips agents whose image has never been built; prints a note for each
  skipped agent

### Error Cases

- Same as `adr build` — unknown agent, docker daemon down, build failure

---

## Behavior 6: `adr status`

**Description**: Prints a summary table of all known agents: whether their
image is present locally, the tag, image size, and when it was built.

### Output Format

```
Agent      Image                         Tag       Size     Built
─────────  ────────────────────────────  ────────  ───────  ─────────────
pi         coding-agent/pi:latest        latest    1.2 GB   2 days ago
opencode   coding-agent/opencode:latest  latest    890 MB   3 hours ago
claude     (not built)                   -         -        -
codex      (not built)                   -         -        -
```

### Happy Path

- `adr status` queries `docker image ls` for each known agent
- Rows for built images show tag, size, and relative time since creation
- Rows for absent images show `(not built)` with dashes

### Edge Cases

- Docker daemon is not running → `Error: Cannot reach Docker daemon. Is Docker
  running?` with non-zero exit
- No agents have been built yet → table is printed with all rows showing `(not
  built)`; helpful note: `Run 'adr build <agent>' to build an image.`

---

## Behavior 7: `adr fix-owner [DIR]`

**Description**: Changes ownership of files in a directory recursively to the
current user. Wrapper around the existing `fix_owner.sh` logic.

### Happy Path

- User runs `adr fix-owner` from the workspace directory
- Equivalent to running `sudo chown -R $(id -u):$(id -g) .`
- Prints a confirmation: `Changed ownership of all files in . to
  user:group.`

### Options

- Optional positional argument specifies target directory; defaults to `$PWD`

### Error Cases

- Directory does not exist → clear error, non-zero exit
- `sudo` not available or user lacks permissions → surfaces the system error
  message

---

## Behavior 8: Global Config File (`~/.config/adr/config`)

**Description**: A shell-sourceable key=value file that sets default values for
all `adr` commands. Users do not need to create it — the absence of the file is
valid and equivalent to having an empty one.

### Supported Keys

| Key | Affects | Example |
|---|---|---|
| `ADR_TAG` | Default image tag for `build` and `run` | `ADR_TAG=latest` |
| `ADR_MODEL_PI` | Default `--model` when running pi | `ADR_MODEL_PI=anthropic/claude-sonnet-4` |
| `ADR_MODEL_CLAUDE` | Default `--model` when running claude | `ADR_MODEL_CLAUDE=sonnet` |
| `ADR_MODEL_OPENCODE` | Default `--model` when running opencode | `ADR_MODEL_OPENCODE=anthropic/claude-sonnet-4` |
| `ADR_MODEL_CODEX` | Default `--model` when running codex | `ADR_MODEL_CODEX=o4-mini` |

### Precedence (lowest → highest)

1. Built-in defaults (e.g., tag `latest`, no model override)
2. `~/.config/adr/config`
3. Project-level `.adr` file in the current directory (or nearest parent)
4. Explicit CLI flags passed by the user

### Happy Path

- User sets `ADR_MODEL_PI=anthropic/claude-opus-4` in `~/.config/adr/config`
- Runs `adr run pi` → model flag is passed automatically
- Runs `adr run pi --model anthropic/claude-sonnet-4` → explicit flag overrides
  the config file value

### Edge Cases

- Config file contains unknown keys → silently ignored; no warning
- Config file contains syntax errors (e.g., unquoted spaces) → sourced by
  bash; malformed lines are silently skipped by the shell's `source` command
- Config directory `~/.config/adr/` does not exist → `adr` continues without
  config, using built-in defaults; the directory is not created automatically

---

## Behavior 9: Project-Level Config File (`.adr`)

**Description**: A per-project key=value file (same format as the global
config) that overrides global defaults for that project. Placed in a project
root directory.

### Supported Keys

Same keys as the global config, plus:

| Key | Affects | Example |
|---|---|---|
| `ADR_AGENT` | Default agent for `adr run` (no agent argument) | `ADR_AGENT=pi` |

### Discovery

`adr` looks for `.adr` starting in `$PWD` and walking up to the filesystem
root. The first file found wins. This mirrors how tools like `.editorconfig`,
`.gitignore`, and `.nvmrc` are discovered.

### Happy Path

- Developer adds `.adr` to `~/projects/myapp/`:
  ```
  ADR_AGENT=pi
  ADR_MODEL_PI=anthropic/claude-opus-4
  ```
- Runs `adr run` from any subdirectory of `~/projects/myapp/`
- `adr` picks up the file, uses pi with opus-4 without any flags

### Edge Cases

- `.adr` file found in a parent directory (e.g., `~/projects/`) → used for all
  subdirectories that do not have their own `.adr`
- `.adr` file exists but is empty → treated as no overrides; no error
- `.adr` sets `ADR_AGENT` to an unknown agent name → error at `adr run` time,
  same as if the user had passed an unknown agent on the command line

---

## Behavior 10: `adr config`

**Description**: Provides read and write access to the global config file from
the command line, so users do not need to edit it manually.

### Subcommands

#### `adr config` (no subcommand)

Prints the effective merged configuration: global values overlaid with any
project-level `.adr` found, showing which file each value comes from.

Example output:
```
Effective configuration (merged):

  ADR_TAG=latest                  (default)
  ADR_MODEL_PI=anthropic/claude-opus-4  (~/.config/adr/config)
  ADR_MODEL_CLAUDE=sonnet         (.adr)
```

#### `adr config set KEY=VALUE`

Writes or updates a single key in `~/.config/adr/config`.

- Creates `~/.config/adr/` and the file if they do not exist
- If the key already exists, the existing line is replaced in-place
- If the key does not exist, it is appended
- Prints: `Set ADR_MODEL_PI=anthropic/claude-opus-4 in ~/.config/adr/config`

#### `adr config set --project KEY=VALUE`

Same as above but writes to the `.adr` file in `$PWD` (creates it if absent).

### Error Cases

- `adr config set` without a `KEY=VALUE` argument → usage error
- `KEY=VALUE` missing the `=` sign → `Error: Expected KEY=VALUE format`

---

## Behavior 11: Shell Completions

**Description**: `adr` ships completion scripts for bash, zsh, and fish that
enable tab-completion of commands, agent names, and flags.

### `adr completions <shell>`

Prints the completion script for the given shell to stdout.

```bash
adr completions bash   # → bash completion script
adr completions zsh    # → zsh completion script
adr completions fish   # → fish completion script
```

### `adr completions install`

Auto-detects the current shell from `$SHELL` and installs the completion script
to the appropriate location:

| Shell | Installation path |
|---|---|
| bash | `~/.bash_completion.d/adr` (creates dir if needed) |
| zsh | `~/.zsh/completions/_adr` (creates dir if needed) |
| fish | `~/.config/fish/completions/adr.fish` |

Prints the path it wrote to and, for bash/zsh, the line the user needs to add
to their shell rc file if the completion directory is not already sourced.

### What Is Completed

| Context | Completions offered |
|---|---|
| `adr <TAB>` | `build run update status fix-owner completions config version help` |
| `adr build <TAB>` | `pi opencode claude codex` |
| `adr run <TAB>` | `pi opencode claude codex` |
| `adr run pi <TAB>` | `--workspace --config --prompt --headless --shell --tag --model` |
| `adr completions <TAB>` | `bash zsh fish install` |
| `adr config <TAB>` | `set` |
| `adr config set <TAB>` | `ADR_TAG= ADR_MODEL_PI= ADR_MODEL_CLAUDE= ADR_MODEL_OPENCODE= ADR_MODEL_CODEX=` |

### Error Cases

- Unknown shell name → `Error: Unknown shell 'xxx'. Supported: bash, zsh,
  fish`

---

## Behavior 12: `adr version`

**Description**: Prints the installed version of `adr`.

### Happy Path

- `adr version` → reads `~/.local/share/adr/VERSION` and prints: `adr 0.3.0`
- `adr --version` → same output

### Edge Cases

- `VERSION` file missing (corrupted install) → prints: `adr (unknown version)
  — reinstall with install.sh`

---

## Behavior 13: `adr help [command]`

**Description**: Prints usage information.

### `adr help` / `adr --help` / `adr -h`

Prints a summary of all commands with one-line descriptions.

```
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
```

### `adr help <command>`

Prints the full option reference for the given command (equivalent to `adr
<command> --help`).

---

## Behavior 14: File and Directory Layout After Install

**Description**: The installed layout is predictable and self-contained. All
`adr`-owned files live under `~/.local/` or `~/.config/adr/`. No files are
placed elsewhere without the user's explicit action.

```
~/.local/
  bin/
    adr                              ← main CLI executable

  share/adr/
    VERSION                          ← e.g. "0.3.0"
    agents/
      pi/
        Dockerfile
        entrypoint.sh
      opencode/
        Dockerfile
        entrypoint.sh
      claude/
        Dockerfile
        entrypoint.sh
      codex/
        Dockerfile
        entrypoint.sh
    config-examples/                 ← mirrors repo config-examples/
      pi/
      opencode/
      claude/
      codex/
    completions/
      adr.bash
      adr.zsh
      adr.fish

~/.config/adr/
  config                             ← global defaults (KEY=VALUE, optional)

<any project directory>/
  .adr                               ← project-level overrides (KEY=VALUE, optional)
```

---

## Non-Goals (Explicitly Out of Scope)

- **Publishing images to a registry**: Images are built and stay local. No
  `docker push`. No public registry.
- **Managing multiple image tags simultaneously**: `adr status` shows only
  the default tag per agent. Users with pinned tags manage them via direct
  `docker` commands.
- **Windows native support**: WSL2 on Windows is supported (bash runs fine
  there). Native Windows cmd/PowerShell is out of scope.
- **`adr init` first-run wizard**: Deferred to a later phase. The install
  script and error messages with hints cover the first-run experience for now.
- **Pre-built Docker Hub images / `adr pull`**: Out of scope. Build locally
  from the bundled Dockerfiles.
- **Daemon / background process**: `adr` is a pure CLI wrapper. It spawns
  Docker containers and exits. No persistent process, no socket, no server.

---

## Related Documents

- [Tests](./tests.md) — Test cases for all behaviors above
- [Architecture](../../project/architecture.md) — Container Manager and CLI Layer design
- [Conventions](../../project/conventions.md) — File naming and coding patterns
