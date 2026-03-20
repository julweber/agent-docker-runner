# ADR CLI - Tests

This document defines test cases for the `adr` CLI. Tests are organised by
behavior and cover installation, command invocation, config resolution, and
error handling.

Unless otherwise noted, tests assume:
- The install has been completed successfully (`install.sh` run, `adr` is on `PATH`)
- Docker daemon is running
- At least one agent image has been built (`adr build pi`)

---

## Test 1: Installation

### Test 1.1: Clean Install Places Files Correctly

**Procedure**:
1. Ensure no prior installation: `rm -f ~/.local/bin/adr && rm -rf ~/.local/share/adr`
2. Run `./install.sh` from the repository root
3. Verify each expected file is in place

**Expected Outcome**:
- `~/.local/bin/adr` exists and is executable (`-x`)
- `~/.local/share/adr/VERSION` exists and contains a non-empty string
- `~/.local/share/adr/agents/pi/Dockerfile` exists
- `~/.local/share/adr/agents/opencode/Dockerfile` exists
- `~/.local/share/adr/agents/claude/Dockerfile` exists
- `~/.local/share/adr/agents/codex/Dockerfile` exists
- `~/.local/share/adr/config-examples/` directory exists
- `~/.local/share/adr/completions/` directory exists
- Install script exits with code 0
- Terminal output contains "adr installed"

### Test 1.2: Re-running Install Is Idempotent

**Procedure**:
1. Run `./install.sh` (clean install)
2. Record the content of `~/.local/share/adr/VERSION`
3. Run `./install.sh` again without any changes
4. Verify state after second run

**Expected Outcome**:
- Script exits with code 0 both times
- `~/.local/bin/adr` is still present and executable
- VERSION content is the same as after the first run
- Any pre-existing `~/.config/adr/config` file is unchanged

### Test 1.3: Install Warns When `~/.local/bin` Not in PATH

**Procedure**:
1. Temporarily remove `~/.local/bin` from PATH: `export PATH=$(echo $PATH | sed 's|:~/.local/bin||; s|~/.local/bin:||')`
2. Run `./install.sh`

**Expected Outcome**:
- Script completes successfully (exit code 0)
- Terminal output contains a message about `~/.local/bin` not being in PATH
- Message includes a suggestion for the user to add it to their shell rc file

### Test 1.4: Install Fails Cleanly on Permission Error

**Procedure**:
1. Make `~/.local/bin` unwritable: `chmod -w ~/.local/bin`
2. Run `./install.sh`
3. Restore permissions afterward: `chmod +w ~/.local/bin`

**Expected Outcome**:
- Script prints an error describing the failure
- Script exits with a non-zero code
- No partial installation left in place (no half-written files in share/)

---

## Test 2: Uninstallation

### Test 2.1: Clean Uninstall Removes Installed Files

**Procedure**:
1. Complete a successful install (Test 1.1)
2. Create a global config: `mkdir -p ~/.config/adr && echo "ADR_TAG=latest" > ~/.config/adr/config`
3. Build one image: `adr build pi`
4. Run `./uninstall.sh --yes`

**Expected Outcome**:
- `~/.local/bin/adr` is removed
- `~/.local/share/adr/` directory is removed
- `~/.config/adr/config` still exists (not removed)
- `docker image ls coding-agent/pi:latest` still shows the image (not removed)
- Exit code 0

### Test 2.2: Uninstall When Not Installed

**Procedure**:
1. Ensure `adr` is not installed
2. Run `./uninstall.sh --yes`

**Expected Outcome**:
- Script prints: `adr does not appear to be installed.`
- Exit code 0 (not an error)

---

## Test 3: `adr build`

### Test 3.1: Build Known Agent

**Procedure**:
1. Run `adr build pi`
2. Check Docker image list

**Expected Outcome**:
- `docker image ls coding-agent/pi:latest` shows the image
- `adr build` exits with code 0
- Terminal output includes "built successfully" or equivalent confirmation

### Test 3.2: Build with Custom Tag

**Procedure**:
1. Run `adr build pi --tag 1.0.0`
2. Check Docker image list

**Expected Outcome**:
- `docker image ls coding-agent/pi:1.0.0` shows the image
- `docker image ls coding-agent/pi:latest` is unaffected (not re-tagged)
- Exit code 0

