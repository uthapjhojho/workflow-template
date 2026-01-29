# CLAUDE.md - Project Template

> **Last updated:** YYYY-MM-DD | **Current Phase:** (phase name)

---

## CRITICAL RULES (Always Follow)

### Agent Workflow (Read First)
- Read `docs/AGENTS_WORKFLOW.md` at the start of every session
- Follow the planner/reviewer + executor split defined there
- If you are Claude-code, you are the executor: you DO all code edits/tests and you DO NOT delegate them back
- All changes must be accompanied by a handoff note in `docs/plans/active/output.md`

### Multi-Agent Orchestration (Claude + Codex)
When using the `.agents/` orchestration system:

1. **PLANNER phase MUST create Codex task files**
   - Create `.agents/codex-tasks/task-X.X-<name>.md` for each `[CODEX]` task
   - The `./orchestrate.sh approve plan` will BLOCK if no Codex tasks exist

2. **EXECUTION phase requires coordination**
   - Claude works on `[CLAUDE]` tasks sequentially
   - Use `./.agents/dispatch-codex.sh --background` to run Codex in parallel
   - Monitor with `./orchestrate.sh codex-status`

3. **Model Selection**
   - Check recommended model: `./orchestrate.sh model <phase> [complexity]`
   - architect = opus, execution = sonnet/haiku, other = sonnet

### Workflow
1. **Confirm** - Restate understanding before execution
2. **Plan** - Write todo list before starting
3. **Build** - Implement the changes
4. **Test** - Validate before marking complete
5. **Summarize** - Explain what was done after completion

### Testing (REQUIRED Before Completion)
After building/modifying code, ALWAYS run these checks:

```bash
# 1. Syntax check
python -m py_compile <file>.py

# 2. Import test
python -c "from module import ClassName"

# 3. Run existing tests
pytest tests/ -v --tb=short
```

---

## Project Structure

```
project-root/
├── .agents/                   # Orchestration system
│   ├── orchestrate.sh         # Main workflow script
│   ├── dispatch-codex.sh      # Parallel Codex dispatch
│   ├── prompts/               # Phase prompts
│   ├── codex-tasks/           # Codex task files
│   └── outputs/               # Phase outputs
├── docs/
│   ├── plans/                 # Execution plans
│   └── AGENTS_WORKFLOW.md     # Workflow documentation
└── CLAUDE.md                  # This file
```

---

## Quick Reference

### Orchestration Commands

```bash
# Start new feature
./orchestrate.sh start <feature-name>

# Check status
./orchestrate.sh status

# Resume workflow
./orchestrate.sh resume

# Approve checkpoints
./orchestrate.sh approve research   # After research phase
./orchestrate.sh approve plan       # After planning phase
./orchestrate.sh approve review     # After review phase

# Codex operations
./orchestrate.sh codex-dispatch     # Dispatch Codex tasks
./orchestrate.sh codex-status       # Check Codex progress
./orchestrate.sh codex-complete     # Mark Codex done

# Claude operations
./orchestrate.sh claude-complete    # Mark Claude done

# Model recommendation
./orchestrate.sh model <phase> [simple|medium|complex]
```

### Running Locally

```bash
# (Add your project-specific run commands here)
```

---

## Current Focus

(Describe current development phase/feature)

---

## Important Notes

(Add project-specific notes, constraints, environment variables, etc.)
