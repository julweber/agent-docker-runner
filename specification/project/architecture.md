# Agent Docker Runner - Architecture

This document describes the high-level technical design and system architecture of Agent Docker Runner.

## Overview

Agent Docker Runner is a CLI-based workflow tool that simplifies coding agent container management and orchestration. It provides a unified interface for running multiple AI coding agents in isolated, secure environments while maintaining flexibility for future expansion.

## System Architecture

### High-Level Structure

```
┌─────────────────────────────────────────────────────────────┐
│                    Host Machine                            │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              CLI Layer (Agent Docker Runner)         │   │
│  │  - Command parsing and validation                    │   │
│  │  - User interface (CLI arguments, prompts)           │   │
│  │  - Workflow orchestration coordination               │   │
│  └──────────────────────┬───────────────────────────────┘   │
│                         │                                     │
│              ┌──────────▼──────────┐                        │
│              │  Container Manager  │                        │
│  ┌──────────►  - Image selection    │                        │
│  │           - Container lifecycle  │                        │
│  │           - Resource allocation  │                        │
│  │           - Timeout enforcement  │                        │
│  │           - Cleanup              │                        │
│  │           └──────────┬──────────┘                        │
│  │                      │                                   │
│  │    ┌─────────────────▼─────────────────┐                │
│  │    │     Staging Mechanism             │                │
│  │    │  - Config directory staging        │                │
│  │    │  - Permission handling             │                │
│  └────┼───────────────────────────────────┘                │
│       │                                                   │
│  ┌────▼───────────────────────────────────────────────┐   │
│  │              Docker/Podman Daemon                  │   │
│  │  - Image management                                │   │
│  │  - Container lifecycle                             │   │
│  │  - Network configuration                           │   │
│  └────────────────────────────────────────────────────┘   │
└───────────────────────────────────────────────────────────┘

                    Inside Container (Isolated)
┌───────────────────────────────────────────────────────────┐
│  ┌─────────────────────────────────────────────────────┐  │
│  │              Agent Runtime                          │  │
│  │  - pi / opencode / claude (configurable)           │  │
│  │  - Model loading                                    │  │
│  │  - Prompt execution                                 │  │
│  └─────────────────────────────────────────────────────┘  │
│                                                           │
│  ┌─────────────────────────────────────────────────────┐  │
│  │              Agent Config                           │  │
│  │  - API keys (from staged-config)                   │  │
│  │  - Model selection                                  │  │
│  │  - Runtime settings                                 │  │
│  └─────────────────────────────────────────────────────┘  │
│                                                           │
│  ┌─────────────────────────────────────────────────────┐  │
│  │              /workspace (mounted)                   │  │
│  │  - Read/write access                                │  │
│  │  - Shared with host                                 │  │
│  └─────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────┘

                    External Systems
┌───────────────────────────────────────────────────────────┐
│  AI Model Providers (via container network)              │
│  - Anthropic API                                         │
│  - OpenRouter                                            │
│  - Ollama / LM Studio (local LLMs)                      │
│  - Custom providers                                      │
└───────────────────────────────────────────────────────────┘
```

## Component Descriptions

### CLI Layer

The command-line interface is the primary user-facing component. Responsibilities include:

- **Command parsing**: Interpret user arguments and options
- **Validation**: Ensure required parameters are provided, agent types are valid
- **Mode selection**: Determine task vs session mode based on flags
- **Parameter forwarding**: Pass user configurations to container runtime
- **Error handling**: Provide clear error messages for common issues

### Container Manager

The core orchestration component responsible for:

- **Image management**: Select appropriate Docker image based on agent type and version tag
- **Container lifecycle**: Create, start, monitor, and terminate containers
- **Resource allocation**: Configure mounts, environment variables, security options
- **Timeout enforcement**: Monitor task duration and enforce maximum runtime limits
- **Cleanup**: Ensure resources are released after execution completes

### Staging Mechanism

A specialized component that handles configuration directory access:

1. Copies host config directory to temporary world-readable location
2. Mounts staged location read-only into container
3. Container entrypoint copies config as non-root user (UID 1000)
4. Maintains security while enabling access under `--cap-drop ALL` constraints

### Agent Runtime

