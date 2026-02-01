# Getting Started with Multi-Agent Orchestration

Get your first orchestrated workflow running in under 5 minutes.

## Prerequisites

- **git** - Version control
- **jq** - JSON parsing (install: `brew install jq` on macOS, `apt install jq` on Linux)
- **gh** (optional) - GitHub CLI for bug-fix workflow (`brew install gh`)

Run pre-flight checks to verify your setup:

```bash
./orchestrate.sh preflight
```

## Quick Start: Feature Workflow

### 1. Start a Feature

```bash
cd your-project
./orchestrate.sh start "add user authentication"
```

This initializes state and enters the **RESEARCH** phase.

### 2. Research Phase (Claude)

Claude reads `.agents/prompts/researcher.md` and investigates:
- Problem statement and user impact
- Existing alternatives
- Technical feasibility
- Build recommendation (GO/NO-GO)

Output: `.agents/outputs/research.md`

### 3. Approve or Reject

After reviewing the research:

```bash
# If worth building:
./orchestrate.sh approve research

# If not worth building:
./orchestrate.sh reject research
```

### 4. Architecture Phase (Claude)

Claude reads `.agents/prompts/architect.md` and designs:
- Component structure
- Data flow
- Task assignment preview (Claude vs Codex)

Output: `.agents/outputs/architecture.md`

```bash
./orchestrate.sh next  # Move to planning
```

### 5. Planning Phase (Claude)

Claude reads `.agents/prompts/planner.md` and creates:
- Master plan in `docs/plans/active/<feature>.md`
- Codex task files in `.agents/codex-tasks/`

```bash
./orchestrate.sh approve plan  # Start execution
```

### 6. Execution Phase (Claude + Codex)

Claude works on sequential `[CLAUDE]` tasks.
At HARD STOPs, dispatch Codex:

```bash
./orchestrate.sh codex-dispatch  # Manual mode
# or
./orchestrate.sh claude-codex-auto  # Background auto mode
```

When complete:

```bash
./orchestrate.sh claude-complete
./orchestrate.sh codex-complete
```

### 7. Review Phase (Claude)

Claude reads `.agents/prompts/reviewer.md` and reviews all changes.

```bash
./orchestrate.sh approve review  # Approve changes
```

### 8. Integration Phase (Claude)

Claude reads `.agents/prompts/integrator.md`:
- Merges branches
- Updates documentation

```bash
./orchestrate.sh complete  # Finish workflow
```

### 9. Reset for Next Feature

```bash
./orchestrate.sh reset
```

---

## Quick Start: Bug-Fix Workflow

### 1. Start a Bug-Fix

```bash
./orchestrate.sh bug "Login fails on Safari" major
```

Severity options: `critical`, `major` (default), `minor`

This creates a GitHub issue and branch automatically.

### 2. Triage Phase

Claude reads `.agents/prompts/triage.md`:
- Reproduces the bug
- Identifies root cause
- Assesses severity

```bash
./orchestrate.sh approve triage
```

### 3. Plan Phase

Claude creates fix plan with Codex tasks for tests.

```bash
./orchestrate.sh approve plan
```

### 4. Fix Phase

Claude implements core fix, Codex writes regression tests.

```bash
./orchestrate.sh claude-complete
./orchestrate.sh codex-complete
```

### 5. Verify Phase

Claude verifies fix, creates PR.

```bash
./orchestrate.sh bug-complete
```

---

## Essential Commands

| Command | Description |
|---------|-------------|
| `./orchestrate.sh status` | Show current workflow state |
| `./orchestrate.sh resume` | Resume from checkpoint with instructions |
| `./orchestrate.sh reset` | Reset to idle state |
| `./orchestrate.sh preflight` | Run pre-flight checks |

---

## Directory Structure

```
your-project/
├── .agents/
│   ├── orchestrate.sh       # Main orchestration script
│   ├── state.json           # Current workflow state
│   ├── prompts/             # Role prompts for each phase
│   ├── outputs/             # Phase outputs
│   ├── codex-tasks/         # Tasks for Codex parallel execution
│   └── logs/                # Workflow execution logs
├── docs/
│   └── plans/
│       ├── active/          # Current plan files
│       └── archive/         # Completed plans
└── CLAUDE.md                # Project instructions
```

---

## Next Steps

- Read [Commands Reference](COMMANDS.md) for all available commands
- Read [State Schema](STATE_SCHEMA.md) to understand workflow state
- Read [Adoption Guide](ADOPTION.md) to add orchestration to existing projects
- Read [Troubleshooting](TROUBLESHOOTING.md) for common issues
