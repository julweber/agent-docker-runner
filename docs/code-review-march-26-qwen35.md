# Code Review: Agent Docker Runner

**Date:** March 2, 2026  
**Reviewer:** Qwen3.5  
**Scope:** Full repository code review including shell scripts, Dockerfiles, configuration files, and documentation  

---

## Executive Summary

Agent Docker Runner is a well-designed CLI tool that provides secure containerization for AI coding agents (pi, opencode, claude). The project demonstrates strong security practices, clean architecture, and thoughtful user experience design. However, several areas need improvement including error handling consistency, testing infrastructure, documentation gaps, and operational robustness.

**Overall Rating:** ⭐⭐⭐⭐☆ (4/5)

### Key Strengths
- Excellent security model with capability dropping and non-root execution
- Clean separation of concerns between build/run scripts and agent-specific code
- Comprehensive documentation with clear usage examples
- Thoughtful config staging mechanism for handling `--cap-drop ALL` constraints
- Consistent bash scripting patterns across all agents

### Critical Issues Requiring Attention
1. **Missing error handling** in several critical paths (Docker daemon checks, file operations)
2. **No automated testing infrastructure** - relies entirely on manual verification
3. **Inconsistent variable naming** between scripts (`PROVIDER` vs `AGENT_PROVIDER`)
4. **Security vulnerability** in config staging with temporary files
5. **Missing validation** for Docker image existence before container creation

---

## Detailed Findings by Category

### 1. Security Analysis ⭐⭐⭐⭐☆

#### ✅ Strengths
- **Capability dropping**: All containers use `--cap-drop ALL` with minimal additions (SETUID, SETGID)
- **Non-root execution**: Agents run as UID 1000 (`node` user), not root
- **No privilege escalation**: `--security-opt no-new-privileges` enforced consistently
- **Read-only config mounts**: Configuration mounted read-only with staged-copy pattern
- **Network isolation**: Bridge network prevents inbound exposure

#### ⚠️ Issues Found

