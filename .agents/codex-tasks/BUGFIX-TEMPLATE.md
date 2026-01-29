# Codex Bugfix Task: [Task Name]

> **Issue:** #[number]
> **Branch:** `fix/[number]-[description]`
> **Task Type:** regression-test | similar-fix | doc-update | cleanup

---

## Context

This task is part of the bug fix for issue #[number]: [bug title].

**Root Cause:** [One-line summary from triage]

**Fix Applied:** [Brief description of what Claude fixed]

---

## Your Task

[Clear, specific instructions for what Codex should do]

---

## Files to Create/Modify

| File | Action | Description |
|------|--------|-------------|
| `path/to/file.py` | Create/Modify | [What to do] |

---

## Requirements

1. [Specific requirement]
2. [Another requirement]
3. [Another requirement]

---

## Acceptance Criteria

- [ ] [Testable criterion]
- [ ] [Another criterion]
- [ ] All existing tests still pass
- [ ] No linting errors

---

## Code Patterns to Follow

```python
# Example from existing codebase
# [Show relevant patterns]
```

---

## Do NOT

- Modify the core fix (Claude already did this)
- Change files outside your scope
- Skip running tests
- Introduce new dependencies without approval

---

## Verification Commands

```bash
# Run tests for this area
pytest tests/test_[module].py -v

# Check linting
ruff check [files]

# Verify no regressions
pytest tests/ -v --tb=short
```

---

## Commit Message

Use this format:
```
test: add regression test for bug #[number]
```

or for other types:
```
docs: update [area] for bug #[number] fix
fix: apply same fix to [location] (#[number])
style: cleanup [area] after bug #[number] fix
```

---

## Related Context

**GitHub Issue:** https://github.com/[org]/[repo]/issues/[number]

**Triage Report:** `.agents/outputs/triage.md`

**Fix Plan:** `docs/plans/active/fix-[number].md`

---

## When Done

1. Run verification commands above
2. Commit with appropriate message
3. Your changes will be merged with Claude's work

---

## Task Types Reference

| Type | Purpose | Example |
|------|---------|---------|
| `regression-test` | Write test that catches this bug | Test that fails without fix |
| `similar-fix` | Apply same fix to similar code | Same bug in other handlers |
| `doc-update` | Update docs affected by fix | Update API docs if behavior changed |
| `cleanup` | Code cleanup in affected files | Remove debug code, fix lint |
