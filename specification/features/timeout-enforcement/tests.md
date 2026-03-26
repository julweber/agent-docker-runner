# Timeout Enforcement - Tests

This document defines test cases for timeout enforcement functionality. All tests are integration tests that verify end-to-end behavior.

---

## Test-Behavior Traceability Matrix

| Behavior | Validating Test(s) | Coverage Status |
|----------|-------------------|-----------------|
| Behavior 1: Human-Readable Timeout Specification | Test 1.1 - Test 1.9 | ✓ Covered |
| Behavior 2: Exit Code Semantics | Test 2.1 - Test 2.4 | ✓ Covered |
| Behavior 3: Timeout Monitoring & Enforcement | Test 3.1 - Test 3.3 | ✓ Covered |
| Behavior 4: Edge Cases | Test 4.1 - Test 4.5 | ✓ Covered |
| Behavior 5: Session Mode Exemption | Test 5.1 - Test 5.2 | ✓ Covered |

---

## Test 1: Human-Readable Timeout Parsing

**Purpose**: Verify that various timeout formats are correctly parsed and applied.

### Test 1.1: Seconds Format (with unit)
**Procedure**:
1. Run `adr run --prompt "Test" pi --timeout 30s`
2. Verify container timeout is set to 30 seconds

**Expected Outcome**: 
- Timeout correctly parsed as 30 seconds
- Task terminates at 30-second mark if not completed

### Test 1.2: Seconds Format (without unit)
**Procedure**:
1. Run `adr run --prompt "Test" pi --timeout 60`
2. Verify container timeout is set to 60 seconds

**Expected Outcome**: 
- Timeout correctly parsed as 60 seconds (implicit seconds)
- Task terminates at 60-second mark if not completed

### Test 1.3: Minutes Format
**Procedure**:
1. Run `adr run --prompt "Test" pi --timeout 5m`
2. Verify container timeout is set to 5 minutes

**Expected Outcome**: 
- Timeout correctly parsed as 300 seconds
- Task terminates at 5-minute mark if not completed

### Test 1.4: Hours Format
**Procedure**:
1. Run `adr run --prompt "Test" pi --timeout 5m`
2. Verify container timeout is set to 5 minutes

**Expected Outcome**: 
- Timeout correctly parsed as 300 seconds
- Task terminates at 5-minute mark if not completed

### Test 2.4: Hours Format
**Procedure**:
1. Run `adr run --prompt "Test" pi --timeout 1h`
2. Verify container timeout is set to 1 hour

**Expected Outcome**: 
- Timeout correctly parsed as 3600 seconds
- Task terminates at 1-hour mark if not completed

### Test 1.5: Hours Format
**Procedure**:
1. Run `adr run --prompt "Test" pi --timeout 1h`
2. Verify container timeout is set to 1 hour

**Expected Outcome**: 
- Timeout correctly parsed as 3600 seconds
- Task terminates at 1-hour mark if not completed

### Test 1.6: Days Format
**Procedure**:
1. Run `adr run --prompt "Test" pi --timeout 1d`
2. Verify container timeout is set to 1 day

**Expected Outcome**: 
- Timeout correctly parsed as 86400 seconds
- Task terminates at 1-day mark if not completed

### Test 1.7: Invalid Unit Rejection
**Procedure**:
1. Run `adr run --prompt "Test" pi --timeout 1x` with invalid unit

**Expected Outcome**: 
- Error message: "Invalid timeout unit. Use s, m, h, or d"
- Exit code is 2 (invalid arguments)
- No container execution occurs

### Test 1.8: Malformed Value Rejection
**Procedure**:
1. Run `adr run --prompt "Test" pi --timeout abc` with non-numeric value

**Expected Outcome**: 
- Error message: "Malformed timeout value: 'abc'. Expected a number followed by an optional unit (s, m, h, d)"
- Exit code is 2 (invalid arguments)
- No container execution occurs

### Test 1.9: Decimal Value Rejection
**Procedure**:
1. Run `adr run --prompt "Test" pi --timeout 1.5h` with decimal value

**Expected Outcome**: 
- Error message: "Decimal timeout values are not supported (got: {value})"
- Exit code is 2 (invalid arguments)
- No container execution occurs

