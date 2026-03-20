# Agent Docker Runner - Domain Concepts

This document defines the key terms and abstractions used throughout the project.

## Core Entities

### Agent

An **Agent** is a coding AI that runs within an isolated container. The system currently supports four agent types:

- `pi` — pi coding agent
- `opencode` — opencode platform
- `claude` — Claude Code by Anthropic
- `codex` — OpenAI Codex CLI

Each agent type has its own configuration format and runtime requirements, but all share the same isolation model and execution semantics.

### Container

A **Container** is an isolated Docker execution environment that runs a single Agent instance. Containers provide:

- Filesystem isolation (only `/workspace` is writable from the host perspective)
- Capability restrictions (`--cap-drop ALL` with minimal additions)
- Security policies (`no-new-privileges`)
- Network access (full outbound for API calls)

Each Container runs exactly one Agent and has a unique lifecycle independent of other containers.

### Image

An **Image** is a Docker image containing the runtime environment for an Agent type. Images are:

- Named `coding-agent/<agent>:<tag>`
- Built locally (never pushed to registries)
- Versionable via tags for reproducibility
- Reusable across multiple Container instances

### Workspace

The **Workspace** is the host directory mounted as `/workspace` inside the container. It serves as:

- The shared boundary between host and container
- The only writable location from the host's perspective
- The execution context where agents read and write files

## Execution Modes

### Task

A **Task** is a headless, non-interactive execution of an Agent with a specific prompt or objective. Characteristics:

- Runs without TUI (terminal user interface)
- Terminates automatically when the Agent completes its work
- Has configurable maximum runtime (user-defined timeout)
- If actual runtime exceeds the maximum, the task is cancelled automatically
- Suitable for CI/CD pipelines and automated workflows

### Session

A **Session** is an interactive TUI session where a user engages with an Agent in real-time. Characteristics:

- Runs with full terminal interactivity
- Continues until the user explicitly ends it
- Allows iterative collaboration between human and agent
- Suitable for exploratory work, debugging, and learning

## Configuration Management

### Staged-Config

A **Staged-Config** is a temporary world-readable location where configuration directories are copied before being mounted into containers. This staging step is necessary because:

- Containers run with `--cap-drop ALL`, preventing the root process from reading files owned by other users
- The staged config is readable by all users, allowing the container to access it
- Once inside the container, the non-root `node` user (UID 1000) copies the config into its home directory

The staging process:
1. Copies host config directory to temporary world-readable location
2. Mounts staged location read-only into container
3. Container entrypoint copies config as non-root user
4. Original host config remains untouched

## Advanced Concepts (Future)

### Workflow

A **Workflow** is a coordinated sequence or network of Agent executions that work together toward a common goal. Workflows enable:

- **Chains**: Linear sequences where one agent's output feeds into the next
- **Hierarchies**: Tree-like structures with parent agents delegating to child agents
- **Architectures**: Complex topologies with parallel execution, branching, and merging
- **Tandem operation**: Multiple agents collaborating simultaneously on different aspects of a task

Workflows represent the orchestration layer that will allow teams to define sophisticated multi-agent systems.

## Relationships

### One-to-One Relationships

```
Agent → Container (one Agent runs in one Container)
Container → Image (one Container uses one Image)
Container → Workspace (one Container mounts one Workspace)
Task/Session → Container (one Task or Session creates one Container instance)
```

### Many-to-One Relationships

```
Multiple Images → One Agent type (different versions/tags of the same agent)
Multiple Containers → One Workspace (multiple containers can share a workspace)
Multiple Tasks/Sessions → One Workflow (future: multiple executions form a workflow)
```

## Lifecycle Concepts

### Task Lifecycle

1. **Initialization**: Container is created, staged-config is mounted, entrypoint executes
2. **Execution**: Agent receives prompt and begins work
3. **Completion or Timeout**: 
   - If agent finishes before timeout → task ends gracefully
   - If timeout exceeded → container is terminated automatically
4. **Cleanup**: Container resources are released

### Session Lifecycle

1. **Initialization**: Same as Task
2. **Interactive Phase**: User and Agent exchange messages via TUI
3. **Termination**: User explicitly ends the session (Ctrl+C, exit command)
4. **Cleanup**: Same as Task

## Related Documents

- [Description](./description.md) — What the project does and why
- [Architecture](./architecture.md) — Technical implementation details
- [Conventions](./conventions.md) — Coding standards and patterns
- [Test Strategy](./test-strategy.md) — Quality assurance approach
