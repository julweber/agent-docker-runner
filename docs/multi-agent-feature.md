# Multi-Agent Feature Specification

## Overview

The **Multi-Agent Feature** extends the agent-docker-runner to support parallel execution of multiple AI coding agents (pi, opencode, claude) with comprehensive orchestration, monitoring, and state management capabilities.

---

## Core Concepts

### 1. Task-Based Execution Model

Instead of running a single container per invocation, the multi-agent feature introduces a **task-based execution model**:

- **Task ID**: A unique UUID v4 identifier that groups related containers
- **Container Index**: An integer (0, 1, 2...) identifying individual containers within a task
- **Container Naming Convention**: `agent-runner-{task_id}-{index}`

This enables:
- Launching multiple containers with the same prompt (scaling)
- Running different agents simultaneously on related tasks
- Tracking and grouping containers by their logical task

### 2. State Persistence Layer

The feature introduces a persistent state management system stored in `~/.agent-runner/`:

```
~/.agent-runner/
├── state.json           # Main state file tracking all containers
├── last_task.json       # Quick reference to the most recent task
└── logs/                # Container log files (optional)
    ├── {task_id_prefix}-{index}.log
```

**State Schema:**
```json
{
  "version": "1.0",
  "containers": [
    {
      "id": "agent-runner-abc123-0",
      "task_id": "abc123def456",
      "index": 0,
      "agent_type": "pi|opencode|claude",
      "workspace": "/path/to/workspace",
      "status": "running|completed|failed|exited",
      "started_at": "ISO8601 timestamp",
      "elapsed_seconds": null | integer,
      "exit_code": null | integer,
      "logs_path": "/path/to/log/file"
    }
  ]
}
```

### 3. Docker Label-Based Discovery

Each container is tagged with metadata labels for discovery and filtering:

| Label | Value | Purpose |
|-------|-------|--------|
| `app` | `agent-runner` | Application identifier for filtering |
| `task_id` | `<uuid>` | Groups containers by task |
| `index` | `<0,1,2...>` | Container position within task |
| `agent_type` | `pi\|opencode\|claude` | Agent type identification |
| `workspace` | `<path>` | Workspace directory path |
| `start_time` | `<ISO8601>` | Container start timestamp |
| `command` | `<prompt_truncated>` | Original prompt (first 50 chars) |

These labels enable:
- Docker-native filtering (`docker ps --filter label=app=agent-runner`)
- Task-based container grouping
- Resource tracking and monitoring

---

## Architecture Components

### Component Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    run_parallel.sh                          │
│                  (Wrapper Script)                           │
│  - Delegates to scripts/parallel.sh                         │
└──────────────────────┬──────────────────────────────────────┘
                       │ exec
                       ▼
┌─────────────────────────────────────────────────────────────┐
│                   scripts/parallel.sh                        │
│              (Main Orchestration Script)                     │
│  - Command dispatcher (launch, status, logs, stats, etc.)   │
│  - Argument parsing and validation                          │
│  - Task ID generation                                       │
│  - Color output formatting                                  │
└──────────────────────┬──────────────────────────────────────┘
                       │ sources
        ┌──────────────┼──────────────┐
        ▼              ▼              ▼