### Test 3.3: Build with `--no-cache`

**Procedure**:
1. Run `adr build pi` (warm cache)
2. Run `adr build pi --no-cache`
3. Note timestamp difference

**Expected Outcome**:
- Both commands succeed (exit code 0)
- Second build does not use cached layers (visible in Docker output)
- Resulting image replaces the previous `coding-agent/pi:latest`

### Test 3.4: Build Unknown Agent

**Procedure**:
1. Run `adr build fakeagent`

**Expected Outcome**:
- Exit code 1
- Error message: "Unknown agent 'fakeagent'. Supported agents: pi, opencode, claude, codex"
- No Docker command is invoked

### Test 3.5: Build All Agents (Interactive Confirmation)

**Procedure**:
1. Run `adr build` (no agent argument)
2. When prompted, enter `y`

**Expected Outcome**:
- Builds all four known agents sequentially
- Each agent's build is preceded by a header line identifying it
- Final summary lists which succeeded and which (if any) failed
- Exit code 0 if all succeed; non-zero if any fail

### Test 3.6: Build All Agents — Rejection Aborts

**Procedure**:
1. Run `adr build`
2. When prompted, enter `n`

**Expected Outcome**:
- No builds are started
- Exit code 0 (user cancelled, not an error)

### Test 3.7: `--tag` with Empty String

**Procedure**:
1. Run `adr build pi --tag ""`

**Expected Outcome**:
- Error: "--tag requires a non-empty value"
- Exit code 1

---

## Test 4: `adr run`

### Test 4.1: Interactive Session (Default Workspace)

**Procedure**:
1. `cd ~/projects/myapp` (any directory)
2. Run `adr run pi` (image must be built)

**Expected Outcome**:
- Container starts with `/workspace` mounted from `~/projects/myapp`
- Pi TUI session appears in the terminal
- Container name or ID is visible in `docker ps` while session is active
- Container is removed after the session exits (`--rm` confirmed)

### Test 4.2: Workspace Override

**Procedure**:
1. Run `adr run pi --workspace /tmp/test-workspace` (directory must exist)

**Expected Outcome**:
- Container mounts `/tmp/test-workspace` as `/workspace`
- Confirmed by creating a file inside the container and verifying it appears in
  `/tmp/test-workspace` on the host

### Test 4.3: Headless One-Shot Prompt

**Procedure**:
1. Run `adr run pi --prompt "Print the string HELLO_TEST to stdout and exit"`

**Expected Outcome**:
- Container starts in non-interactive (headless) mode
- Output contains "HELLO_TEST"
- Container exits and is removed
- Exit code 0

### Test 4.4: `--prompt` Implies `--headless`

**Procedure**:
1. Run `adr run pi --prompt "Say hello"` (no `--headless` flag)

**Expected Outcome**:
- Behaves identically to running with `--headless` explicitly
- No TTY allocation (no `-t` in the docker run command)

### Test 4.5: `--headless` Without `--prompt` Is Rejected

**Procedure**:
1. Run `adr run pi --headless` (no `--prompt`)

**Expected Outcome**:
- Error: "--headless requires --prompt"
- Exit code 1
- No container is started

### Test 4.6: `--shell` Drops into Bash

**Procedure**:
1. Run `adr run pi --shell`
2. Inside the container, run `whoami` and `pwd`

**Expected Outcome**:
- Bash shell is presented inside the container
- `whoami` returns `node`
- `pwd` returns `/workspace`

### Test 4.7: `--shell` and `--prompt` Are Mutually Exclusive

**Procedure**:
1. Run `adr run pi --shell --prompt "Hello"`

**Expected Outcome**:
- Error: "--shell and --headless/--prompt are mutually exclusive"
- Exit code 1
- No container is started

### Test 4.8: Model Override (pi provider/model format)

**Procedure**:
1. Run `adr run pi --model anthropic/claude-opus-4 --prompt "Print HELLO_TEST"`

**Expected Outcome**:
- Container receives `AGENT_PROVIDER=anthropic` and `AGENT_MODEL=claude-opus-4`
  as separate env vars (verified via `adr run pi --shell` and `env | grep AGENT`)

### Test 4.9: Model Override (claude alias)

**Procedure**:
1. Run `adr run claude --model sonnet --prompt "Print HELLO_TEST"`

