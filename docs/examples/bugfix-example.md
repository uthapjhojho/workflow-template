# Bug-Fix Workflow Example

A complete walkthrough of fixing a "login fails with special characters" bug.

---

## Phase 1: Start Bug-Fix

```bash
$ ./orchestrate.sh bug "Login fails when password contains special characters" major

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  STARTING BUG-FIX WORKFLOW
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[INFO] Creating GitHub issue...
[SUCCESS] Created issue #47

Issue:    #47
URL:      https://github.com/org/repo/issues/47
Branch:   fix/47-login-fails-when-password
Severity: major
Model:    sonnet

Next steps:
  1. Claude reads .agents/prompts/triage.md
  2. Reproduce and analyze the bug
  3. Output triage report to .agents/outputs/triage.md
  4. Then run './orchestrate.sh approve triage'
```

---

## Phase 2: Triage

Claude investigates the bug:

### Sample `.agents/outputs/triage.md`

```markdown
# Triage Report: Issue #47

## Bug Summary
Login fails when password contains characters like `&`, `+`, `=`

## Reproduction Steps
1. Create account with password `Test&123`
2. Log out
3. Attempt login with same password
4. Error: "Invalid credentials"

## Root Cause Analysis

### Investigation
1. Checked auth endpoint: `POST /api/auth/login`
2. Examined request payload encoding
3. Found issue in `src/auth/handlers.py`

### Root Cause
Password is URL-encoded twice. Special characters like `&` become `%26`,
then `%2526` on second encoding. Server decodes once, compares wrong value.

**Location**: `src/auth/handlers.py:45`
```python
# Bug: password already encoded by frontend
password = urllib.parse.quote(data.password)  # Double encoding!
```

## Recommended Fix
Remove server-side URL encoding. Frontend already handles this correctly.

## Impact Assessment
- Severity: Major (users cannot log in)
- Affected: ~5% of users with special char passwords
- Workaround: Use alphanumeric passwords (not acceptable)

## Ready for Fix: YES
```

### Approve Triage

```bash
$ ./orchestrate.sh approve triage

[SUCCESS] Triage approved! Moving to PLAN phase.
```

---

## Phase 3: Plan Fix

Claude creates fix plan:

### Sample Plan (`docs/plans/active/fix-47.md`)

```markdown
# Fix Plan: Issue #47

## Summary
Remove double URL encoding of password in login handler.

## Tasks

### [CLAUDE] Fix Auth Handler
Remove `urllib.parse.quote()` call from login handler.
- File: `src/auth/handlers.py`
- Line: 45

### [CLAUDE] Add Unit Tests
Add tests for special character passwords.
- File: `tests/test_auth.py`
- Test cases: `&`, `+`, `=`, `%`, space

### [CODEX] Update Integration Tests
Add end-to-end test for special char login.
- File: `tests/integration/test_login.py`
```

### Approve Plan

```bash
$ ./orchestrate.sh approve plan

[SUCCESS] Plan approved! FIX phase started.

Next steps:
  1. Claude: Implement the core fix
  2. At HARD STOP: ./orchestrate.sh codex-dispatch
  3. When done: ./orchestrate.sh claude-complete
```

---

## Phase 4: Fix

### Claude Implements Fix

```python
# src/auth/handlers.py - BEFORE
def login(data: LoginRequest):
    password = urllib.parse.quote(data.password)  # Bug!
    user = authenticate(data.email, password)
    ...

# src/auth/handlers.py - AFTER
def login(data: LoginRequest):
    # Password comes pre-encoded from frontend, no need to encode again
    user = authenticate(data.email, data.password)
    ...
```

### Claude Adds Unit Tests

```python
# tests/test_auth.py
@pytest.mark.parametrize("password", [
    "Test&123",
    "Pass+word",
    "Equal=Sign",
    "Percent%25",
    "With Space",
])
def test_login_special_characters(password):
    user = create_test_user(password=password)
    response = client.post("/api/auth/login", json={
        "email": user.email,
        "password": password
    })
    assert response.status_code == 200
```

### Dispatch Codex (if needed)

```bash
$ ./orchestrate.sh codex-dispatch

[INFO] Found 1 Codex task(s)
[INFO] Starting task: task-1.1-integration-tests.md
```

### Complete Fix Phase

```bash
$ ./orchestrate.sh claude-complete
[SUCCESS] Claude execution complete!

$ ./orchestrate.sh codex-complete
[SUCCESS] Codex execution complete!
[INFO] Moving to VERIFY phase.
```

---

## Phase 5: Verify

### Run Tests

```bash
$ pytest tests/ -v
================================ test session starts ================================
tests/test_auth.py::test_login_special_characters[Test&123] PASSED
tests/test_auth.py::test_login_special_characters[Pass+word] PASSED
tests/test_auth.py::test_login_special_characters[Equal=Sign] PASSED
tests/test_auth.py::test_login_special_characters[Percent%25] PASSED
tests/test_auth.py::test_login_special_characters[With Space] PASSED
tests/integration/test_login.py::test_e2e_special_char_login PASSED
================================ 6 passed in 2.34s ==================================
```

### Create PR

```bash
$ gh pr create --title "Fix: Login fails with special characters (#47)" \
  --body "## Summary
Fixes #47 - Removes double URL encoding of password in login handler.

## Changes
- Removed redundant \`urllib.parse.quote()\` call
- Added unit tests for special characters
- Added integration test

## Test Plan
- [x] Unit tests pass
- [x] Integration tests pass
- [x] Manual testing with special char password"

https://github.com/org/repo/pull/123
```

### Complete Bug-Fix

```bash
$ ./orchestrate.sh bug-complete

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  COMPLETING BUG-FIX
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[INFO] Plan archived to: docs/plans/archive/2026-02-01-fix-47.md
[INFO] Workflow log saved: logs/workflow-2026-02-01-fix-47.json
[INFO] Workflow summary added to memory

[SUCCESS] Bug-fix workflow complete!

Issue #47 will auto-close when PR is merged.

Next steps:
  1. Wait for PR review
  2. Address review comments if any
  3. Merge when approved

To start a new workflow: ./orchestrate.sh reset
```

---

## Commands Summary

| Phase | Command |
|-------|---------|
| Start | `./orchestrate.sh bug "Title" major` |
| Triage Done | `./orchestrate.sh approve triage` |
| Plan Done | `./orchestrate.sh approve plan` |
| Fix Done | `./orchestrate.sh claude-complete` |
| Codex Done | `./orchestrate.sh codex-complete` |
| Create PR | `gh pr create ...` |
| Finish | `./orchestrate.sh bug-complete` |
| Reset | `./orchestrate.sh reset` |

---

## Severity Levels

| Severity | Model Selection | Response Time |
|----------|-----------------|---------------|
| Critical | opus for triage/fix | Immediate |
| Major | sonnet for triage/fix | 1-2 days |
| Minor | haiku/sonnet | As scheduled |

---

## GitHub Integration

The workflow automatically:
- Creates GitHub issue with labels
- Creates fix branch from issue number
- PR auto-closes issue on merge
- Archives plan to `docs/plans/archive/`