┌─────────────┐ ┌─────────────┐ ┌─────────────┐
│ launch.sh   │ │ state.sh    │ │ run.sh      │
│             │ │             │ │ (existing)  │
│ - Container │ │ - State     │ │ - Config    │
│   creation  │ │   file mgmt │ │   staging   │
│ - Docker    │ │ - CRUD ops  │ │ - Security  │
│   run cmd   │ │ - Runtime   │ │   options   │
│ - Labels    │ │   calc      │ │             │
└─────────────┘ └─────────────┘ └─────────────┘
```

### Component Responsibilities

#### 1. `run_parallel.sh` (Wrapper)
- Entry point for users
- Delegates all commands to `scripts/parallel.sh`
- Ensures consistent script directory resolution

#### 2. `scripts/parallel.sh` (Orchestrator)
**Commands:**
- **launch**: Parse arguments, generate task ID, invoke launch_container()
- **status**: Display container status in table or JSON format
- **logs**: Tail logs from specific or all containers
- **stats**: Show resource usage for running containers
- **stop**: Stop one or all containers
- **cleanup**: Remove finished containers and update state

**Features:**
- Argument parsing with validation
- Color-coded status output (when terminal)
- Task metadata tracking (`last_task.json`)

#### 3. `scripts/launch.sh` (Container Launcher)
**Responsibilities:**
- Validate Docker image exists locally
- Stage configuration directory (temp copy with proper permissions)
- Build Docker run command with labels and security options
- Launch container in background
- Wait for container to start (10s timeout)
- Record initial state
- Clean up staged config

**Security Options:**
```bash
--cap-drop ALL
--cap-add SETUID
--cap-add SETGID
--security-opt no-new-privileges
```

#### 4. `scripts/state.sh` (State Management)
**Functions:**
- `init_state()`: Initialize state file if missing
- `update_state()`: Add or update container entry
- `complete_container()`: Mark container as completed/failed with exit code
- `remove_container()`: Remove container from state
- `get_container()`: Query single container by ID
- `get_all_containers()`: List all containers (optional filter)
- `get_task_containers()`: Get containers by task_id
- `calculate_elapsed_seconds()`: Compute runtime from start time

---

## CLI Interface Specification

### Command Structure

```
./run_parallel.sh <command> [OPTIONS] [ARGUMENTS]
```

### Commands

#### 1. launch

**Purpose**: Launch one or more agent containers

**Syntax:**
```bash
./run_parallel.sh launch [OPTIONS] <agent> <prompt>
```

**Options:**
| Option | Description | Default |
|--------|-------------|---------|
| `-w, --workspace DIR` | Workspace directory | Current directory |
| `-c, --config DIR` | Config directory for agent(s) | Agent-specific default |
| `--tag TAG` | Docker image tag | `latest` |
| `-n, --num N` | Number of containers to launch | `1` |
| `-d, --detach` | Run in background mode | `false` |

**Agent-Specific Config Defaults:**
- `pi`: `$HOME/.pi`
- `opencode`: `$HOME/.config/opencode`
- `claude`: `$HOME/.claude`

**Examples:**
```bash
# Single container
./run_parallel.sh launch pi "Analyze this codebase"

# Multiple containers with same config (scaling)
./run_parallel.sh launch -n 3 opencode "Write tests"

# Detached mode for background execution
./run_parallel.sh launch --detach claude "Document API" &
```

#### 2. status

**Purpose**: Display container status

**Syntax:**
```bash
./run_parallel.sh status [OPTIONS]
```

**Options:**
| Option | Description |
|--------|-------------|
| `-f, --format FORMAT` | Output format: `table` or `json` |
| `--all` | Show all containers (including stopped/finished) |

**Output Format (Table):**
```
CONTAINER_ID                               STATUS     ELAPSED       WORKSPACE
------------                               ------     -------       ---------
agent-runner-abc123def456-0                running    45s           /home/user/project
agent-runner-def456abc789-0                completed  120s          /home/user/other
```

**Output Format (JSON):**
```json
{
  "version": "1.0",
  "containers": [...]
}
```

#### 3. logs

**Purpose**: View container logs

**Syntax:**
```bash
./run_parallel.sh logs [OPTIONS] [container-id]
```

**Behavior:**
- Without `container-id`: Lists all known containers with status
- With `container-id`: Shows/tails logs from that container
- For stopped containers: Shows last known state and cached logs if available

#### 4. stats

**Purpose**: Show resource usage

**Syntax:**
```bash
./run_parallel.sh stats [OPTIONS] [container-id]
```

**Output:**
```
CONTAINER           CPU %     MEM USAGE / LIMIT   NET I/O
agent-runner-abc123  5.2%      512MiB / 4GiB       1.2kB / 890B
```

#### 5. stop

**Purpose**: Stop containers

**Syntax:**
```bash
./run_parallel.sh stop [container-id]
```

**Behavior:**
- Without `container-id`: Stops all agent-runner containers
- With `container-id`: Stops specific container and updates state to "exited"

#### 6. cleanup

**Purpose**: Remove finished containers

**Syntax:**
```bash
./run_parallel.sh cleanup
```

**Behavior:**
- Finds all exited/finished containers with `app=agent-runner` label
- Removes them from Docker
- Updates state file to remove entries
- Reports number of containers removed

---

## Execution Flow

### Launch Flow (Single Container)

```
1. User invokes: ./run_parallel.sh launch pi "Analyze code"
   │