**CRITICAL: Temporary File Security (run.sh, agents/*/entrypoint.sh)**
```bash
# Current implementation in run.sh line ~105
STAGED_CONFIG=$(mktemp -d)
trap 'rm -rf "$STAGED_CONFIG"' EXIT
cp -r "$CONFIG_DIR/." "$STAGED_CONFIG/"
chmod -R a+rX "$STAGED_CONFIG"
```

**Problem:** World-readable permissions (`a+rX`) expose sensitive API keys to any user on the system. The trap cleanup is good, but the window of exposure is unnecessary.

**Recommendation:** Use restrictive permissions and copy as root before dropping privileges:
```bash
STAGED_CONFIG=$(mktemp -d)
trap 'rm -rf "$STAGED_CONFIG"' EXIT
cp -r "$CONFIG_DIR/." "$STAGED_CONFIG/"
chmod 700 "$STAGED_CONFIG"  # Only owner can access
# Entry point runs as root, copies to node-owned directory, then drops privileges
```

**MEDIUM: Docker Image Tag Validation (build.sh)**
```bash
TAG="latest"
# No validation that tag follows semantic versioning or naming conventions
```

**Problem:** Allows invalid tags like `latest!@#$` which could cause issues with registry operations or tooling.

**Recommendation:** Add regex validation:
```bash
if ! [[ "$TAG" =~ ^[a-zA-Z0-9._-]+$ ]]; then
  echo "Error: Invalid tag format '$TAG'. Use alphanumeric, dots, dashes, underscores." >&2
  exit 1
fi
```

**LOW: Hardcoded Agent Names (build.sh, run.sh)**
```bash
KNOWN_AGENTS=("pi" "opencode" "claude")
```

**Problem:** Adding a new agent requires editing multiple files. While this is intentional for safety, it creates maintenance burden.

**Recommendation:** Store known agents in a separate config file or use directory discovery:
```bash
# Option 1: Config file
source config/agents.conf

# Option 2: Directory-based discovery (safer)
KNOWN_AGENTS=($(ls -1 agents/ | grep -v '^\.'))
```

---

### 2. Error Handling & Robustness ⭐⭐⭐☆☆

#### ⚠️ Issues Found

**HIGH: Missing Docker Daemon Check (run.sh)**
```bash
# Line ~95: Validates image exists but doesn't check if Docker daemon is running
if ! docker image inspect "$IMAGE" > /dev/null 2>&1; then
  echo "Error: Docker image '$IMAGE' not found locally." >&2
  exit 1
fi
```

**Problem:** If Docker daemon is stopped, `docker image inspect` fails with confusing error. User gets "image not found" instead of "Docker daemon not running".

**Recommendation:** Add daemon check before image validation:
```bash
if ! docker info > /dev/null 2>&1; then
  echo "Error: Docker daemon is not running." >&2
  echo "Please start Docker Desktop or dockerd." >&2
  exit 1
fi

if ! docker image inspect "$IMAGE" > /dev/null 2>&1; then
  echo "Error: Docker image '$IMAGE' not found locally." >&2
  echo "Build it first with: adr build $AGENT" >&2
  exit 1
fi
```

**HIGH: Missing Error Handling for File Operations (run.sh)**
```bash
# Line ~106-107: No error handling for staging operations
STAGED_CONFIG=$(mktemp -d)
trap 'rm -rf "$STAGED_CONFIG"' EXIT
cp -r "$CONFIG_DIR/." "$STAGED_CONFIG/"
chmod -R a+rX "$STAGED_CONFIG"
```

**Problem:** If `cp` fails (permissions, disk full), script continues with empty config directory.

**Recommendation:** Add error handling:
```bash
STAGED_CONFIG=$(mktemp -d) || { echo "Error: Failed to create temp directory"; exit 1; }
trap 'rm -rf "$STAGED_CONFIG"' EXIT

if ! cp -r "$CONFIG_DIR/." "$STAGED_CONFIG/"; then
  echo "Error: Failed to stage config from $CONFIG_DIR" >&2
  rm -rf "$STAGED_CONFIG"
  exit 1
fi
```

**MEDIUM: Inconsistent Error Messages (run.sh, build.sh)**
```bash
# run.sh line ~60: Uses >&2 for errors
echo "Error: Unknown agent '$AGENT'. Supported agents: ${KNOWN_AGENTS[*]}" >&2

# build.sh line ~45: Also uses >&2 consistently - GOOD!
# But some scripts use stderr inconsistently
```

**Problem:** Some error messages go to stdout, others to stderr. This breaks scripting and automation.

**Recommendation:** Audit all echo statements in error paths and ensure they use `>&2`.

**LOW: Missing Input Validation (run.sh)**
```bash
# Line ~50-60: Validates workspace exists but doesn't check if it's a directory
if [[ ! -d "$WORKSPACE" ]]; then
  echo "Error: workspace directory does not exist: $WORKSPACE" >&2
  exit 1
fi
```

**Problem:** Doesn't validate that path is actually accessible (permissions) or is a real directory (not symlink to broken target).

**Recommendation:** Add accessibility check:
```bash
if [[ ! -d "$WORKSPACE" ]]; then
  echo "Error: workspace directory does not exist: $WORKSPACE" >&2
  exit 1
fi

if [[ ! -r "$WORKSPACE" || ! -w "$WORKSPACE" ]]; then
  echo "Error: workspace directory is not readable/writable: $WORKSPACE" >&2
  exit 1
fi
```

---

### 3. Code Quality & Maintainability ⭐⭐⭐☆☆

#### ✅ Strengths
- Consistent use of `set -euo pipefail` in all scripts
- Clear function separation with comments
- Good use of helper functions for common operations

#### ⚠️ Issues Found

**HIGH: Variable Naming Inconsistency (run.sh vs entrypoint.sh)**
```bash
# run.sh line ~20
PROVIDER=""
if [[ "$AGENT" == "pi" && -n "$MODEL" && "$MODEL" == */* ]]; then
  PROVIDER="${MODEL%%/*}"
  MODEL="${MODEL#*/}"
