# Agent Docker Runner - Test Strategy

This document defines the testing approach and quality gates for Agent Docker Runner.

> **Note**: This specification is intentionally minimal at this stage. The primary goal is to establish a baseline that ensures core functionality works across all supported agents, with more detailed test requirements to be added as the project evolves.

## Current Test Strategy (Initial Phase)

### Integration Tests: Agent Orchestration Verification

Each supported agent must pass an integration test that verifies:
- Container creation succeeds
- Staged-config mechanism works correctly
- Agent initializes and executes within the container
- Headless mode functions properly
- Task completes successfully

#### Test Case: "Hello World"

**Purpose**: Quick verification that orchestration and container setup work for all supported agents.

**Test Procedure**:
1. Build Docker image for agent (if not already built)
2. Launch container in headless mode with prompt: `"Just say Hello!"`
3. Verify agent receives the prompt and produces output containing "Hello" or equivalent greeting
4. Confirm task completes without errors within reasonable timeout

**Expected Outcome**: Agent responds with a greeting message, confirming successful execution.

#### Supported Agents

| Agent | Test Command Pattern | Expected Output |
|-------|---------------------|-----------------|
| `pi` | `./run.sh --prompt "Just say Hello!" pi` | Greeting from pi agent |
| `opencode` | `./run.sh --prompt "Just say Hello!" opencode` | Greeting from opencode |
| `claude` | `./run.sh --prompt "Just say Hello!" claude` | Greeting from Claude Code |

### Test Execution

Run all agent integration tests:
```bash
# Build images first (optional if already built)
./build.sh pi
./build.sh opencode
./build.sh claude

# Run integration tests for each agent
./run.sh --prompt "Just say Hello!" pi && echo "✓ pi test passed" || echo "✗ pi test failed"
./run.sh --prompt "Just say Hello!" opencode && echo "✓ opencode test passed" || echo "✗ opencode test failed"
./run.sh --prompt "Just say Hello!" claude && echo "✓ claude test passed" || echo "✗ claude test failed"
```

## Future Test Strategy (To Be Defined)

The following testing areas are planned for future specification:

| Category | Status | Notes |
|----------|--------|-------|
| **Unit Tests** | TBD | Will be defined when programming languages are finalized |
| **Integration Test Coverage** | TBD | Additional integration scenarios beyond basic orchestration |
| **End-to-End (E2E) Tests** | TBD | Full workflow testing with complex multi-step tasks |
| **Contract Tests** | TBD | Agent compatibility verification across versions |
| **Coverage Expectations** | TBD | Target coverage percentages and requirements |
| **Testing Frameworks** | TBD | Tool selection pending language decisions |
| **Mocking Strategy** | TBD | How to handle external API calls in tests |
| **CI/CD Integration** | TBD | Automated test execution in pipelines |

## Quality Gates (Initial)

### Minimum Requirements for Merge

- All three agent integration tests must pass
- No container creation failures
- No config staging errors
- Task completes within timeout limits

### Definition of "Passing"

A test passes when:
1. Container starts successfully without errors
2. Agent receives and processes the prompt
3. Output contains expected response pattern (e.g., greeting)
4. Task exits cleanly with appropriate exit code
5. No security violations or capability errors occur

## Related Documents

- [Description](./description.md) — What the project does and why
- [Concepts](./concepts.md) — Domain terminology and key abstractions
- [Architecture](./architecture.md) — High-level technical design
- [Conventions](./conventions.md) — Coding standards and patterns