### Test 1.10: Mixed Case Acceptance
**Procedure**:
1. Run `adr run --prompt "Test" pi --timeout 1H` with uppercase unit

**Expected Outcome**: 
- Timeout correctly parsed as 3600 seconds
- Execution proceeds normally

---

## Test 2: Exit Code Semantics

**Purpose**: Verify that exit codes provide clear signal about execution outcome for scripting and CI/CD integration.

### Test 2.1: Successful Completion Returns Exit Code 0
**Procedure**:
1. Run `adr run --prompt "Say hello" pi --timeout 5m` with a task that completes quickly
2. Check exit code immediately after completion

**Expected Outcome**: 
- Exit code is exactly 0
- No error messages in stderr

### Test 2.2: Timeout Returns Exit Code 1
**Procedure**:
1. Run `adr run --prompt "Long task" pi --timeout 10s` with a task guaranteed to exceed timeout
2. Verify exit code after timeout occurs

**Expected Outcome**: 
- Exit code is exactly 1
- Error message in stderr: "Error: Task terminated due to timeout (max 10s exceeded)"

### Test 2.3: Invalid Arguments Return Exit Code 2
**Procedure**:
1. Run `adr run --prompt "Test" pi --timeout 1x` with invalid timeout format
2. Check exit code before container creation

**Expected Outcome**: 
- Exit code is exactly 2
- Error message indicates invalid argument format

### Test 2.4: Signal Interruption Returns Exit Code 130
**Procedure**:
1. Start a task or session
2. Send SIGINT (Ctrl+C) during execution
3. Check exit code after interruption

**Expected Outcome**: 
- Exit code is exactly 130 (standard for SIGINT)

---

## Test 3: Timeout Enforcement

**Purpose**: Verify that the system correctly monitors elapsed time and terminates containers when timeout is reached.

### Test 3.1: Container Terminates at Timeout
**Procedure**:
1. Create a task that would run longer than specified timeout (e.g., agent with long prompt or simulated delay)
2. Run `adr run --prompt "Long running task" pi --timeout 2m`
3. Monitor execution time and termination behavior

**Expected Outcome**: 
- Container terminates when 2-minute limit is reached
- Error message: "Error: Task terminated due to timeout (max {timeout} exceeded)" where `{timeout}` = "2m"
- Exit code is non-zero (1) indicating failure
- Any output produced before termination is captured in stdout

### Test 3.2: Graceful Shutdown Sequence (Manual Verification)
**Procedure**:
1. Create a container that ignores SIGTERM signals
2. Run with short timeout (e.g., `--timeout 30s`)
3. Observe system logs or use debugging tools to verify signal sequence

**Expected Outcome**: 
- SIGTERM sent immediately when timeout is reached
- Container given 10 seconds grace period
- If still unresponsive after 10 seconds, SIGKILL sent
- Container terminates forcefully

**Note**: This test requires manual verification using container inspection tools or system logs. Automated testing of signal behavior is out of scope for this specification.

### Test 3.3: Timeout During Startup
**Procedure**:
1. Use a slow-starting agent configuration or artificially delay startup
2. Run with very short timeout (e.g., `--timeout 5s`)
3. Verify timeout enforcement applies to entire lifecycle

**Expected Outcome**: 
- Timer starts from container creation, not after initialization completes
- Timeout can occur during image pull, config staging, or agent startup phases
- User sees appropriate timeout message regardless of phase where it occurred
- **Note**: This test implicitly validates Behavior 3 (Single Total Timeout) by confirming the countdown does not reset between lifecycle phases

---

## Test 4: Edge Cases

**Purpose**: Verify correct behavior for boundary conditions and unusual inputs.

### Test 4.1: Very Short Timeout Rejection
**Procedure**:
1. Run `adr run --prompt "Test" pi --timeout 3s` with timeout below minimum threshold

**Expected Outcome**: 
- Validation error message matches pattern: "Timeout value must be at least 5 seconds (got: {value})" where `{value}` = "3s"
- Exit code is 2 (invalid arguments)
- No container execution occurs

