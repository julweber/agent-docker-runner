# Timeout Enforcement - Behaviors

This document defines the behavioral requirements for timeout enforcement in Agent Docker Runner.

## Overview

Timeout enforcement ensures that agent executions do not run indefinitely, protecting resources and enabling reliable CI/CD pipelines. The system enforces a maximum runtime with automatic container termination when exceeded.

---

## Behavior 1: Default Timeout Configuration

**Description**: When no explicit timeout is specified, the system applies a sensible default to prevent runaway processes while allowing reasonable execution time.

### Happy Path
- User runs `adr run --prompt "Task" pi` without `--timeout` flag
- System applies default timeout of 30 minutes (1800 seconds)
- Timer starts when container creation begins
- Task completes successfully within timeout → normal exit with code 0

### Error Cases
- Invalid timeout format provided → clear error message, exit non-zero
- Timeout value too small (< 5 seconds) → validation error with suggestion to increase

### Edge Cases
- Very long timeouts (e.g., 24h+) → accepted without warning
- Negative or zero timeout values → rejected with error

---

## Behavior 2: Human-Readable Timeout Specification

**Description**: Users can specify timeout using human-readable units for improved usability.

### Supported Formats
| Format | Example | Equivalent Seconds |
|--------|---------|-------------------|
| Seconds | `--timeout 30s` or `--timeout 30` | 30 |
| Minutes | `--timeout 15m` | 900 |
| Hours | `--timeout 2h` | 7200 |
| Days | `--timeout 1d` | 86400 |

### Happy Path
- User specifies `adr run --prompt "Task" pi --timeout 1h`
- System parses "1h" as 3600 seconds
- Timer configured for 3600 second limit
- Execution proceeds with correct timeout applied

### Error Cases
- Invalid unit (e.g., `--timeout 1x`) → error: "Invalid timeout unit. Use s, m, h, or d"
- Malformed value (e.g., `--timeout abc` or `--timeout -5m`) → error with guidance
- Missing number before unit (e.g., `--timeout h`) → error

### Edge Cases
- Mixed case units (`--timeout 1H`, `--timeout 1M`) → accepted as valid
- Decimal values (e.g., `--timeout 1.5h`) → **rejected** with error: "Decimal timeout values are not supported"

---

## Behavior 3: Timeout Monitoring & Enforcement

**Description**: The system monitors elapsed time and terminates the container when timeout is reached.

### Happy Path (Normal Completion)
- Container starts, timer begins counting from zero
- Agent completes work at t=15 minutes
- System detects completion before timeout threshold
- Container stops gracefully, exit code 0 returned to user

### Timeout Enforcement Flow
1. Timer reaches configured limit (e.g., 30 minutes elapsed)
2. Container Manager sends SIGTERM to container process
3. Agent receives signal and attempts graceful shutdown
4. If no response after **10 seconds** → send SIGKILL
5. Container terminates, exit code non-zero indicates timeout

### User Feedback
- Timeout occurs → stderr message: "Error: Task terminated due to timeout (max 30m exceeded)"
- Exit code is non-zero (e.g., 1) for programmatic detection
- stdout contains any output produced before termination

### Edge Cases
- Container unresponsive to SIGTERM after **10 seconds** → force kill with SIGKILL
- Timeout occurs during container startup → still counts toward total, user sees timeout message
- Multiple containers spawned rapidly → each tracked independently with own timer

---

## Behavior 4: Single Total Timeout (All Phases)

**Description**: A single unified timeout applies to the entire execution lifecycle from container creation through completion.

### Scope of Timeout
- **Included in countdown**:
  - Container image pull time (if not cached)
  - Container startup and initialization
  - Config staging and copying into container
  - Agent loading and prompt processing
  - Actual agent work execution
  - Result collection and cleanup

- **Not applicable**:
  - Time spent by user preparing command before execution
  - Network delays outside container (e.g., API provider latency)

### Rationale
- Simpler mental model for users
- Prevents bypassing timeout through slow initialization phases
- Ensures predictable resource usage in CI/CD environments

### Edge Cases
- Slow image pull (> timeout duration) → timeout occurs, user sees timeout message
- Config staging takes significant time → counts toward total (acceptable tradeoff)
- Agent startup is unusually slow → still enforced, may need longer timeout for complex agents

---

## Behavior 5: Exit Code Semantics

**Description**: Exit codes provide clear signal about execution outcome for scripting and CI/CD integration.

### Exit Code Assignments
| Exit Code | Meaning | Timeout Scenario |
|-----------|---------|------------------|
| 0 | Success | Task completed within timeout |
| 1 | Error/Failure | Timeout occurred OR other error (generic) |
| 2 | Invalid Arguments | Bad timeout format or value |

### Happy Path
- Successful completion → exit code 0
- User can check `$?` to detect success in scripts

### Error Handling
- Any failure (timeout, agent error, config issue) → exit code 1
- Detailed error message printed to stderr for debugging
- Scripts should check both exit code and stderr output for root cause

### Edge Cases
- Signal interruption (Ctrl+C during execution) → exit code 130 (standard convention)
- Container runtime errors → exit code 1 with specific error message

---

## Behavior 6: Session Mode Exemption

**Description**: Timeout enforcement applies only to headless task mode, not interactive session mode.

### Task Mode (Headless)
- `--timeout` flag is optional (defaults to 30m if omitted)
- Timeout is strictly enforced with automatic termination

### Session Mode (Interactive TUI)
- `--timeout` flag is ignored or rejected with warning
- No automatic timeout - session continues until user explicitly exits
- Rationale: Interactive sessions require user-controlled duration

### Validation Logic
```
if session mode and --timeout specified:
    warn "Timeout not applicable to interactive sessions, ignoring"
    continue without timeout
elif task mode and no --timeout specified:
    apply 30m default
elif task mode and --timeout specified:
    parse and enforce user-specified timeout
```

---

## Non-Goals (Explicitly Out of Scope)

- **Phase-specific timeouts**: No separate timeouts for staging vs execution phases
- **Dynamic timeout adjustment**: Cannot extend/reduce timeout mid-execution
- **Per-agent default overrides**: Default is global, not configurable per agent type
- **Timeout persistence**: Timeout setting does not carry over between runs

---

## Related Documents

- [Tests](./tests.md) — Test cases for timeout enforcement
- [Architecture](../../project/architecture.md) — Container Manager responsibilities
- [Concepts](../../project/concepts.md) — Task lifecycle and execution modes
