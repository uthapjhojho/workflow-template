# Multi-Agent Orchestration

This directory contains the orchestration system for coordinating Claude (sequential) and Codex (parallel) agents.

## Quick Start

```bash
# FEATURE WORKFLOW
./orchestrate.sh start slack-integration   # Start new feature

# BUG-FIX WORKFLOW
./orchestrate.sh bug "Button not working" major  # Start bug-fix (creates GH issue)

# COMMON COMMANDS
./orchestrate.sh status    # Show current state
./orchestrate.sh resume    # Resume workflow
./orchestrate.sh reset     # Reset to idle
```

## Workflow Types

### Feature Workflow (6 phases)
```
RESEARCH → ARCHITECT → PLANNER → EXECUTION → REVIEWER → INTEGRATOR
```

### Bug-Fix Workflow (4 phases)
```
TRIAGE → PLAN → FIX → VERIFY
   ↓                    ↓
gh issue            gh pr create
created             (auto-links)
```

## Commands

### Feature Workflow
| Command | Description |
|---------|-------------|
| `start <feature>` | Initialize new feature (begins with RESEARCH) |
| `approve research` | Approve research, proceed to build |
| `next` | Advance from architect phase |
| `approve plan` | Approve plan, start execution |
| `approve review` | Approve review, start integration |
| `complete` | Finish integration |

### Bug-Fix Workflow
| Command | Description |
|---------|-------------|
| `bug "<title>" [severity]` | Start bug-fix (creates GitHub issue) |
| `bug-status` | Show bug-fix status |
| `bug-resume` | Resume bug-fix workflow |
| `approve triage` | Approve triage (root cause found) |
| `approve plan` | Approve fix plan |
| `bug-complete` | Complete bug-fix (after PR created) |

**Severity:** `critical`, `major` (default), `minor`

### Common Commands
| Command | Description |
|---------|-------------|
| `status` | Show current state (auto-detects workflow) |
| `resume` | Get guidance for current phase |
| `codex-dispatch` | Launch Codex tasks |
| `codex-complete` | Mark Codex work done |
| `claude-complete` | Mark Claude work done |
| `reset` | Clear state for new workflow |

### Workflow Control
| Command | Description |
|---------|-------------|
| `abort` | Soft stop - pause workflow (can resume later) |
| `rollback` | Hard reset - discard changes, delete branches |
| `preflight` | Run pre-flight checks (git, tools, auth) |

### Autonomous Mode
| Command | Description |
|---------|-------------|
| `autonomous enable [timeout]` | Enable auto-approval (e.g., `enable 4h`) |
| `autonomous disable` | Return to manual approval mode |
| `autonomous extend <duration>` | Add time to timeout (e.g., `extend 2h`) |
| `autonomous status` | Check autonomous mode state |

**Timeout formats:** `4h`, `30m`, `2h30m`, `8h`, `1d`

**Safety gates:** Research (feature) or Triage (bug-fix) ALWAYS requires human approval.

## Directory Structure

```
.agents/
├── orchestrate.sh      # Main workflow script
├── state.json          # State machine (type, phase, tasks)
├── prompts/            # Agent role prompts
│   ├── researcher.md   # Feature research
│   ├── architect.md    # Architecture design
│   ├── planner.md      # Feature task planning
│   ├── reviewer.md     # Code review
│   ├── integrator.md   # Merge & finalize
│   ├── triage.md       # Bug-fix: root cause analysis
│   ├── bugfix-planner.md  # Bug-fix: fix planning
│   └── verify.md       # Bug-fix: verification & PR
├── codex-tasks/        # Generated Codex task files
│   ├── TEMPLATE.md     # Feature task template
│   └── BUGFIX-TEMPLATE.md  # Bug-fix task template
└── outputs/            # Agent outputs (triage, architecture, etc.)
```

## Agent Assignments

### Claude handles:
- Complex logic requiring judgment
- Tasks with dependencies
- Multi-file refactoring
- Architectural decisions
- Review and integration

### Codex handles:
- Well-defined, scoped tasks
- Independent implementations
- Test writing
- Documentation
- Boilerplate code

## State Machine

The `state.json` tracks:
- Current feature name
- Branch names (main + codex)
- Current phase
- Task status for each agent
- Checkpoint approvals
- History log

## Integration with Existing Tools

- **Plans:** Stored in `docs/plans/active/` (existing location)
- **Notion:** Updated via `.claude/skills/project-workflow/`
- **STATE.md:** Session state in `docs/handoff/STATE.md`

## Example Session

```bash
# 1. Start feature
./orchestrate.sh start slack-integration

# 2. Claude does ARCHITECT phase
# (creates .agents/outputs/architecture.md)
./orchestrate.sh next

# 3. Claude does PLANNER phase
# (creates plan + codex tasks)
# Human reviews plan
./orchestrate.sh approve plan

# 4. EXECUTION phase
# Claude works on sequential tasks
# When Claude hits HARD STOP:
./orchestrate.sh codex-dispatch
# (Run Codex in separate terminal)

# 5. When both complete:
./orchestrate.sh codex-complete
./orchestrate.sh claude-complete

# 6. REVIEWER phase
# Human reviews findings
./orchestrate.sh approve review

# 7. INTEGRATOR phase
# Claude merges and updates Notion
./orchestrate.sh complete

# Done! Create PR to main.
```
