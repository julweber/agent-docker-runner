# Agent Docker Runner - Conventions

This document defines coding style, naming conventions, and architectural patterns for Agent Docker Runner.

> **Note**: This specification is intentionally minimal. Many conventions are left open to be defined later as the project evolves and specific language/tool choices are made.

## File Naming Conventions

### Primary Convention: snake_case

All files in the project use **snake_case** naming:

- Shell scripts: `build.sh`, `run.sh`, `fix_owner.sh`
- Configuration files: `settings.json`, `models.json`, `opencode.json`
- Directory names: `config-examples/`, `specification/project/`
- Future code files: `agent_manager.sh`, `workflow_executor.py` (if applicable)

### Exceptions

- Docker images follow their own naming convention: `coding-agent/<agent>:<tag>`
- Agent-specific configuration may use different conventions (e.g., camelCase in JSON configs for external tools)

## Docker Image Naming

Images are named consistently using the following pattern:

```
coding-agent/<agent>:<tag>
```

Where:
- `<agent>` is one of: `pi`, `opencode`, `claude`
- `<tag>` defaults to `latest` but can be pinned for reproducibility (e.g., `1.2.3`)

Examples:
- `coding-agent/pi:latest`
- `coding-agent/claude:1.0.0`
- `coding-agent/opencode:v2.1`

## Configuration Files

### Structure

Agent configuration files follow the native format of each agent:

| Agent | Config Location | Format |
|-------|-----------------|--------|
| pi | `~/.pi/agent/settings.json`, `~/.pi/agent/models.json` | JSON |
| opencode | `~/.config/opencode/opencode.json` | JSON |
| claude | `~/.claude/settings.json`, `~/.claude.json` | JSON |

### Staged-Config Pattern

Configuration directories are staged to temporary world-readable locations before container execution. This pattern is enforced by the system and should not be bypassed in custom implementations.

## Open Conventions (To Be Defined)

The following conventions are intentionally left open for future specification:

| Category | Status | Notes |
|----------|--------|-------|
| **Programming Languages** | TBD | Language choice not yet finalized; may vary by component |
| **Linting & Formatting Tools** | TBD | Will be specified when languages are chosen |
| **Variable Naming** | TBD | Bash vs other language conventions pending |
| **Architectural Patterns** | TBD | Layered architecture, modular design patterns to be defined |
| **CLI Interaction Patterns** | TBD | How CLI layer interacts with container management |
| **Workflow Orchestration Patterns** | TBD | Chaining agents, hierarchy patterns for multi-agent systems |
| **Anti-Patterns to Avoid** | TBD | Domain-specific anti-patterns to be identified |
| **Libraries & Utilities** | TBD | Preferred tools (e.g., `jq`, `yq`) and restrictions |
| **Testing Frameworks** | TBD | Testing tooling choices pending language decisions |

## Related Documents

- [Description](./description.md) — What the project does and why
- [Concepts](./concepts.md) — Domain terminology and key abstractions
- [Architecture](./architecture.md) — High-level technical design
- [Test Strategy](./test-strategy.md) — Quality assurance approach