**Expected Outcome**:
- Container receives `AGENT_MODEL=sonnet`

### Test 4.10: Unknown Workspace Directory

**Procedure**:
1. Run `adr run pi --workspace /nonexistent/path`

**Expected Outcome**:
- Error: "workspace directory does not exist: /nonexistent/path"
- Exit code 1
- No container is started

### Test 4.11: Image Not Built — Auto-Build Prompt

**Procedure**:
1. Remove the pi image if present: `docker rmi coding-agent/pi:latest || true`
2. Run `adr run pi`
3. When prompted to build, enter `y`

**Expected Outcome**:
- Prompt: "Image coding-agent/pi:latest not found. Build it now? [Y/n]"
- On `y`: `adr build pi` runs inline, then the container starts

### Test 4.12: Image Not Built — Auto-Build Rejected

**Procedure**:
1. Remove the pi image: `docker rmi coding-agent/pi:latest || true`
2. Run `adr run pi`
3. When prompted to build, enter `n`

**Expected Outcome**:
- Command to build manually is printed
- Exit code 1, no container started

### Test 4.13: No Agent Argument, No `.adr` File

**Procedure**:
1. `cd /tmp` (directory with no `.adr` file in any parent)
2. Run `adr run`

**Expected Outcome**:
- Error: "No agent specified. Pass an agent name or create a .adr file with
  ADR_AGENT=<agent>. Run 'adr status' to see available agents."
- Exit code 1

### Test 4.14: No Agent Argument, `.adr` File Present

**Procedure**:
1. Create `/tmp/test-proj/.adr` with `ADR_AGENT=pi`
2. `cd /tmp/test-proj`
3. Run `adr run`

**Expected Outcome**:
- Behaves as `adr run pi` using current directory as workspace

---

## Test 5: `adr update`

### Test 5.1: Update Single Agent

**Procedure**:
1. `adr build pi` (ensure image exists)
2. Record the image creation timestamp: `docker inspect --format '{{.Created}}' coding-agent/pi:latest`
3. Run `adr update pi`
4. Record new timestamp

**Expected Outcome**:
- `adr update pi` exits with code 0
- New image creation timestamp is later than the original
- Build ran with `--no-cache` (visible in Docker output)

### Test 5.2: Update All — Only Rebuilds Present Images

**Procedure**:
1. Build only pi: `adr build pi`
2. Ensure claude is not built: `docker rmi coding-agent/claude:latest || true`
3. Run `adr update` (no argument)

**Expected Outcome**:
- pi is rebuilt
- A note is printed for claude: "Skipping claude (not built)"
- opencode and codex are also noted as skipped if not built
- Exit code 0

---

## Test 6: `adr status`

### Test 6.1: Mixed State (Some Built, Some Not)

**Procedure**:
1. Build pi and opencode; ensure claude and codex images are absent
2. Run `adr status`

**Expected Outcome**:
- Table is printed with four rows (one per known agent)
- pi row: shows `coding-agent/pi:latest`, tag, size (non-zero), and a "X time ago" value
- opencode row: same fields populated
- claude row: shows `(not built)` with dashes in size and built columns
- codex row: same as claude
- Exit code 0

### Test 6.2: No Images Built

**Procedure**:
1. Remove all agent images (or run in a clean environment)
2. Run `adr status`

**Expected Outcome**:
- All four rows show `(not built)`
- Footer note: "Run 'adr build <agent>' to build an image."
- Exit code 0

### Test 6.3: Docker Daemon Not Running

**Procedure**:
1. Stop Docker daemon (or simulate by pointing DOCKER_HOST to a bad socket)
2. Run `adr status`

**Expected Outcome**:
- Error: "Cannot reach Docker daemon. Is Docker running?"
- Exit code 1

---

## Test 7: `adr fix-owner`

### Test 7.1: Fix Ownership in Current Directory

**Procedure**:
1. Create files owned by another UID (simulate via a container that creates files
   as UID 1000, which may differ from the host user)
2. `cd` into the affected directory
3. Run `adr fix-owner`

**Expected Outcome**:
- All files in the directory recursively are owned by the current user
- Confirmation message is printed
- Exit code 0

### Test 7.2: Target Directory Does Not Exist

**Procedure**:
1. Run `adr fix-owner /nonexistent/dir`

