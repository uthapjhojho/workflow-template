# CLAUDE.md - Workflow Template

> **Last updated:** 2026-02-01 | **Current Phase:** Template Project

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
# 1. Syntax check (adjust for your language)
python -m py_compile <file>.py
# or: node --check <file>.js
# or: go build ./...

# 2. Import/module test
python -c "from module import ClassName"
# or: node -e "require('./module')"

# 3. Run existing tests
pytest tests/ -v --tb=short
# or: npm test
# or: go test ./...
```

---

## Project Structure

```
project-root/
├── .agents/                   # Orchestration system
│   ├── orchestrate.sh         # Main workflow script
│   ├── dispatch-codex.sh      # Parallel Codex dispatch
│   ├── config.json            # Project configuration
│   ├── memory.md              # Cross-session learnings
│   ├── prompts/               # Phase prompts (parameterized)
│   ├── codex-tasks/           # Codex task files
│   ├── outputs/               # Phase outputs
│   └── logs/                  # Workflow execution logs
├── docs/
│   ├── GETTING_STARTED.md     # 5-minute quickstart
│   ├── COMMANDS.md            # Full command reference
│   ├── STATE_SCHEMA.md        # State file documentation
│   ├── ADOPTION.md            # Guide for adopting in existing projects
│   ├── AGENTS_WORKFLOW.md     # Workflow documentation
│   └── plans/                 # Execution plans
│       ├── active/            # Current plans
│       └── archive/           # Completed plans
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

# Memory and analytics
./orchestrate.sh memory show        # View learnings
./orchestrate.sh metrics            # Current workflow metrics
./orchestrate.sh analytics          # Cross-workflow stats
```

### Bug-Fix Workflow

```bash
# Start bug-fix (creates GitHub issue)
./orchestrate.sh bug "<title>" [critical|major|minor]

# Approve triage (root cause identified)
./orchestrate.sh approve triage

# Complete bug-fix (after PR created)
./orchestrate.sh bug-complete
```

### Autonomous Mode (Overnight Work)

```bash
# Enable after research/triage approval
./orchestrate.sh autonomous enable 8h

# Check status
./orchestrate.sh autonomous status

# Disable when done
./orchestrate.sh autonomous disable
```

---

## Template Customization

This is a template project for multi-agent orchestration. When adopting:

1. **Run init command** to configure project settings:
   ```bash
   ./orchestrate.sh init
   ```

2. **Customize prompts** if needed - placeholders like `{{PROJECT_NAME}}` are auto-replaced

3. **Add project-specific tests** to the Testing section above

4. **Update this section** with your project context

See `docs/ADOPTION.md` for detailed adoption instructions.

---

## Documentation

- [Getting Started](docs/GETTING_STARTED.md) - 5-minute quickstart
- [Commands Reference](docs/COMMANDS.md) - All 30+ commands
- [State Schema](docs/STATE_SCHEMA.md) - state.json documentation
- [Agents Workflow](docs/AGENTS_WORKFLOW.md) - Detailed workflow guide
- [Troubleshooting](docs/TROUBLESHOOTING.md) - Common issues and solutions
