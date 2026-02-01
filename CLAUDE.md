# CLAUDE.md - Workflow Template

> **Last updated:** 2026-02-01 | **Current Phase:** Template Project

---

## CRITICAL RULES (Always Follow)

### Agent Workflow (Read First)
- Read `docs/AGENTS_WORKFLOW.md` at the start of every session
- Follow the planner/reviewer + executor split defined there
- If you are Claude-code, you are the executor: you DO all code edits/tests and you DO NOT delegate them back
- All changes must be accompanied by a handoff note in `docs/plans/active/output.md`

### Multi-Agent Orchestration (Claude + AI Agents)
When using the `.agents/` orchestration system:

1. **PLANNER phase MUST create AI Agent task files**
   - Create `.agents/codex-tasks/task-X.X-<name>.md` for each `[AI]` task
   - The `./orchestrate.sh approve plan` will BLOCK if no AI tasks exist

2. **EXECUTION phase requires coordination**
   - Claude works on `[CLAUDE]` tasks sequentially
   - Use `./.agents/dispatch-ai.sh --background` to run AI agents in parallel
   - Monitor with `./orchestrate.sh codex-status`
   - Attach to session: `./orchestrate.sh ai-attach`

3. **Model Selection (REQUIRED for Cost Savings)**
   - Check recommended model: `./orchestrate.sh model <phase> [complexity]`
   - Read `.agents/model-hint.txt` if it exists for current phase recommendation

   **When spawning Task tool subagents, ALWAYS use the `model` parameter:**
   | Phase/Task | Model | Reason |
   |------------|-------|--------|
   | architect | opus | Deep reasoning for architecture decisions |
   | planner, reviewer, integrator | sonnet | Good balance for planning/review |
   | execution (simple tasks) | haiku | Fast, cheap for straightforward coding |
   | execution (complex tasks) | opus | Complex code needs deep reasoning |
   | research, exploration | sonnet | Sufficient for codebase exploration |

   **Example Task tool usage:**
   ```
   Task tool with model: "haiku" for simple file edits
   Task tool with model: "sonnet" for planning subagents
   Task tool with model: "opus" only for complex architecture
   ```

   This saves significant costs by using Opus only when necessary.

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
│   ├── dispatch-ai.sh         # Multi-provider AI dispatch (GLM, DeepSeek, etc.)
│   ├── config.json            # Project configuration (includes AI provider settings)
│   ├── memory.md              # Cross-session learnings
│   ├── prompts/               # Phase prompts (parameterized)
│   ├── codex-tasks/           # AI task files
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

# AI Agent operations (GLM, DeepSeek, etc.)
./orchestrate.sh codex-dispatch     # Dispatch AI tasks
./orchestrate.sh codex-status       # Check AI progress
./orchestrate.sh codex-complete     # Mark AI done
./orchestrate.sh ai-attach          # Attach to tmux session
./orchestrate.sh ai-windows         # List AI sessions

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