### Test 4.2: Zero Timeout Rejection
**Procedure**:
1. Run `adr run --prompt "Test" pi --timeout 0` or `--timeout 0s`

**Expected Outcome**: 
- Error message: "Timeout value must be greater than zero (got: {value})"
- Exit code is 2 (invalid arguments)
- No container execution occurs

### Test 4.3: Negative Timeout Rejection
**Procedure**:
1. Run `adr run --prompt "Test" pi --timeout -5m` with negative value

**Expected Outcome**: 
- Error message matches pattern: "Negative timeout values are not allowed (got: {value})" where `{value}` = "-5m"
- Exit code is 2 (invalid arguments)
- No container execution occurs

### Test 4.4: Very Long Timeout Acceptance
**Procedure**:
1. Run `adr run --prompt "Test" pi --timeout 7d` with extremely long timeout

**Expected Outcome**: 
- No warning message displayed
- Timeout accepted and applied as-is (604800 seconds)
- Execution proceeds normally

### Test 4.5: Independent Timers for Concurrent Tasks
**Procedure**:
1. Spawn two simultaneous tasks with different timeouts using separate container instances
2. Monitor both containers independently

**Expected Outcome**: 
- Each container tracked with its own timer
- Container A terminates at its timeout regardless of Container B status
- Container B terminates at its timeout regardless of Container A status
- No cross-contamination of timer state

---

## Test 5: Session Mode Exemption

**Purpose**: Verify that timeout enforcement does not apply to interactive session mode.

### Test 5.1: Timeout Flag Ignored in Session Mode
**Procedure**:
1. Start interactive session with timeout flag: `adr run --timeout 5m` (no --prompt)
2. Observe warning message and session behavior

**Expected Outcome**: 
- Warning displayed: "Timeout not applicable to interactive sessions, ignoring"
- Session starts normally without automatic termination
- User can continue interaction indefinitely until manual exit

### Test 5.2: Manual Exit Still Works in Session Mode
**Procedure**:
1. Start interactive session (with or without timeout flag)
2. Manually terminate using Ctrl+C or exit command

**Expected Outcome**: 
- Session terminates cleanly on user request
- Exit code indicates interruption (130 for SIGINT)
- No confusion with timeout behavior

---

## Test Execution Commands

### Quick Verification: All Timeout Formats
```bash
# Valid formats - should all succeed
adr run --prompt "Test" pi --timeout 30s && echo "✓ 30s passed"
adr run --prompt "Test" pi --timeout 60 && echo "✓ 60 (implicit s) passed"
adr run --prompt "Test" pi --timeout 5m && echo "✓ 5m passed"
adr run --prompt "Test" pi --timeout 1h && echo "✓ 1h passed"
adr run --prompt "Test" pi --timeout 1d && echo "✓ 1d passed"

# Invalid formats - should all fail with exit code 2
adr run --prompt "Test" pi --timeout 1x; [ $? -eq 2 ] && echo "✓ invalid unit rejected"
adr run --prompt "Test" pi --timeout abc; [ $? -eq 2 ] && echo "✓ malformed value rejected"
adr run --prompt "Test" pi --timeout 1.5h; [ $? -eq 2 ] && echo "✓ decimal rejected"
```

### Integration Test: Timeout Enforcement
```bash
# Create a task that exceeds timeout (e.g., agent with very long prompt)
adr run --prompt "$(yes 'Continue working' | head -n 10000)" pi --timeout 2m
echo "Exit code: $?"
# Expected: non-zero exit code indicating timeout
```

---

## Quality Gates

### Minimum Requirements for Merge
- All parsing tests (Test 1) must pass
- Exit code semantics verified (Test 2.x series)
- Timeout enforcement confirmed (Test 3.x series)
- Edge case handling correct (Test 4.x series)
- Session mode exemption tested (Test 5.1)

### Definition of "Passing"
A test passes when:
1. Expected exit code is returned
2. Error/warning messages match expected format
3. Container behavior matches specification (termination, timeout application)
4. No unexpected side effects or crashes occur

---

## Related Documents

- [Behaviors](./behaviors.md) — Functional requirements for timeout enforcement
- [Test Strategy](../../project/test-strategy.md) — Overall testing approach