**Expected Outcome**:
- Error message referencing the missing directory
- Exit code 1

---

## Test 8: Global Config File

### Test 8.1: Default Model Applied to `adr run`

**Procedure**:
1. Write `ADR_MODEL_PI=anthropic/claude-opus-4` to `~/.config/adr/config`
2. Run `adr run pi --shell`
3. Inside the container, inspect env: `env | grep AGENT_MODEL`

**Expected Outcome**:
- `AGENT_MODEL=claude-opus-4` (with `AGENT_PROVIDER=anthropic`) visible in the
  container environment

### Test 8.2: CLI Flag Overrides Config File

**Procedure**:
1. Write `ADR_MODEL_PI=anthropic/claude-opus-4` to `~/.config/adr/config`
2. Run `adr run pi --model anthropic/claude-sonnet-4 --shell`
3. Inspect env inside container: `env | grep AGENT_MODEL`

**Expected Outcome**:
- `AGENT_MODEL=claude-sonnet-4` is used (CLI flag wins over config file)

### Test 8.3: Missing Config File Is Not an Error

**Procedure**:
1. Ensure `~/.config/adr/config` does not exist
2. Run `adr status`

**Expected Outcome**:
- Command runs normally, exit code 0
- No error or warning about missing config

### Test 8.4: Unknown Keys Are Silently Ignored

**Procedure**:
1. Write `UNKNOWN_KEY=foo` to `~/.config/adr/config`
2. Run `adr status`

**Expected Outcome**:
- Command runs normally, exit code 0
- No error or warning about the unknown key

---

## Test 9: Project-Level Config File (`.adr`)

### Test 9.1: `.adr` Sets Default Agent

**Procedure**:
1. Create `/tmp/test-proj/.adr` with:
   ```
   ADR_AGENT=pi
   ```
2. `cd /tmp/test-proj`
3. Run `adr run` (no agent argument)

**Expected Outcome**:
- `adr` uses pi as the agent (identical to `adr run pi`)
- No error about missing agent argument

### Test 9.2: `.adr` Overrides Global Config Model

**Procedure**:
1. Write `ADR_MODEL_PI=anthropic/claude-sonnet-4` to `~/.config/adr/config`
2. Create `/tmp/test-proj/.adr` with `ADR_MODEL_PI=anthropic/claude-opus-4`
3. `cd /tmp/test-proj`
4. Run `adr run pi --shell` and inspect env

**Expected Outcome**:
- `AGENT_MODEL=claude-opus-4` (project `.adr` wins over global config)

### Test 9.3: `.adr` Discovered in Parent Directory

**Procedure**:
1. Create `/tmp/test-proj/.adr` with `ADR_AGENT=pi`
2. `mkdir -p /tmp/test-proj/src/utils && cd /tmp/test-proj/src/utils`
3. Run `adr run` (no `.adr` in current dir or `src/`)

**Expected Outcome**:
- `adr` discovers `/tmp/test-proj/.adr` by walking up the directory tree
- Runs pi as the agent

### Test 9.4: `.adr` with Unknown Agent Name

**Procedure**:
1. Create `.adr` with `ADR_AGENT=fakeagent` in `$PWD`
2. Run `adr run`

**Expected Outcome**:
- Error: "Unknown agent 'fakeagent'. Supported agents: pi, opencode, claude, codex"
- Exit code 1

---

## Test 10: `adr config`

### Test 10.1: `adr config` Prints Effective Configuration

**Procedure**:
1. Set `ADR_MODEL_PI=anthropic/claude-opus-4` in `~/.config/adr/config`
2. Create `.adr` in `$PWD` with `ADR_MODEL_CLAUDE=sonnet`
3. Run `adr config`

**Expected Outcome**:
- Output shows each known config key and its value
- Source annotation indicates `(~/.config/adr/config)` or `(.adr)` or `(default)`
- pi model shows `anthropic/claude-opus-4` from global config
- claude model shows `sonnet` from project `.adr`
- Unset keys show their built-in default or indicate "not set"

### Test 10.2: `adr config set` Creates Key

**Procedure**:
1. Ensure `~/.config/adr/config` is absent or empty
2. Run `adr config set ADR_TAG=1.0.0`
3. Check file contents