The execution environment inside each container:

- **Agent-specific**: Different Dockerfiles and entrypoints for pi, opencode, claude, codex
- **Non-root execution**: Runs as `node` user (UID 1000) for security
- **Workspace focus**: All file operations occur in `/workspace`
- **API connectivity**: Outbound network access to AI model providers

## Containerization Strategy

### Supported Platforms

The system supports multiple containerization runtimes:

- **Docker** (primary): Full feature set, widely available
- **Podman** (future): Rootless containers, Docker-compatible CLI

Both runtimes must be installed on the host machine for the system to function.

### Image Management

Images follow a consistent naming convention:
```
coding-agent/<agent>:<tag>
```

Where:
- `<agent>` is one of: `pi`, `opencode`, `claude`, `codex`
- `<tag>` defaults to `latest` but can be pinned for reproducibility

Images are built locally and never pushed to external registries.

### Security Model

Each container runs with minimal privileges:

| Control | Value |
|---------|-------|
| User | Non-root (UID 1000) |
| Capabilities | `--cap-drop ALL`, only SETUID/SETGID added |
| Privilege escalation | `no-new-privileges` enforced |
| Filesystem access | Only `/workspace` writable from host perspective |
| Network | Full outbound (for API calls), no inbound exposure |

## Execution Modes

### Task Mode (Headless)

```
User → CLI → Container Manager → Create container with prompt → Agent executes → Exit on completion or timeout
```

Characteristics:
- No TUI, fully automated
- Maximum runtime enforced
- Suitable for CI/CD pipelines

### Session Mode (Interactive)

```
User → CLI → Container Manager → Create container → TUI session begins → User-Agent interaction → Exit on user request
```

Characteristics:
- Full terminal interactivity
- No automatic timeout (user-controlled)
- Suitable for exploratory work

## Future Architecture Extensions

### Monitoring & Logging Layer

Future addition to track:
- Agent activity and commands executed
- Resource usage (CPU, memory, network)
- Execution results and artifacts
- Security events and policy violations

### Workflow Orchestrator Layer

Future component enabling multi-agent collaboration:
- **Chain executor**: Linear sequences of agent tasks
- **Hierarchy manager**: Parent-child delegation patterns
- **Parallel coordinator**: Concurrent agent execution with synchronization
- **Result aggregator**: Collect and merge outputs from multiple agents

### CI/CD Integration (Future)

Potential integrations:
- GitHub Actions runner
- GitLab CI job template
- Jenkins pipeline plugin
- Custom webhook handlers

## Deployment Models

### Local Development

```
Developer machine → Docker installed → Agent Docker Runner CLI → Local images
```

Requirements:
- Docker or Podman installed and running
- Sufficient local disk space for images
- Network access to AI model providers (or local LLM servers)

### Virtual Dev Environment

```
Remote VM / Containerized dev environment → Docker daemon → Agent Docker Runner → Remote execution
```

Use cases:
- Isolated development environments
- Secure sandboxes for sensitive projects
- Consistent CI/CD runner configurations

## Data Flow

### Task Execution Flow

1. User invokes CLI with agent type and prompt
2. CLI validates arguments and determines task mode
3. Container Manager selects appropriate image tag
4. Staging Mechanism prepares config directory
5. Docker/Podman creates container with security constraints
6. Agent Runtime initializes and receives prompt
7. Agent executes work within `/workspace`
8. Container Manager monitors duration against timeout
9. On completion or timeout, container is terminated
10. Results are returned to user

### Session Execution Flow

1. User invokes CLI with agent type (no prompt required)
2. CLI validates arguments and determines session mode
3. Container Manager selects appropriate image tag
4. Staging Mechanism prepares config directory
5. Docker/Podman creates container with security constraints
6. Agent Runtime initializes
7. TUI interface connects user to agent
8. User and agent exchange messages interactively
9. Session continues until user terminates
10. Container is terminated and cleaned up

## Related Documents

- [Description](./description.md) — What the project does and why
- [Concepts](./concepts.md) — Domain terminology and key abstractions
- [Conventions](./conventions.md) — Coding standards and patterns
- [Test Strategy](./test-strategy.md) — Quality assurance approach
