# Commands Reference

Complete reference for all orchestration commands.

---

## Feature Workflow Commands

### `start <feature-name>`

Start a new feature workflow.

```bash
./orchestrate.sh start "add user authentication"
./orchestrate.sh start "refactor-api-layer"
```

- Normalizes feature name to kebab-case
- Initializes state with feature name
- Enters RESEARCH phase
- Sets model hint to `sonnet`

### `status`

Show current workflow state.

```bash
./orchestrate.sh status
```

Displays:
- Current feature and phase
- Branch names (main, codex)
- Checkpoint status
- Phase status details
- Autonomous mode state
- Model hint
- Next command suggestion

### `resume`

Resume workflow from current checkpoint with detailed instructions.

```bash
./orchestrate.sh resume
```

Shows:
- Current phase
- Recommended model
- What Claude should do
- Next commands to run

### `next`

Move to next phase (architect phase only).

```bash
./orchestrate.sh next
```

Transitions: `architect` → `planner`

### `approve <checkpoint>`

Approve a checkpoint to proceed.

```bash
./orchestrate.sh approve research  # GO decision
./orchestrate.sh approve plan      # Start execution
./orchestrate.sh approve review    # Start integration
```

| Checkpoint | Current Phase | Next Phase |
|------------|---------------|------------|
| `research` | research | architect |
| `plan` | planner | execution |
| `review` | reviewer | integrator |

### `reject research`

NO-GO decision - reject feature after research.

```bash
./orchestrate.sh reject research
```

- Archives research output
- Resets state to idle
- Research saved to `docs/research-archive/`

### `complete`

Complete integration phase and finish workflow.

```bash
./orchestrate.sh complete
```

- Merges Codex branch into main branch
- Marks workflow complete

### `reset`

Reset state to idle.

```bash
./orchestrate.sh reset
```

- Prompts for confirmation
- Clears all state
- Removes task files and outputs

---

## Bug-Fix Workflow Commands

### `bug "<title>" [severity]`

Start a bug-fix workflow.

```bash
./orchestrate.sh bug "Login fails on Safari" major
./orchestrate.sh bug "Typo in header" minor
./orchestrate.sh bug "Data corruption on save" critical
```

Severity options:
- `critical` - Data loss, security, complete feature broken
- `major` (default) - Feature partially broken, significant UX impact
- `minor` - Cosmetic, edge case, workaround exists

Actions:
- Creates GitHub issue with labels
- Creates branch `fix/<issue>-<description>`
- Enters TRIAGE phase

### `bug-status`

Show bug-fix workflow status.

```bash
./orchestrate.sh bug-status
```

### `bug-resume`

Resume bug-fix workflow.

```bash
./orchestrate.sh bug-resume
```

### `approve triage`

Approve triage checkpoint (root cause identified).

```bash
./orchestrate.sh approve triage
```

Transitions: `triage` → `plan`

### `bug-complete`

Complete bug-fix workflow (after PR created).

```bash
./orchestrate.sh bug-complete
```

---

## Autonomous Mode Commands

Enable unattended overnight work.

### `autonomous enable [timeout]`

Enable autonomous mode with optional timeout.

```bash
./orchestrate.sh autonomous enable       # No timeout
./orchestrate.sh autonomous enable 4h    # 4 hours
./orchestrate.sh autonomous enable 8h    # 8 hours
./orchestrate.sh autonomous enable 2h30m # 2.5 hours
```

**Requirement**: Research (or triage for bugfix) must be approved first.

Auto-approved checkpoints:
- `plan`
- `review`
- `integration`

Never auto-approved:
- `research` (feature) - always requires human GO/NO-GO
- `triage` (bugfix) - always requires human review

### `autonomous disable`

Disable autonomous mode.

```bash
./orchestrate.sh autonomous disable
```

### `autonomous extend <duration>`

Extend timeout.

```bash
./orchestrate.sh autonomous extend 2h
./orchestrate.sh autonomous extend 30m
```

### `autonomous status`

Check autonomous mode state.

```bash
./orchestrate.sh autonomous status
```

---

## Claude-Codex Auto-Orchestration

Launch Codex in background while Claude continues working.

### `claude-codex-auto`

Launch Codex in background, return immediately.

```bash
./orchestrate.sh claude-codex-auto
```

Claude can continue working on `[CLAUDE]` tasks.

### `claude-codex-auto --wait`

Launch Codex and wait for completion.