2. run_parallel.sh delegates to scripts/parallel.sh
   │
3. parallel.sh parses arguments, validates workspace/config
   │
4. Generate task ID (UUID v4)
   │
5. Call launch_container() from launch.sh
   │
6. Validate Docker image exists locally
   │
7. Stage config directory to temp location
   │
8. Build Docker run command with:
   - Labels (app, task_id, index, agent_type, workspace, start_time)
   - Security options (--cap-drop ALL, --security-opt no-new-privileges)
   - Volume mounts (workspace, config)
   - Environment variables (AGENT_HEADLESS=1, AGENT_PROMPT)
   │
9. Execute docker run in background
   │
10. Wait for container to start (max 10s polling)
    │
11. Call update_state() to record initial state
    │
12. Clean up staged config directory
    │
13. Return container ID to user
```

### Launch Flow (Multiple Containers)

```
1-5. Same as single container flow
   │
6. Loop NUM_CONTAINERS times:
   - Call launch_container() with incrementing index
   - Collect all container IDs
   │
7. Display summary of launched containers
   │
8. Save task metadata to last_task.json
```

### Status Flow

```
1. User invokes: ./run_parallel.sh status [--all] [-f json]
   │
2. Call init_state() to ensure state file exists
   │
3. If format=json:
   - Output entire state file (or filtered)
   │
4. If format=table:
   - Query Docker for running containers
   - Merge with state file data
   - Calculate elapsed time for each container
   - Display formatted table with color-coded status
```

---

## State Machine

### Container Status Transitions

```
                    ┌──────────┐
                    │  CREATED │ (container started)
                    └────┬─────┘
                         │
                         ▼
                    ┌──────────┐
                    │ RUNNING  │ ←─── Active execution
                    └────┬─────┘
                         │
          ┌──────────────┼──────────────┐
          │              │              │
          ▼              ▼              ▼
    ┌──────────┐  ┌──────────┐  ┌──────────┐
    │COMPLETED │  │  FAILED  │  │  EXITED  │
    │(exit=0)  │  │(exit≠0)  │  │ (SIGKILL)│
    └──────────┘  └──────────┘  └──────────┘
