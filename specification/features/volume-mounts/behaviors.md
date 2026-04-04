# Feature: Host Directory Mounts for `adr run`

## Overview

Users can mount additional host directories into running agent containers via `--mount` / `-m` flags or via `ADR_MOUNTS` in config files. Mounts are additive to the auto-mounted workspace and agent-config directories.

---

## Behavior 1 — `--mount HOST:CONTAINER[:ro|rw]` flag

**Syntax:** `--mount HOST_PATH:CONTAINER_PATH[:ro|rw]`

- Short form `-m` works identically
- Mode suffix is optional; **defaults to `ro`**
- Flag may appear multiple times; mounts accumulate in declaration order

**Examples:**
```bash
adr run --mount /data:/data:ro claude
adr run -m /data:/data claude              # implicit ro
adr run --mount /data:/data --mount /out:/output:rw claude
```

**Error cases:**

| Scenario | Error Message |
|----------|---------------|
| Missing `:` separator | `"Invalid --mount format. Expected HOST:CONTAINER[:ro\|rw]"` |
| Container path not absolute | `"Mount container path must be absolute: <path>"` |
| Invalid mode (not ro/rw) | `"Invalid mount mode '<mode>'. Must be 'ro' or 'rw'"` |
| Host path does not exist | `"Mount host path does not exist: <path>"` |
| Host path is not a directory | `"Mount host path is not a directory: <path>"` |

---

## Behavior 2 — Config file support (`ADR_MOUNTS`)

Users may set `ADR_MOUNTS` in `~/.config/adr/config` or the project `.adr` file:

```
ADR_MOUNTS=/host/data:/data:ro /host/out:/output:rw
```

- Value is a **space-separated list** of `HOST:CONTAINER[:ro|rw]` entries
- Same syntax and validation rules as the CLI flag apply to each entry
- Config-file mounts are loaded first; CLI `--mount` flags append afterward

---

## Behavior 3 — Validation

All validation runs before the container is started. Any error exits with code 2 and no container is created.

Validation checks (in order):
1. At least one `:` separator present in the mount spec
2. Container path starts with `/`
3. Mode (if present) is exactly `ro` or `rw`
4. Host path exists on the filesystem
5. Host path is a directory (not a file or symlink-to-file)

---

## Behavior 4 — Docker integration

Each mount entry produces a `-v HOST:CONTAINER:MODE` argument in the `docker run` command. The mode is always explicit (defaulting to `ro` when omitted by the user), so the Docker command is deterministic.

**Example Docker command fragment:**
```
docker run ... -v /host/data:/data:ro -v /host/out:/output:rw ...
```

---

## Verification Examples

```bash
# Basic ro mount (implicit default)
adr run --mount /tmp/testdata:/data claude --shell
# inside container: ls /data  (readable, not writable)

# Explicit rw mount
adr run --mount /tmp/output:/output:rw claude --shell
# inside container: touch /output/file  (should succeed)

# Multiple mounts via short form
adr run -m /tmp/testdata:/data -m /tmp/output:/output:rw pi

# Config file
echo "ADR_MOUNTS=/tmp/testdata:/data:ro" >> .adr
adr run claude --shell

# Error: missing host dir
adr run --mount /nonexistent:/data claude
# => "Error: Mount host path does not exist: /nonexistent"

# Error: bad mode
adr run --mount /tmp:/data:readwrite claude
# => "Error: Invalid mount mode 'readwrite'. Must be 'ro' or 'rw'"

# Error: relative container path
adr run --mount /tmp:relative claude
# => "Error: Mount container path must be absolute: relative"
```