**Expected Outcome**:
- `~/.config/adr/` directory is created if needed
- `~/.config/adr/config` contains `ADR_TAG=1.0.0`
- Terminal output: "Set ADR_TAG=1.0.0 in ~/.config/adr/config"

### Test 10.3: `adr config set` Updates Existing Key

**Procedure**:
1. Write `ADR_TAG=latest` to `~/.config/adr/config`
2. Run `adr config set ADR_TAG=1.2.3`
3. Check file contents

**Expected Outcome**:
- File contains `ADR_TAG=1.2.3` (old value replaced)
- File does not contain `ADR_TAG=latest`
- No duplicate lines

### Test 10.4: `adr config set --project` Writes to `.adr`

**Procedure**:
1. `cd /tmp/test-proj` (no `.adr` present)
2. Run `adr config set --project ADR_AGENT=pi`
3. Check `/tmp/test-proj/.adr`

**Expected Outcome**:
- `/tmp/test-proj/.adr` is created containing `ADR_AGENT=pi`

### Test 10.5: `adr config set` Without Argument

**Procedure**:
1. Run `adr config set` with no argument

**Expected Outcome**:
- Usage error shown
- Exit code 1

### Test 10.6: `adr config set` With Malformed Argument (no `=`)

**Procedure**:
1. Run `adr config set ADR_TAG`

**Expected Outcome**:
- Error: "Expected KEY=VALUE format"
- Exit code 1

---

## Test 11: Shell Completions

### Test 11.1: Bash Completion Output Is Non-Empty

**Procedure**:
1. Run `adr completions bash`

**Expected Outcome**:
- Non-empty output to stdout
- Output contains bash completion boilerplate (`complete` command)
- Exit code 0

### Test 11.2: Zsh Completion Output Is Non-Empty

**Procedure**:
1. Run `adr completions zsh`

**Expected Outcome**:
- Non-empty output to stdout
- Output is valid zsh completion syntax (`_arguments` or similar)
- Exit code 0

### Test 11.3: Fish Completion Output Is Non-Empty

**Procedure**:
1. Run `adr completions fish`

**Expected Outcome**:
- Non-empty output to stdout
- Output contains `complete -c adr` directives
- Exit code 0

### Test 11.4: Unknown Shell Is Rejected

**Procedure**:
1. Run `adr completions powershell`

**Expected Outcome**:
- Error: "Unknown shell 'powershell'. Supported: bash, zsh, fish"
- Exit code 1

### Test 11.5: Completion Install Creates File

**Procedure**:
1. Ensure `$SHELL` is set to `/bin/bash`
2. Run `adr completions install`
3. Check `~/.bash_completion.d/adr`

**Expected Outcome**:
- `~/.bash_completion.d/adr` exists and is non-empty
- Terminal output names the file that was written
- Terminal output includes the line to add to `.bashrc` if the directory is not
  yet sourced

### Test 11.6: Command Completions Are Accurate

**Procedure** (manual, requires bash with completions active):
1. Type `adr ` and press Tab twice

**Expected Outcome**:
- Completion candidates include: `build`, `run`, `update`, `status`,
  `fix-owner`, `completions`, `config`, `version`, `help`

### Test 11.7: Agent Name Completions After `adr run`

**Procedure** (manual):
1. Type `adr run ` and press Tab twice

**Expected Outcome**:
- Completion candidates include: `pi`, `opencode`, `claude`, `codex`

---

## Test 12: `adr version`

### Test 12.1: Version Is Printed

**Procedure**:
1. Run `adr version`

**Expected Outcome**:
- Output matches pattern: `adr <semver>` (e.g., `adr 0.3.0`)
- Exit code 0

### Test 12.2: `--version` Flag Works

**Procedure**:
1. Run `adr --version`

**Expected Outcome**:
- Same output as `adr version`

### Test 12.3: Missing VERSION File

**Procedure**:
1. Temporarily remove `~/.local/share/adr/VERSION`
2. Run `adr version`
3. Restore the file

**Expected Outcome**:
- Output: "adr (unknown version) — reinstall with install.sh"
- Exit code 0 (not a fatal error)

---

## Test 13: Precedence — Config Layering

**Purpose**: Verify that the three-layer precedence (defaults → global config →
project `.adr` → CLI flags) is applied correctly at runtime.

### Test 13.1: Full Precedence Chain