```

### State File Operations

| Operation | Trigger | Effect |
|-----------|---------|--------|
| `init_state()` | Any command | Creates empty state file if missing |
| `update_state()` | Container launch | Adds/updates container entry with status="running" |
| `complete_container()` | Container exit | Updates status to "completed" or "failed", records exit code |
| `remove_container()` | Cleanup | Removes entry from state array |

---

## Error Handling

### Validation Errors

| Condition | Error Message | Exit Code |
|-----------|---------------|----------|
| Docker not installed | `Error: Docker not found. Please install Docker.` | 1 |
| Image not built locally | `Error: Docker image 'coding-agent/pi:latest' not found locally. Build it first with: ./build.sh pi` | 1 |
| Workspace directory missing | `Error: Workspace directory does not exist: <path>` | 1 |
| Config directory missing | `Error: Config directory does not exist: <path>` | 1 |
| Unknown agent type | `Error: Unknown agent '<agent>'. Supported: pi, opencode, claude` | 1 |
| Missing prompt argument | `Error: Prompt is required.` | 1 |
| Task ID generation fails | `Error: Could not generate task ID` | 1 |

### Runtime Errors

| Condition | Handling |
|-----------|----------|
| Container fails to start (timeout) | Log error, clean up staged config, return failure |
| State file corruption | Attempt recovery, log warning, create new state |
| Docker daemon not running | Error message suggesting to start Docker |

---

## Security Considerations

### Container Isolation

1. **Capability Dropping**: `--cap-drop ALL` removes all Linux capabilities
2. **Minimal Capability Addition**: Only `SETUID` and `SETGID` added for user operations
3. **No New Privileges**: `--security-opt no-new-privileges` prevents privilege escalation
4. **Read-Only Config Mount**: Configuration mounted as read-only (`:ro`)
5. **Network Isolation**: Bridge network (default Docker isolation)

### Workspace Access

- Workspace is mounted at `/workspace` inside container
- Agent can read/write workspace files
- User should ensure workspace contains only intended files

---

## Performance Considerations

### Parallel Launch Overhead

- Each container launch involves:
  - Config staging (copy to temp): ~10-100ms depending on config size
  - Docker image inspection: ~5-20ms
  - Container creation and start: ~100-500ms
  - State file update: ~5-10ms

**Total per container**: ~150-630ms (sequential)

### Optimization Opportunities

1. **Parallel Config Staging**: Stage configs in parallel for multi-container launches
2. **Batch Docker Operations**: Use docker-compose or swarm for batch operations
3. **State File Locking**: Implement file locking to prevent race conditions
4. **Caching**: Cache Docker image inspection results

---

## Future Enhancements

### Phase 1: Core Features (Implemented)
- ✅ Basic parallel launch
- ✅ Status monitoring
- ✅ State persistence
- ✅ Container cleanup

### Phase 2: Enhanced Monitoring
- [ ] Real-time log aggregation with filtering
- [ ] Resource usage tracking over time
- [ ] Alerting on container failures
- [ ] Web dashboard interface

### Phase 3: Advanced Orchestration
- [ ] Task scheduling and queuing
- [ ] Retry logic for failed containers
- [ ] Resource limits per container (memory, CPU)
- [ ] Priority-based execution
- [ ] Dependency management between tasks

### Phase 4: Integration Features
- [ ] Prometheus metrics export
- [ ] API endpoint for programmatic control
- [ ] CI/CD integration hooks
- [ ] Notification system (email, Slack, etc.)

---

## Backward Compatibility

### With Existing `run.sh`

| Aspect | Compatibility |
|--------|---------------|
| Docker images | ✅ Same images (`coding-agent/<agent>:latest`) |
| Config structure | ✅ Same config directory layout |
| Environment variables | ✅ Same env vars (`AGENT_HEADLESS`, `AGENT_PROMPT`) |
| Workspace mounting | ✅ Same mount point (`/workspace`) |
| Security options | ✅ Same capability restrictions |

### Migration Path

Users can:
1. Continue using `run.sh` for single-container workflows
2. Use `run_parallel.sh` for multi-container scenarios
3. Share the same Docker images and config directories
4. Optionally add `--parallel` flag to `run.sh` (future enhancement)

---

## Testing Strategy

### Unit Tests

**Target**: Individual functions in state.sh, launch.sh

```bash
# Test state operations
test_init_state()
test_update_state()
test_complete_container()
test_remove_container()
test_calculate_elapsed_seconds()
```

### Integration Tests

**Target**: End-to-end container lifecycle

```bash
# Test container launch and status
test_launch_single_container()
test_launch_multiple_containers()
test_status_command_output()
test_logs_command_output()
test_cleanup_removes_containers()
```

### Manual Testing Scenarios

1. **Single Container Launch**: Verify basic functionality
2. **Multiple Containers**: Test scaling with `-n` flag
3. **Different Agents**: Launch pi, opencode, claude simultaneously
4. **Detached Mode**: Background execution and process management
5. **State Persistence**: Restart script, verify state survives
6. **Cleanup Flow**: Complete containers, run cleanup, verify removal
7. **Error Cases**: Missing image, invalid agent, bad config

---

## Documentation Structure

```
docs/
├── multi-agent-feature.md          # THIS FILE - Core specification
├── parallel-run-script-spec.md     # Implementation spec (detailed)
└── parallel-runner-docs.md         # User documentation
```

### Document Purposes

| Document | Audience | Content |
|----------|----------|---------|
| `multi-agent-feature.md` | Developers, Architects | Concepts, architecture, state machine, future roadmap |
| `parallel-run-script-spec.md` | Implementers | Detailed implementation steps, code examples |
| `parallel-runner-docs.md` | End Users | CLI reference, usage examples, troubleshooting |

---

## Glossary

| Term | Definition |
|------|------------|
| **Task** | A logical unit of work identified by a UUID, may contain one or more containers |
| **Container Index** | Integer identifying position within a task (0-based) |
| **State File** | JSON file tracking all container metadata (`~/.agent-runner/state.json`) |
| **Config Staging** | Process of copying config to temp directory for Docker mount |
| **Label** | Docker metadata key-value pair attached to containers |
| **Detached Mode** | Running containers in background without blocking the shell |

---

## Appendix A: Example Session

```
$ ./run_parallel.sh launch -n 2 pi "Analyze this codebase"
Task a1b2c3d4e5f6 started with 2 container(s):
  - agent-runner-a1b2c3d4e5f6-0
  - agent-runner-a1b2c3d4e5f6-1