fi

# entrypoint.sh (pi) line ~15
if [[ -n "${AGENT_PROVIDER:-}" ]]; then
  PI_ARGS+=(--provider "${AGENT_PROVIDER}")
fi
```

**Problem:** `run.sh` uses `PROVIDER`, but passes it as `AGENT_PROVIDER` to container. This is confusing and error-prone.

**Recommendation:** Use consistent naming throughout:
```bash
# run.sh
if [[ "$AGENT" == "pi" && -n "$MODEL" && "$MODEL" == */* ]]; then
  AGENT_PROVIDER="${MODEL%%/*}"
  MODEL="${MODEL#*/}"
fi

# Then pass directly without renaming
CMD+=(--env "AGENT_PROVIDER=$AGENT_PROVIDER")
```

**HIGH: Magic Numbers (session-monitor.sh, task-monitor.sh)**
```bash
# session-monitor.sh line ~105
sleep 0.3

# task-monitor.sh line ~85
for _ in $(seq 1 30); do
    check_quit
done
# (30 * 0.1s = 3 seconds)
```

**Problem:** Magic numbers without explanation make code harder to maintain.

**Recommendation:** Use named constants:
```bash
POLL_INTERVAL=0.3
MAX_CHECKS_PER_REFRESH=30
REFRESH_RATE_SECONDS=$((POLL_INTERVAL * MAX_CHECKS_PER_REFRESH))
```

**MEDIUM: Missing Shebang Consistency (scripts/)**
```bash
# Most files use #!/usr/bin/env bash
# But some might use #!/bin/bash - check all files
```

**Problem:** `#!/bin/bash` may not work on macOS (uses different bash location).

**Recommendation:** Standardize on `#!/usr/bin/env bash` for portability.

**MEDIUM: Unnecessary Subshells (build.sh, run.sh)**
```bash
# Line ~10-15 in build.sh
cd "$(cd "$(dirname "$0")" && pwd)"

# Better approach: use BASH_SOURCE or script directory variable
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
```

**Problem:** Nested `cd` commands can cause issues with error handling and are harder to read.

**Recommendation:** Use `SCRIPT_DIR` pattern consistently (already done in some scripts, not others).

**LOW: Inconsistent Comment Style (all scripts)**
```bash
# Some use # ── Header ── style
# Others use # ========================================
# Still others use no headers at all
```

**Recommendation:** Establish and document a consistent comment header style.

---

### 4. Docker & Containerization ⭐⭐⭐⭐☆

#### ✅ Strengths
- Minimal base images (`node:lts-slim`) reduce attack surface
- Multi-stage patterns where appropriate (install tools, then clean up)
- Proper cleanup of apt cache in Dockerfiles
- Consistent workspace preparation across all agents

#### ⚠️ Issues Found

**MEDIUM: Duplicate Tool Installation (all Dockerfiles)**
```dockerfile
# All three Dockerfiles install identical tool sets:
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      gosu \
      curl \
      wget \
      jq \
      python3 \
      python3-pip \
      python3-venv \
 && pip3 install --break-system-packages uv \
 && curl -fsSL https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 \
      -o /usr/local/bin/yq \
 && chmod +x /usr/local/bin/yq \
 && rm -rf /var/lib/apt/lists/*
```

**Problem:** Code duplication violates DRY principle. If a tool needs updating, all three Dockerfiles must be changed.

**Recommendation:** Create base image or use multi-stage builds:
```dockerfile
# Option 1: Base image
FROM coding-agent/base AS pi-base
FROM node:lts-slim
COPY --from=pi-base /usr/local/bin/yq /usr/local/bin/yq
RUN apt-get install -y gosu curl wget jq python3 python3-pip python3-venv

# Option 2: Build script that generates Dockerfiles from template
```

**MEDIUM: Missing Health Checks (all Dockerfiles)**
```dockerfile
# No HEALTHCHECK instruction in any Dockerfile
```

**Problem:** Cannot programmatically verify container is ready to accept connections.

**Recommendation:** Add health check for interactive mode:
```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
  CMD pgrep -x pi || pgrep -x opencode || pgrep -x claude || exit 1
```

**LOW: Hardcoded User UID (all Dockerfiles)**
```dockerfile
# All scripts assume UID 1000 for node user
RUN useradd -m -u 1000 node
```

**Problem:** May conflict with host user on some systems.

**Recommendation:** Document this requirement clearly or use `--user` flag flexibility.

---

### 5. Testing & Quality Assurance ⭐⭐☆☆☆

#### ❌ Critical Gap: No Automated Testing

**Problem:** The project has zero automated tests. All verification is manual via the "Hello World" test described in test-strategy.md.

**Impact:**
- Regression bugs likely to slip through
- Cannot safely refactor code
- CI/CD integration impossible without adding tests first

**Recommendation:** Implement testing infrastructure:

```bash
# Proposed structure:
tests/
├── unit/
│   ├── test-build.sh      # Test build.sh argument parsing
│   └── test-run.sh        # Test run.sh validation logic
├── integration/
│   ├── test-pi-container.sh    # Verify pi container starts
│   ├── test-opencode-container.sh
│   └── test-claude-container.sh
└── e2e/
    └── test-headless-mode.sh   # Full workflow test

# Test runner script:
./run-tests.sh --unit      # Run unit tests
./run-tests.sh --integration  # Run integration tests (requires Docker)
./run-tests.sh --all       # Run all tests
```

**Minimum Viable Testing:**
1. **Unit tests for argument parsing**: Validate `--help`, invalid arguments, missing required args
2. **Integration test for container creation**: Verify containers start without errors
3. **Smoke test for headless mode**: Run agent with simple prompt and verify output contains expected text

---

### 6. Documentation ⭐⭐⭐⭐☆

#### ✅ Strengths
- Comprehensive README with usage examples
- Clear security model documentation
- Good explanation of config staging mechanism
- Well-structured specification documents

#### ⚠️ Issues Found

**MEDIUM: Missing Troubleshooting Section (README.md)**
```bash
# No section for common issues like:
# - "Container fails to start"
# - "API key not working"
# - "Permission denied errors on Linux"
```

**Recommendation:** Add troubleshooting section:
```markdown
## Troubleshooting

### Container fails to start with "image not found"
Build the image first: `adr build <agent>`

### Permission denied when writing files
On Linux, the container runs as UID 1000. Either:
- Use `chmod o+w ~/projects/myapp` on workspace directory
- Run `./fix_owner.sh` after agent creates files
```

**LOW: Incomplete Agent-Specific Documentation (README.md)**
```markdown
# Missing details for:
# - How to configure local LLMs in detail
# - Troubleshooting model selection issues
# - Environment variable overrides
```

**Recommendation:** Add subsection under "Custom Models and Local LLMs" with step-by-step setup.

---

### 7. Feature Implementation Scripts ⭐⭐⭐☆☆

#### Issues Found in `scripts/implement-feature.sh`

**HIGH: Missing Git Worktree Error Handling**
```bash
# Line ~65-68
if [ -d "$WORKTREE_PATH" ]; then
  echo "Worktree already exists at: $WORKTREE_PATH"
else
  echo "Creating worktree at: $WORKTREE_PATH"
  git worktree add -b "$BRANCH_NAME" "$WORKTREE_PATH" 
fi
```

**Problem:** If `git worktree add` fails (network issue, git config problem), script continues without error.

**Recommendation:** Add error handling:
```bash
if [ -d "$WORKTREE_PATH" ]; then
  echo "Worktree already exists at: $WORKTREE_PATH"
else
  echo "Creating worktree at: $WORKTREE_PATH"
  if ! git worktree add -b "$BRANCH_NAME" "$WORKTREE_PATH"; then
    echo "Error: Failed to create git worktree" >&2
    exit 1
  fi
fi
```

**MEDIUM: No Validation of Ralph Script (implement-feature.sh)**
```bash
# Line ~75-78
RALPH_SCRIPT="$WORKTREE_PATH/scripts/ralph/ralph.sh"

if [ ! -f "$RALPH_SCRIPT" ]; then
  echo "Error: ralph.sh not found at $RALPH_SCRIPT" >&2
  exit 1
fi
```

**Problem:** Checks for file existence but doesn't verify it's executable.

**Recommendation:** Add execute permission check:
```bash
if [ ! -x "$RALPH_SCRIPT" ]; then
  echo "Error: ralph.sh is not executable at $RALPH_SCRIPT" >&2
  exit 1
fi
```

#### Issues Found in `scripts/ralph/ralph.sh`

**HIGH: Signal Detection Regex Fragility**
```bash
if [[ "$line" == *'<promise>SUB-TASK-COMPLETE</promise>'* ]]; then
  DETECTED_SIGNAL="SUB-TASK-COMPLETE"
  break
fi
```

**Problem:** Relies on exact string matching. If agent output formatting changes, signal detection breaks silently.

**Recommendation:** Add logging and validation:
```bash
if [[ "$line" == *'<promise>SUB-TASK-COMPLETE</promise>'* ]]; then
  DETECTED_SIGNAL="SUB-TASK-COMPLETE"
  echo "✓ Detected SUB-TASK-COMPLETE signal at iteration $iteration" >> "$LOG_FILE"
  break
fi

# Add fallback: log if no signal detected after N lines
if [[ $line_count -gt 100 && -z "$DETECTED_SIGNAL" ]]; then
  echo "⚠ Warning: No recognized signal after 100 lines of output" >> "$LOG_FILE"
fi
```

**MEDIUM: Context Building Could Be More Efficient**
```bash
build_context() {
  local context=""
  for spec_file in "$PROJECT_ROOT"/specification/project/*.md; do
    if [ -f "$spec_file" ]; then
      context+="$(cat "$spec_file")"$'\n\n'
    fi
  done
  context+="$(cat "$PROMPT_FILE")"
  echo "$context"
}
```

**Problem:** Concatenating strings in bash is inefficient for large files. Could use process substitution or temp file.

**Recommendation:** Use temp file approach:
```bash
build_context() {
  local tmpfile=$(mktemp)
  cat "$PROJECT_ROOT"/specification/project/*.md > "$tmpfile" 2>/dev/null || true
  echo "" >> "$tmpfile"
  cat "$PROMPT_FILE" >> "$tmpfile"
  cat "$tmpfile"
  rm -f "$tmpfile"
}
```

**LOW: Hardcoded Iteration Count Validation**
```bash
MAX_ITERATIONS=5
# No validation that MAX_ITERATIONS is positive integer
```

**Recommendation:** Add validation:
```bash
if ! [[ "$MAX_ITERATIONS" =~ ^[0-9]+$ ]] || [[ "$MAX_ITERATIONS" -lt 1 ]]; then
  echo "Error: --max-iterations must be a positive integer" >&2
  exit 1
fi
```

---

### 8. Monitoring & Observability ⭐⭐⭐☆☆

#### Issues Found in `scripts/session-monitor.sh` and `task-monitor.sh`

**MEDIUM: Missing Color Detection (both monitors)**
```bash
# Both scripts use color codes unconditionally
CYAN="\033[36m"
BOLD="\033[1m"
```

**Problem:** Colors break output when piped to file or non-TTY environment.

**Recommendation:** Add color detection:
```bash
if [[ -t 1 ]]; then
  RESET="\033[0m"
  CYAN="\033[36m"
else
  RESET=""
  CYAN=""
fi
```

**LOW: No Logging to File (both monitors)**
```bash
# Monitors only display to stdout, no persistent logs
```

**Recommendation:** Add optional logging:
```bash
LOG_FILE="${LOG_FILE:-/dev/null}"
echo "$line" >> "$LOG_FILE"  # For each parsed event
```

---

## Recommendations Summary

### Priority 1: Critical (Fix Immediately)

| Issue | File(s) | Impact | Effort |
|-------|---------|--------|--------|
| Temporary file security vulnerability | run.sh, entrypoint.sh | Security risk | Low |
| Missing Docker daemon check | run.sh | Poor UX | Low |
| Missing error handling for file ops | run.sh, build.sh | Reliability | Low |
| No automated testing infrastructure | All | Regression risk | High |

### Priority 2: High (Fix Soon)

| Issue | File(s) | Impact | Effort |
|-------|---------|--------|--------|
| Variable naming inconsistency | run.sh, entrypoint.sh | Maintainability | Low |
| Signal detection fragility | scripts/ralph/ralph.sh | Reliability | Medium |
| Git worktree error handling | scripts/implement-feature.sh | Reliability | Low |

### Priority 3: Medium (Plan for Next Sprint)

| Issue | File(s) | Impact | Effort |
|-------|---------|--------|--------|
| Duplicate tool installation in Dockerfiles | All Dockerfiles | Maintainability | Medium |
| Missing health checks | All Dockerfiles | Observability | Low |
| Magic numbers without constants | Monitor scripts | Maintainability | Low |
| Inconsistent error messages | Various scripts | UX | Low |

### Priority 4: Low (Nice to Have)

| Issue | File(s) | Impact | Effort |
|-------|---------|--------|--------|
| Missing troubleshooting section | README.md | Documentation | Low |
| Hardcoded agent names | build.sh, run.sh | Maintainability | Medium |
| Color output without detection | Monitor scripts | UX | Low |

---

## Action Items

### For Next Release (v1.1)

1. **Security hardening**
   - [ ] Fix temporary file permissions in config staging
   - [ ] Add Docker daemon check to run.sh
   - [ ] Add error handling for all file operations

2. **Testing infrastructure**
   - [ ] Create test directory structure
   - [ ] Implement unit tests for argument parsing
   - [ ] Add integration test for container creation

3. **Code quality improvements**
   - [ ] Standardize variable naming (PROVIDER vs AGENT_PROVIDER)
   - [ ] Replace magic numbers with named constants
   - [ ] Add color detection to monitor scripts

### For Future Release (v1.2+)

1. **Docker optimization**
   - [ ] Create base image for shared tool installation
   - [ ] Add HEALTHCHECK instructions
   - [ ] Consider multi-stage builds for smaller images

2. **Feature enhancements**
   - [ ] Add troubleshooting section to README
   - [ ] Implement config file for known agents (reduce duplication)
   - [ ] Add logging capability to monitor scripts

3. **Documentation improvements**
   - [ ] Add detailed local LLM setup guide
   - [ ] Create architecture diagrams
   - [ ] Add contribution guidelines

---

## Conclusion

Agent Docker Runner is a well-architected project with strong security practices and thoughtful design. The primary areas for improvement are:

1. **Security hardening** of temporary file handling
2. **Testing infrastructure** to prevent regressions
3. **Error handling consistency** across all scripts
4. **Documentation gaps** in troubleshooting and advanced usage

The project demonstrates maturity in its security model and user experience design. With the recommended improvements, particularly around testing and error handling, it could serve as an excellent reference implementation for secure containerized application deployment.

---

## Appendix: Quick Reference

### Files Reviewed
- `build.sh` - Docker image building script
- `run.sh` - Container execution script  
- `agents/pi/Dockerfile`, `entrypoint.sh` - Pi agent configuration
- `agents/opencode/Dockerfile`, `entrypoint.sh` - Opencode agent configuration
- `agents/claude/Dockerfile`, `entrypoint.sh` - Claude agent configuration
- `scripts/implement-feature.sh` - Feature implementation launcher
- `scripts/ralph/ralph.sh` - Autonomous AI coding loop
- `scripts/session-monitor.sh` - Session progress monitor
- `scripts/task-monitor.sh` - Task progress monitor
- `scripts/link-skills.sh`, `setup.sh` - Project setup utilities

### Documentation Reviewed
- `README.md` - Main documentation
- `specification/project/*.md` - Project specifications
- `docs/multi-agent-feature.md` - Feature specification
- All SKILL.md files in `skills/` directory

---

*Review completed by Qwen3.5 on March 2, 2026*
