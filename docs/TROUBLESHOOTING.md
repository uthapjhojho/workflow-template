# Troubleshooting Guide

Common issues and solutions for the orchestration workflow.

---

## Quick Diagnostics

Run these commands first:

```bash
# Check system requirements
./orchestrate.sh preflight

# Check current state
./orchestrate.sh status

# View recent history
jq '.history[-5:]' .agents/state.json
```

---

## Common Issues

### 1. "Command not found: jq"

**Symptom**: Error when running any orchestrate command.

**Solution**: Install jq:

```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt install jq

# Fedora
sudo dnf install jq

# Windows (WSL)
sudo apt install jq
```

---

### 2. "Workflow already in progress"

**Symptom**: Cannot start new feature/bug.

**Solution**:

```bash
# Check what's running
./orchestrate.sh status

# Option 1: Complete or resume current workflow
./orchestrate.sh resume

# Option 2: Reset to start fresh (loses progress)
./orchestrate.sh reset
```

---

### 3. "No Codex tasks found"

**Symptom**: `codex-dispatch` says no tasks but plan has `[CODEX]` items.

**Cause**: Planner didn't create task files in `.agents/codex-tasks/`.

**Solution**:

```bash
# Check if files exist
ls -la .agents/codex-tasks/

# If empty, create tasks manually or have Claude re-run planner:
# 1. Read .agents/prompts/planner.md
# 2. Create task-X.X-name.md files for each [CODEX] task
```

**Template for task files**:
```markdown
# Task: [Description]

## Context
[Background from the plan]

## Requirements
- [Specific requirements]

## Files to Create/Modify
- `path/to/file.py`

## Success Criteria
- [How to verify task is complete]
```

---

### 4. "Failed to acquire state lock"

**Symptom**: Commands hang or fail with lock error.

**Cause**: Stale lock from crashed process.

**Solution**:

```bash
# Remove stale lock
rmdir .agents/state.json.lockdir

# Retry command
./orchestrate.sh status
```

**Prevention**: Locks auto-expire after 30 seconds.

---

### 5. "Not in a git repository"

**Symptom**: Commands fail with git errors.

**Solution**:

```bash
# Initialize git if needed
git init

# Or navigate to correct directory
cd /path/to/your/project
```

---

### 6. "GitHub CLI not authenticated"

**Symptom**: Bug-fix workflow fails to create issues.

**Solution**:

```bash
# Authenticate with GitHub
gh auth login

# Verify authentication
gh auth status
```

---

### 7. Phase Stuck in "in_progress"

**Symptom**: Phase never completes, `resume` shows same instructions.

**Cause**: Agent output not saved or approval not given.

**Solution**:

```bash
# Check what phase expects
./orchestrate.sh resume

# For research: create .agents/outputs/research.md, then:
./orchestrate.sh approve research

# For architect: create .agents/outputs/architecture.md, then:
./orchestrate.sh next

# For planner: create plan + codex tasks, then:
./orchestrate.sh approve plan
```

---

### 8. "Codex branch already exists"

**Symptom**: `codex-dispatch` fails on branch creation.

**Solution**:

```bash
# Delete existing branch and retry
git branch -D codex/your-feature
./orchestrate.sh codex-dispatch
```

---

### 9. Memory File Corrupted

**Symptom**: `memory show` displays garbled output.

**Solution**:

```bash
# Clear and recreate memory
./orchestrate.sh memory clear

# Verify
./orchestrate.sh memory show
```

---

### 10. State File Corrupted

**Symptom**: JSON parse errors on any command.

**Solution**:

```bash
# Validate JSON
jq '.' .agents/state.json

# If invalid, reset from template
cp .agents/state.json.template .agents/state.json

# Or manually fix the JSON error
```

---

## Recovery Procedures

### Soft Recovery: Abort and Resume

```bash
# Pause workflow (preserves state)
./orchestrate.sh abort

# Later, resume from where you left off
./orchestrate.sh resume
```

### Hard Recovery: Rollback

```bash
# WARNING: Destructive! Discards all changes
./orchestrate.sh rollback

# Type "ROLLBACK" to confirm
```

### Manual State Fix

```bash
# Edit state directly
vim .agents/state.json

# Common fixes:
# - Set phase: "idle" to reset
# - Set .phases.X.status: "pending" to re-run phase
# - Clear history if too large
```

---

## Debug Commands

### View Current State

```bash
# Full state
cat .agents/state.json | jq '.'

# Just phase info
jq '{phase, phases}' .agents/state.json

# Just execution status
jq '.phases.execution' .agents/state.json
```

### View History

```bash
# Last 10 events
jq '.history[-10:]' .agents/state.json

# Find specific events
jq '.history | map(select(.message | contains("error")))' .agents/state.json
```

### Check Outputs

```bash
# List output files
ls -la .agents/outputs/

# View specific output
cat .agents/outputs/research.md
```

### Check Codex Tasks

```bash
# List tasks
ls -la .agents/codex-tasks/

# Count tasks
find .agents/codex-tasks -name "task-*.md" | wc -l
```

---

## Getting Help

### Check Documentation

1. `docs/GETTING_STARTED.md` - Quick start
2. `docs/COMMANDS.md` - All commands
3. `docs/STATE_SCHEMA.md` - State structure
4. `docs/ARCHITECTURE.md` - System design

### Check Logs

```bash
# View workflow logs
./orchestrate.sh logs

# View specific log
./orchestrate.sh logs <workflow-id>

# View aggregate stats
./orchestrate.sh analytics
```

### Report Issues

If you encounter a bug:

1. Capture current state: `./orchestrate.sh status > debug.txt`
2. Capture state file: `cat .agents/state.json >> debug.txt`
3. Note the error message
4. Report at: https://github.com/your-org/workflow-template/issues

---

## FAQ

### Q: Can I run multiple workflows in parallel?

**A**: No, one workflow per project. Each `.agents/state.json` tracks one active workflow.

### Q: Can I skip phases?

**A**: Not recommended. Each phase builds on previous outputs. You can manually advance by editing `state.json`.

### Q: How do I change the recommended model?

**A**: Edit `.agents/config.json`:

```json
{
  "models": {
    "architect": "sonnet",
    "planner": "haiku"
  }
}
```

### Q: Can I use this without Codex?

**A**: Yes. Skip `codex-dispatch` and mark Claude as handling all tasks. Use `./orchestrate.sh claude-complete` when done.

### Q: How do I add custom phases?

**A**: See `docs/ARCHITECTURE.md` for extension points.