```bash
./orchestrate.sh claude-codex-auto --wait
```

Blocking mode - waits for all tasks to complete.

### `claude-codex-auto --check`

Check if Codex is done, finalize if ready.

```bash
./orchestrate.sh claude-codex-auto --check
```

Actions:
- If running: reports status
- If failed: triggers retry (max 2 attempts)
- If complete: commits and marks done

### `claude-codex-auto --status`

Alias for `codex-status`.

```bash
./orchestrate.sh claude-codex-auto --status
```

---

## Codex Manual Control

### `codex-dispatch [--auto]`

Dispatch Codex tasks.

```bash
./orchestrate.sh codex-dispatch         # Print commands
./orchestrate.sh codex-dispatch --auto  # Execute automatically
```

Manual mode prints commands to run in separate terminals.
Auto mode runs all tasks in parallel.

### `codex-status`

Check Codex task status.

```bash
./orchestrate.sh codex-status
```

Shows:
- Current state and progress
- Running processes
- Task files in queue
- Git changes

### `codex-commit [message]`

Commit Codex changes with attribution.

```bash
./orchestrate.sh codex-commit
./orchestrate.sh codex-commit "refactor: update handlers"
```

Default message: `refactor: apply Codex task changes`

### `codex-complete`

Mark Codex execution complete.

```bash
./orchestrate.sh codex-complete
```

---

## Claude Control

### `claude-complete`

Mark Claude execution complete.

```bash
./orchestrate.sh claude-complete
```

---

## Workflow Control

### `abort`

Soft stop - pause workflow (can resume later).

```bash
./orchestrate.sh abort
```

- Prompts for confirmation
- Saves abort state
- Can resume with `./orchestrate.sh resume`

### `rollback`

Hard reset - discard all changes, delete branches.

```bash
./orchestrate.sh rollback
```

**Warning**: Destructive operation!

- Requires typing `ROLLBACK` to confirm
- Discards all uncommitted changes
- Deletes feature branches (local only)
- Resets state to idle
- Does NOT delete GitHub issues

---

## Utilities

### `preflight`

Run pre-flight checks.

```bash
./orchestrate.sh preflight
```

Checks:
- Required tools (git, jq, gh)
- Git repository status
- GitHub CLI authentication
- State file status

Set `PREFLIGHT_STRICT=1` to fail on warnings.

### `budget`

Show context token budget estimate.

```bash
./orchestrate.sh budget
```

Estimates tokens for:
- CLAUDE.md
- state.json
- Active plan files
- Agent outputs
- Codex task files

Warns if over 50,000 token threshold.

### `model <phase> [complexity]`

Get recommended model for phase.

```bash
./orchestrate.sh model architect          # opus
./orchestrate.sh model execution simple   # haiku
./orchestrate.sh model execution complex  # opus
./orchestrate.sh model reviewer           # sonnet
```

Complexity options: `simple`, `medium` (default), `complex`

| Phase | simple | medium | complex |
|-------|--------|--------|---------|
| research | haiku | sonnet | sonnet |
| architect | opus | opus | opus |
| planner | sonnet | sonnet | sonnet |
| execution | haiku | sonnet | opus |
| reviewer | haiku | sonnet | sonnet |
| integrator | sonnet | sonnet | sonnet |

---

## Memory Commands

### `memory show`

Display accumulated learnings.

```bash
./orchestrate.sh memory show
```

### `memory add <type>`

Add a learning entry.

```bash
./orchestrate.sh memory add pattern
./orchestrate.sh memory add decision
./orchestrate.sh memory add failure
./orchestrate.sh memory add success
```

### `memory clear`

Clear all memory entries.

```bash
./orchestrate.sh memory clear
```

---

## Analytics Commands

### `logs`

List recent workflow logs.

```bash
./orchestrate.sh logs
```

### `logs <workflow-id>`

Show specific workflow log.

```bash
./orchestrate.sh logs workflow-2026-02-01-add-auth
```

### `analytics`

Show aggregate statistics across all workflows.

```bash
./orchestrate.sh analytics
```

### `metrics`

Show current workflow metrics.

```bash
./orchestrate.sh metrics
```

---

## Configuration

### `init`

Initialize configuration interactively.

```bash
./orchestrate.sh init
```

Creates `.agents/config.json` with project settings.

---

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `PREFLIGHT_STRICT` | Fail on warnings | `0` |

---

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Error or invalid command |
