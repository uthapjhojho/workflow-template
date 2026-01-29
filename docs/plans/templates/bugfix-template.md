# Fix Plan: [Bug Title]

> **Issue:** #[number]
> **Branch:** `fix/[number]-[description]`
> **Severity:** critical | major | minor
> **Created:** YYYY-MM-DD

---

## Quick Start

```bash
# Resume bug-fix workflow
./orchestrate.sh bug-resume
```

---

## Execution Rules

1. **Follow the phases** - Don't skip ahead
2. **Mark [x] when done** - Update this file after each task
3. **Test before proceeding** - Verify at each HARD STOP
4. **Commit per phase** - Small, atomic commits

---

## Root Cause Summary

[Copy from triage report - brief explanation of why bug occurs]

**Location:** `path/to/file.py:123`

---

## Fix Approach

[Description of the fix strategy]

---

## Phase 1: Core Fix [CLAUDE]

### Task 1.1 [CLAUDE] - Implement Fix

**Files:** `path/to/file.py`
**Accept:** Bug no longer reproducible

- [ ] Review root cause in triage report
- [ ] Implement fix at identified location
- [ ] Handle edge cases:
  - [ ] [Edge case 1]
  - [ ] [Edge case 2]
- [ ] Run existing tests: `pytest path/to/tests -v`
- [ ] Verify fix manually

**Commit:** `fix([scope]): [description] (#[number])`

---

## ⏸️ HARD STOP - Core Fix Complete

**Before proceeding:**
- [ ] Fix implemented and tested
- [ ] Existing tests pass
- [ ] No obvious regressions

**→ Dispatch Codex tasks:** `./orchestrate.sh codex-dispatch`

---

## Phase 2: Testing & Parallel Work

### Task 2.1 [CODEX] - Write Regression Test

**Codex File:** `.agents/codex-tasks/bugfix-[number]-regression-test.md`

**Accept:**
- Test fails when fix is reverted
- Test passes with fix applied
- Test properly documented

### Task 2.2 [CODEX] - Fix Similar Patterns

**Codex File:** `.agents/codex-tasks/bugfix-[number]-similar-fix.md`

**Accept:**
- All similar occurrences fixed
- Tests pass for each location

*(Skip if no similar patterns exist)*

### Task 2.3 [CLAUDE] - Integration Verification

**Accept:** Full test suite passes, no regressions

- [ ] Run full test suite: `pytest tests/ -v`
- [ ] Manual smoke test of related features
- [ ] Check for unintended side effects

---

## ⏸️ HARD STOP - All Tasks Complete

**Checklist:**
- [ ] Claude tasks done: `./orchestrate.sh claude-complete`
- [ ] Codex tasks done: `./orchestrate.sh codex-complete`
- [ ] All tests passing

---

## Phase 3: Finalize

### Task 3.1 [CLAUDE] - Update CHANGELOG

Add to `CHANGELOG.md` under `## [Unreleased]`:

```markdown
### Fixed
- [Brief description of fix] (#[number])
```

### Task 3.2 [CLAUDE] - Create PR

```bash
# Push branch
git push -u origin fix/[number]-[description]

# Create PR
gh pr create \
  --title "Fix: [Bug title]" \
  --body "## Summary
[One-line fix description]

## Root Cause
[Brief explanation]

## Changes
- [Change 1]
- [Change 2]

## Testing
- [x] Regression test added
- [x] All tests pass

Fixes #[number]

---
Generated with Claude Code"
```

---

## ⏸️ HARD STOP - Ready for Verification

Run: `./orchestrate.sh bug-verify`

---

## Completion Checklist

- [ ] Bug fixed and verified
- [ ] Regression test added
- [ ] Similar patterns fixed (if applicable)
- [ ] CHANGELOG updated
- [ ] PR created with "Fixes #[number]"
- [ ] Plan archived

---

## Archive

When complete, archive this plan:
```bash
mv docs/plans/active/fix-[number].md docs/plans/archive/$(date +%Y-%m-%d)-fix-[number].md
```

---

## How to Use This Template

1. **Copy template:**
   ```bash
   cp docs/plans/templates/bugfix-template.md docs/plans/active/fix-[number].md
   ```

2. **Replace placeholders:**
   - `[Bug Title]` - From GitHub issue
   - `[number]` - GitHub issue number
   - `[description]` - Kebab-case summary
   - `[scope]` - Module/component name
   - Severity, dates, file paths

3. **Customize phases:**
   - Remove Task 2.2 if no similar patterns
   - Add tasks if fix is complex
   - Adjust based on triage findings

4. **Create Codex task files:**
   - Copy from `.agents/codex-tasks/BUGFIX-TEMPLATE.md`
   - One file per `[CODEX]` task
