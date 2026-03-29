# Environment Variables - Behaviors

This document defines the behavioral requirements for passing environment variables to agents in the `adr run` command.

## Overview

Users can pass custom environment variables to containers when running agents. This is useful for:
- Providing API keys at runtime
- Setting debug flags or feature toggles
- Any container-level configuration not stored in agent config directories

Two mechanisms are supported: direct CLI arguments and file-based input.

---

## Behavior 1: `--env KEY=VALUE` Flag

**Description**: Pass a single environment variable directly via the command line. Can be specified multiple times.

### Syntax

```
--env KEY=VALUE
```

- `KEY`: Environment variable name (must follow naming rules below)
- `VALUE`: The value to set (can be empty string)

### Key Validation

Environment variable names must follow standard shell conventions:
- Start with a letter or underscore
- Contain only letters, numbers, and underscores (`[A-Za-z_][A-Za-z0-9_]*`)
- Examples: `VALID_KEY`, `_PRIVATE`, `API_KEY_123` are valid; `123_INVALID`, `key-name`, `key.name` are invalid

The `--env` flag may appear anywhere among other options.

### Examples

```bash
adr run --env OPENAI_API_KEY=sk-xxx pi
adr run --env DEBUG=true --env LOG_LEVEL=debug pi
adr run -e ANTHROPIC_API_KEY=sk-ant-xxx claude  # using short form if supported
```

### Happy Path

- Single `--env` flag adds one environment variable to the container
- Multiple `--env` flags accumulate (last value wins for duplicates)
- Value can contain spaces: `--env GREETING="hello world"`
- Value can be empty: `--env EMPTY_VAR=`

### Short Form

The short form `-e` works identically to `--env`. It requires a space between the flag and value:

```
-e KEY=VALUE    # Valid
-eKEY=VALUE   # Invalid - will be interpreted as env var named "eKEY"
```

When combined with other single-character flags, each must have its own leading dash:

```bash
adr run -e FOO=bar -p "prompt" pi  # Valid: separate dashes
adr run -eprompt -e FOO=bar pi    # Invalid: merges -e with prompt
```

### Error Cases

| Scenario | Error Message |
|-----------|----------------|
| Missing `=` in argument | "Invalid --env format. Expected KEY=VALUE" |
| Empty key | "Environment variable name cannot be empty" |
| Invalid key format (e.g., starts with number, contains special chars) | "Invalid environment variable name '\<key\>'. Must start with a letter or underscore, contain only alphanumeric characters and underscores." |

---

## Behavior 2: `--env-file FILE` Flag

**Description**: Read environment variables from a file, supporting `.env` style formatting.

### Syntax

```
--env-file FILE
```

The flag accepts any file path. If relative, it is resolved relative to the current working directory.

### File Format

Each line in the file should be in `KEY=VALUE` format:
- Lines starting with `#` are comments and ignored
- Empty lines are ignored
- **Leading and trailing whitespace on keys and values must be trimmed**
  - `KEY = value` becomes `KEY=value`
  - This matches standard `.env` file conventions

### Examples

```bash
adr run --env-file .env pi
adr run --env-file ~/secrets/api-keys.env claude
```

### Example `.env` file:

```
# API Keys
OPENAI_API_KEY=sk-xxx
ANTHROPIC_API_KEY=sk-ant-xxx

DEBUG=false
```

### Happy Path

- File exists and is readable → variables are loaded
- All valid `KEY=VALUE` lines are added to the container's environment
- Variables from `--env-file` combine with those from `--env` flags

### Error Cases

| Scenario | Error Message |
|-----------|----------------|
| File does not exist | "Env file not found: <filepath>" |
| File is not readable | "Cannot read env file: <filepath>" |
| Invalid key format in file (e.g., `123_KEY=value`, `key-name=value`) | "Invalid environment variable name '\<key\>' in env file. Must start with a letter or underscore, contain only alphanumeric characters and underscores." |

---

## Behavior 3: Environment Variable Precedence & Merging

**Description**: When both `--env-file` and multiple `--env` flags are used, they are merged into a single set of environment variables.

### Merge Rules

1. Variables from `--env-file` are loaded first
2. Each `--env KEY=VALUE` is applied in order
3. If the same key appears multiple times, **the last value wins**

### Example

Given:
```
# .env file
API_KEY=from-file
DEBUG=true
```

Command:
```bash
adr run --env-file .env --env API_KEY=from-cli pi
```

Resulting container environment:
- `API_KEY=from-cli` (overridden by --env)
- `DEBUG=true` (from --env-file, not overridden)

---

## Behavior 4: Docker Integration

**Description**: Environment variables are passed to the container using docker's `--env` flag.

### Implementation Notes

Each user-provided environment variable results in a separate `--env KEY=VALUE` argument appended to the `docker run` command built internally by adr.

The logging behavior remains unchanged: the full docker command is printed to stdout before execution (this includes all --env arguments with their values).

---

## Behavior 5: Error Handling for Invalid Input

**Description**: The CLI should validate inputs and provide clear error messages.

Each behavior above defines specific error scenarios with exact error messages. All errors result in non-zero exit status and prevent container creation.

---

## Summary of New Options

| Flag | Short | Arguments | Description |
|------|-------|------------|-------------|
| `--env` | `-e` | `KEY=VALUE` | Set an environment variable |
| `--env-file` | (none) | `FILEPATH` | Load variables from a file |

Both flags are optional. If neither is provided, the command behaves as before.