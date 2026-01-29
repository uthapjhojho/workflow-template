# [Plan Title]

> **Created:** YYYY-MM-DD
> **Status:** Ready for Execution

---

## Quick Start

```bash
/ralph-loop "Execute docs/plans/active/[name].md. Rules: (1) ONE task at a time, (2) Mark [x] when done, (3) Commit after each phase, (4) Write to output.md at HARD STOPs, (5) Output <promise>PLAN_COMPLETE</promise> when ALL done." --completion-promise "PLAN_COMPLETE" --max-iterations 30
```

---

## Execution Rules

1. **ONE task at a time** - Complete and verify before moving on
2. **Mark [x] immediately** - Edit this plan file after each task
3. **Commit per phase** - Git commit after each HARD STOP
4. **Log to output.md** - Write progress at HARD STOPs
5. **Test before marking complete** - Run verification commands

---

## Dev Implementation Phases

### Phase 1: [Phase Title]

**Task 1.1: [Task Name]**
- [ ] Implement: [description of what to build]
- [ ] Write unit test: [test description]
- [ ] Run unit test: `[command]`
- [ ] Log issues found: _pending_
- [ ] Fix issues: _if any_
- [ ] Mark complete when tests pass

**Task 1.2: [Task Name]**
- [ ] Implement: [description]
- [ ] Write unit test: [test description]
- [ ] Run unit test: `[command]`
- [ ] Log issues found: _pending_
- [ ] Fix issues: _if any_
- [ ] Mark complete when tests pass

**HARD STOP** - Commit Phase 1: `git add . && git commit -m "feat: Phase 1 - [description]"`

---

### Phase 2: [Phase Title]

**Task 2.1: [Task Name]**
- [ ] Implement: [description]
- [ ] Write unit test: [test description]
- [ ] Run unit test: `[command]`
- [ ] Log issues found: _pending_
- [ ] Fix issues: _if any_
- [ ] Mark complete when tests pass

**HARD STOP** - Commit Phase 2: `git add . && git commit -m "feat: Phase 2 - [description]"`

---

## Integration Testing

- [ ] Write integration test plan:
  - Test 1: [description]
  - Test 2: [description]
  - Test 3: [description]
- [ ] Execute integration tests
- [ ] Log issues found: _pending_
- [ ] Fix issues: _if any_
- [ ] Loop until all tests pass

**HARD STOP** - Commit integration tests: `git commit -m "test: Add integration tests"`

---

## Documentation

- [ ] Update code comments: Add comments explaining complex logic
- [ ] Write usage guide: Document how to use new features
- [ ] Update CLAUDE.md: Add any new commands or configurations

**HARD STOP** - Commit documentation: `git commit -m "docs: Update documentation"`

---

## Final Review and Cleanup

- [ ] Review code for consistency: Check naming, formatting, patterns
- [ ] Remove unused code: Delete dead code, unused imports
- [ ] Finalize documentation: Review all changes for clarity

---

## Deployment

- [ ] Prepare deployment scripts: _if applicable_
- [ ] Git commit changes: `git add . && git commit -m "feat: [final commit message]"`
- [ ] Git push to repository: `git push origin main`
- [ ] Update Notion documentation: Add changelog entry
- [ ] Deploy to production environment: _if applicable_
- [ ] Monitor post-deployment: Verify everything works

---

## Completion

When all tasks are done, output: `<promise>PLAN_COMPLETE</promise>`

---

## How to Use This Template

1. **Copy this template** to `docs/plans/active/[descriptive-name].md`
2. **Replace placeholders**:
   - `[Plan Title]` with your plan name
   - `YYYY-MM-DD` with today's date
   - `[name]` in Quick Start with your plan filename
   - `[Phase Title]`, `[Task Name]`, etc. with actual content
3. **Create output file**: Copy `output-template.md` to same folder as `output.md`
4. **Run Quick Start command** to begin execution

### Task Format Explained

Each task follows this workflow:
```
- [ ] Implement: What code to write
- [ ] Write unit test: What to test
- [ ] Run unit test: Command to run
- [ ] Log issues found: Record any problems
- [ ] Fix issues: Resolve problems
- [ ] Mark complete when tests pass
```

This ensures every task is:
1. Implemented
2. Tested
3. Verified working
4. Documented if issues found