**Procedure**:
1. Clear any existing configs
2. Set `ADR_MODEL_PI=anthropic/model-global` in `~/.config/adr/config`
3. Create `.adr` in `$PWD` with `ADR_MODEL_PI=anthropic/model-project`
4. Run `adr run pi --model anthropic/model-flag --shell`
5. Inspect env inside container

**Expected Outcome**:
- `AGENT_MODEL=model-flag` (CLI flag wins; provider split correctly)

### Test 13.2: Project Beats Global

**Procedure**:
1. Set `ADR_MODEL_PI=anthropic/model-global` in `~/.config/adr/config`
2. Create `.adr` in `$PWD` with `ADR_MODEL_PI=anthropic/model-project`
3. Run `adr run pi --shell` (no `--model` flag)
4. Inspect env inside container

**Expected Outcome**:
- `AGENT_MODEL=model-project` (project `.adr` beats global config)

### Test 13.3: Global Beats Default

**Procedure**:
1. Set `ADR_MODEL_PI=anthropic/model-global` in `~/.config/adr/config`
2. Ensure no `.adr` file is present
3. Run `adr run pi --shell` (no `--model` flag)
4. Inspect env inside container

**Expected Outcome**:
- `AGENT_MODEL=model-global` is used
- Without the global config the env var would be absent (default: no model override)

---

## Test Execution Quick Reference

```bash
# Install
./install.sh
which adr             # should print ~/.local/bin/adr
adr version           # should print version

# Build
adr build pi
adr status            # pi should show as built

# Run headless smoke test
adr run pi --prompt "Print the text SMOKE_TEST_OK and nothing else"
# output should contain SMOKE_TEST_OK

# Config round-trip
adr config set ADR_MODEL_PI=anthropic/test-model
grep ADR_MODEL_PI ~/.config/adr/config  # should exist

# Project .adr
mkdir -p /tmp/adr-test && echo "ADR_AGENT=pi" > /tmp/adr-test/.adr
cd /tmp/adr-test && adr run --prompt "Print PROJ_CONFIG_OK"
# should run pi without specifying agent on CLI

# Completions
adr completions bash | head -5   # non-empty output
```

---

## Quality Gates

### Minimum Requirements Before Implementation Is Complete

- Tests 1.1 and 1.2 pass (install + idempotency)
- Tests 3.1 and 3.4 pass (build success and unknown agent error)
- Tests 4.1, 4.3, 4.5, 4.7 pass (run interactive, headless, and mutual-exclusion errors)
- Test 6.1 passes (status table correct output)
- Tests 8.1 and 8.3 pass (config defaults applied; missing config not an error)
- Test 9.1 passes (project `.adr` agent default)
- Tests 13.1–13.3 pass (precedence chain correct)

### Definition of "Passing"

A test passes when:
1. Exit code matches the expected value (0 for success, 1 for errors, etc.)
2. All expected output strings are present in stdout or stderr as described
3. All expected files exist (or are absent) as described
4. No unexpected side effects occur (no extra files created, no existing files deleted)

---

## Test 14: `adr help`

### Test 14.1: `adr help` Prints Command Summary

**Procedure**:
1. Run `adr help`

**Expected Outcome**:
- Output contains the usage line: `Usage: adr <command> [options]`
- Output lists all commands: `build`, `run`, `update`, `status`, `fix-owner`,
  `completions`, `config`, `version`
- Exit code 0

### Test 14.2: `adr --help` and `adr -h` Are Equivalent

**Procedure**:
1. Run `adr --help`
2. Run `adr -h`

**Expected Outcome**:
- Both produce identical output to `adr help`
- Exit code 0 for both

### Test 14.3: `adr help <command>` Prints Command Detail

**Procedure**:
1. Run `adr help run`

**Expected Outcome**:
- Output includes all flags for `adr run`: `--workspace`, `--config`,
  `--config-file`, `--prompt`, `--headless`, `--shell`, `--tag`, `--model`
- Exit code 0
- Output is identical to `adr run --help`

### Test 14.4: `adr help <unknown-command>` Is Handled

**Procedure**:
1. Run `adr help fakecommand`

**Expected Outcome**:
- Error message indicating the unknown command
- Exit code 1

---

## Related Documents

- [Behaviors](./behaviors.md) — Functional requirements tested here
- [Test Strategy](../../project/test-strategy.md) — Overall testing philosophy