Use 'parallel.sh status' to view containers

$ ./run_parallel.sh status
CONTAINER_ID                               STATUS     ELAPSED       WORKSPACE
------------                               ------     -------       ---------
agent-runner-a1b2c3d4e5f6-0                running    15s           /home/user/project
agent-runner-a1b2c3d4e5f6-1                running    15s           /home/user/project

$ ./run_parallel.sh logs agent-runner-a1b2c3d4e5f6-0
[Container output...]

$ ./run_parallel.sh status --all
CONTAINER_ID                               STATUS     ELAPSED       WORKSPACE
------------                               ------     -------       ---------
agent-runner-a1b2c3d4e5f6-0                completed  120s          /home/user/project
agent-runner-a1b2c3d4e5f6-1                running    105s          /home/user/project

$ ./run_parallel.sh cleanup
Removing: agent-runner-a1b2c3d4e5f6-0
Cleanup complete. Removed 1 container(s)
```

---

## Appendix B: State File Evolution Example

**Initial (empty):**
```json
{"version":"1.0","containers":[]}
```

**After launching one container:**
```json
{
  "version": "1.0",
  "containers": [
    {
      "id": "agent-runner-abc123-0",
      "task_id": "abc123def456",
      "index": 0,
      "agent_type": "pi",
      "workspace": "/home/user/project",
      "status": "running",
      "started_at": "2026-02-28T21:00:00+01:00",
      "elapsed_seconds": 5,
      "exit_code": null,
      "logs_path": "/home/user/.agent-runner/logs/abc123-0.log"
    }
  ]
}
```

**After container completes:**
```json
{
  "version": "1.0",
  "containers": [
    {
      "id": "agent-runner-abc123-0",
      "task_id": "abc123def456",
      "index": 0,
      "agent_type": "pi",
      "workspace": "/home/user/project",
      "status": "completed",
      "started_at": "2026-02-28T21:00:00+01:00",
      "elapsed_seconds": 125,
      "exit_code": 0,
      "logs_path": "/home/user/.agent-runner/logs/abc123-0.log"
    }
  ]
}
```

---

*Document Version: 1.0*
*Last Updated: 2026-02-28*
*Status: Specification Complete, Implementation In Progress*