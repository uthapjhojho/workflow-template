# Multi-Agent Dev Workflow

This file lives at `docs/AGENTS_WORKFLOW.md`.
Purpose: a shared, single source of truth for coordinating two coding agents.

If you are Claude-code in VS Code, follow these instructions exactly.

---

## Workflow Types

| Type | Command | Phases | Use Case |
|------|---------|--------|----------|
| **Feature** | `./orchestrate.sh start <name>` | Research → Architect → Planner → Execute → Review → Integrate | New features, enhancements |
| **Bug-fix** | `./orchestrate.sh bug "<title>"` | Triage → Plan → Fix → Verify | Bug fixes with GitHub integration |

---

## Repo Location and Key Directories

- Repo root: `whatsapp-mcp/`
- Services: `services/` (deployable apps)
- Libraries: `libs/` (shared code)
- Tools: `tools/` (MCP server, dev tooling)
- Docs: `docs/` (plans, runbooks, architecture)
- Active plans: `docs/plans/active/`
- Shared status log: `docs/plans/active/output.md`

## Working Agreement (Non-Negotiable)

1) Single source of truth: `docs/plans/active/output.md`
2) Clear file ownership: no overlapping edits without explicit handoff
3) Small, atomic changes: 1-2 files per chunk when possible
4) Short-lived branches: merge back to `main` after each chunk
5) Handoff notes after each chunk using the template below
6) If you are not the executor, you DO NOT edit code unless explicitly asked
7) If you are the executor, you DO all edits/tests and DO NOT delegate them back
8) Log each failed command or approach in `docs/plans/active/output.md` with command, error, and resolution; note known pre-existing failures once and reference later

## Ownership Split (Planner/Reviewer + Executor)

- Codex CLI (this agent): planner + reviewer only
  - Maintains plans/checklists in `docs/plans/active/`
  - Reviews diffs and test outputs
  - Calls out risks, regressions, and missing tests
  - Does not edit code unless explicitly requested
- Claude-code (VS Code): executor
  - Makes all code changes
  - Runs tests for touched areas
  - Writes handoff notes and test results

If code changes are needed from Codex, that must be explicitly requested.

## Daily Flow (Per Feature)

1) Agree on feature scope and boundaries
2) Each agent creates a short-lived branch
3) Work in small chunks, avoid overlapping files
4) Write a handoff note in `docs/plans/active/output.md`
5) Merge to `main` after each chunk
6) Pull latest `main` before the next chunk

## Handoff Note Template (Required)

Paste into `docs/plans/active/output.md` after each chunk.

### Standard Format

```
[Agent: Codex|Claude]
Task: <short>
Files: <paths>
Change: <behavior>
Tests: <command + result>
Risks: <if any>
Next: <what's left>
```

### Compressed Format (for token savings)

Use this format when context budget is tight:

```
[C] feat: <title> | files: <paths> | <test result> | next: <what's left>
```

Examples:
```
[C] feat: centralize templates | files: 7 handlers, templates/* | 481 pass | next: pilot ResponseFormatter
[X] refactor: algo handler | files: algo_handler.py | py_compile OK | next: test imports
[C] fix: import cycle | files: bot.py, services/intent.py | pytest OK | next: deploy
```

Legend:
- `[C]` = Claude, `[X]` = Codex
- `feat/fix/refactor/docs` = change type
- `| ` = field separator
- Test result: `N pass`, `N fail`, `py_compile OK`, `skipped`

## Conflict Rule

- If both agents need the same file, stop and decide ownership.
- One agent edits; the other waits or pivots to a different task.
- If a conflict happens, the agent who owns the file resolves it.

## Minimal Test Discipline

- Run tests only for the area you touched.
- Always record tests (or explicitly say "not run") in the handoff note.

## Example Split (Current Repo)

- Codex: plans + reviews only
- Claude: all code changes and tests

## Codex Task Scope (Parallel Execution)

### What Codex Should Handle

Expand Codex tasks to include parallelizable work:

| Task Type | Suitable for Codex? | Notes |
|-----------|---------------------|-------|
| Handler updates (refactors) | Yes | Well-scoped, independent files |
| Test file creation | Yes | Can run in parallel with impl |
| Documentation updates | Yes | Independent of code |
| Boilerplate generation | Yes | CRUD handlers, simple scaffolds |
| Simple renames/moves | Yes | Pattern-based changes |
| Type annotation additions | Yes | Independent per file |

### What Claude Should Handle

Keep these tasks sequential with Claude:

| Task Type | Reason |
|-----------|--------|
| Architecture decisions | Needs full context |
| Cross-file dependencies | Order matters |
| Complex debugging | Requires investigation |
| Integration testing | Depends on all changes |
| Security-sensitive code | Needs careful review |

### Codex Task Guidelines

1. **Keep tasks atomic** - One file or one logical unit per task
2. **Include test file awareness** - List related test files in task
3. **No git commands** - Sandbox blocks `.git/` access
4. **Clear acceptance criteria** - Checklist of what "done" means
5. **Use TEMPLATE.md** - Copy from `.agents/codex-tasks/TEMPLATE.md`

### Codex CLI Commands

```bash
# Manual dispatch (prints commands)
./orchestrate.sh codex-dispatch

# Auto-execute all tasks in parallel
./orchestrate.sh codex-dispatch --auto

# Or use standalone script
./.agents/dispatch-codex.sh

# Commit Codex changes (after tasks complete)
./orchestrate.sh codex-commit "refactor: update handlers"

# Mark Codex phase complete
./orchestrate.sh codex-complete
```

---

## Model Selection Per Phase (Auto-Selection)

The orchestration system automatically updates the model hint when phases change. Claude should read this hint and use the recommended model for spawning subagents.

### Model Recommendations by Phase

| Phase | Default Model | When to Use Different |
|-------|---------------|----------------------|
| research | sonnet | haiku for quick scans |
| architect | **opus** | Always opus (critical decisions) |
| planner | sonnet | - |
| execution | sonnet | haiku for simple, opus for complex |
| reviewer | sonnet | haiku for quick reviews |
| integrator | sonnet | - |

### How Auto-Selection Works

1. **On phase transition**, orchestrate.sh calls `update_model_hint()`
2. **Model hint is stored** in:
   - `.agents/state.json` under `model_hint` section
   - `.agents/model-hint.txt` (simple text file for easy reading)
3. **Claude reads the hint** and uses it when spawning Task subagents

### Reading the Model Hint

```bash
# Check current recommended model
./orchestrate.sh status

# Or read directly
cat .agents/model-hint.txt
# Returns: opus, sonnet, or haiku

# Or from state.json
jq '.model_hint.recommended_model' .agents/state.json
```

### Using the Model Hint in Claude Code

When spawning subagents with the Task tool, Claude should:

1. Read the model hint from state
2. Use it for subagent model parameter

```
Task tool:
  model: "haiku"   # Fast, cheap - scanning, formatting
  model: "sonnet"  # Balanced - implementation, testing (default)
  model: "opus"    # Complex reasoning - architecture, debugging
```

### Manual Model Check

```bash
# Get recommendation for specific phase/complexity
./orchestrate.sh model <phase> [complexity]

# Examples
./orchestrate.sh model architect          # Returns: opus
./orchestrate.sh model execution simple   # Returns: haiku
./orchestrate.sh model execution complex  # Returns: opus
```

---

## Claude-Initiated Codex Dispatch

Claude Code can dispatch Codex tasks in the background and continue working.

### Dispatch Pattern (for Claude Code)

```bash
# 1. Dispatch Codex in background
./.agents/dispatch-codex.sh --background

# 2. Continue your [CLAUDE] tasks while Codex runs

# 3. Check Codex status periodically
./.agents/dispatch-codex.sh --status
# or
./orchestrate.sh codex-status

# 4. When Codex completes, commit and mark complete
./orchestrate.sh codex-commit "refactor: codex changes"
./orchestrate.sh codex-complete
```

### Monitoring Codex Progress

```bash
# Quick status check
./orchestrate.sh codex-status

# Watch log in real-time
tail -f .agents/codex-dispatch.log

# Check if processes are running
pgrep -f "codex exec"
```

### Workflow Example

```
Claude reads plan
  |
  +-- [CLAUDE] tasks --> Work on sequential tasks
  |
  +-- At HARD STOP:
        |
        +-- Run: ./.agents/dispatch-codex.sh --background
        |
        +-- Continue with more [CLAUDE] tasks
        |
        +-- Check: ./orchestrate.sh codex-status
        |
        +-- When both done: ./orchestrate.sh claude-complete
```

### Parallel Limits

- Codex CLI 0.91.0+: Max 6 sub-agents running in parallel
- Task files beyond 6 will queue automatically

## If You Are Claude-code

Read this file first, then check `docs/plans/active/output.md` for current work.
Confirm ownership before touching any shared file or directory.

## Persistent State (docs/handoff/STATE.md)

On every session start:
1) Open `docs/handoff/STATE.md` first to understand current project state
2) Review context, status, and open tasks before starting work

Trigger phrase: "save our current state"
- When you see this phrase, overwrite `docs/handoff/STATE.md` with an updated summary
- Include: current branch, recent commits, what works/broken, open tasks, next steps

Rules:
- NEVER store secrets, API keys, or credentials in STATE.md
- Keep it concise (ASCII-only, no emojis)
- Update the timestamp when saving state

---

## Fully Autonomous Mode

Enable autonomous mode for overnight unattended work. Claude will auto-approve all checkpoints except research (which always requires human approval as a safety gate).

### Safety Gate

Autonomous mode can ONLY be enabled after research is approved:
- This ensures a human has validated the feature makes sense before Claude works autonomously
- Prevents runaway development on invalid or misunderstood features

### Enabling Autonomous Mode

```bash
# 1. Start a feature and complete research
./orchestrate.sh start "my-feature"
# ... Claude runs research phase ...

# 2. Human reviews and approves research (REQUIRED)
./orchestrate.sh approve research

# 3. NOW you can enable autonomous mode
./orchestrate.sh autonomous enable

# 4. Claude works overnight, auto-approving checkpoints
# ... architect, planner, execution, reviewer, integrator ...

# 5. In the morning, check status and disable
./orchestrate.sh status
./orchestrate.sh autonomous disable
```

### What Gets Auto-Approved

| Checkpoint | Manual Mode | Autonomous Mode |
|------------|-------------|-----------------|
| Research | Human approval required | Human approval required (ALWAYS) |
| Plan | Human approval required | Auto-approved |
| Review | Human approval required | Auto-approved |
| Integration | Human approval required | Auto-approved |

### Commands

```bash
./orchestrate.sh autonomous enable   # Enable (requires research approved)
./orchestrate.sh autonomous disable  # Return to manual mode
./orchestrate.sh autonomous status   # Check current state
```

### Overnight Work Pattern

```
User before going to sleep:
1. ./orchestrate.sh start "my-feature"
2. Claude runs RESEARCH phase
3. ./orchestrate.sh approve research  # Human approves
4. ./orchestrate.sh autonomous enable
5. User goes to sleep

Claude works overnight:
6. ARCHITECT phase - runs automatically
7. PLANNER phase - runs automatically
8. ./orchestrate.sh approve plan      # Auto-approved
9. EXECUTION phase (Claude + Codex)
10. ./orchestrate.sh approve review   # Auto-approved
11. REVIEWER phase
12. INTEGRATOR phase

User wakes up:
13. ./orchestrate.sh status           # See completed feature
14. ./orchestrate.sh autonomous disable
```

---

## Claude-Codex Auto Orchestration

Claude can launch Codex in the background, continue working, and automatically finalize when Codex completes.

### Quick Start

```bash
# Launch Codex in background and continue working
./orchestrate.sh claude-codex-auto

# Or wait for Codex to complete (blocking)
./orchestrate.sh claude-codex-auto --wait

# Check if Codex is done and finalize
./orchestrate.sh claude-codex-auto --check
```

### How It Works

1. **Launch**: Codex starts in background, Claude continues working
2. **Monitor**: Periodic `--check` to see if Codex finished
3. **Retry**: If tasks fail, automatic retry (max 2 attempts)
4. **Finalize**: Auto-commit Codex changes and mark complete

### Retry Mechanism

When Codex tasks fail:
1. Failed tasks are identified from the log
2. Retry task files are created with error context
3. Codex is re-dispatched with the retry tasks
4. Max 2 retry attempts before escalating to human

### Workflow Example

```
Claude during EXECUTION phase:

1. ./orchestrate.sh claude-codex-auto     # Launch Codex in background
   |
   +-- [Claude continues with its own tasks]
   |
2. ./orchestrate.sh claude-codex-auto --check   # Check periodically
   |
   +-- If running: "Codex still running"
   +-- If failed: Auto-retry (up to 2 times)
   +-- If complete: Auto-commit and mark done
   |
3. [Claude receives "Codex complete" confirmation]
4. [Claude proceeds with integration]
```

### Commands

| Command | Description |
|---------|-------------|
| `claude-codex-auto` | Launch Codex in background, return immediately |
| `claude-codex-auto --wait` | Launch and block until complete |
| `claude-codex-auto --check` | Check status, retry/finalize if needed |
| `claude-codex-auto --status` | Alias for `codex-status` |

### Files Created

| File | Purpose |
|------|---------|
| `.agents/codex-dispatch.log` | Full Codex execution log |
| `.agents/codex-dispatch.pid` | PID of running Codex process |
| `.agents/codex-failures.json` | Structured failure tracking |
| `.agents/codex-tasks/*-retry.md` | Retry tasks with error context |

---

## Bug-Fix Workflow

A lightweight workflow for fixing bugs with GitHub issue/PR integration.

### Quick Start

```bash
# Start a bug-fix (creates GitHub issue automatically)
./orchestrate.sh bug "Button not responding on mobile" major

# Severity options: critical, major (default), minor
```

### Phases

```
┌──────────┐      ┌──────────┐      ┌──────────┐      ┌──────────┐
│  TRIAGE  │─────▶│   PLAN   │─────▶│   FIX    │─────▶│  VERIFY  │
│          │      │          │      │          │      │          │
└──────────┘      └──────────┘      └──────────┘      └──────────┘
     │                 │                 │                 │
     ▼                 ▼                 ▼                 ▼
  gh issue         Codex task       Claude +          git push
  created          files            Codex             gh pr create
```

| Phase | Purpose | Output | Checkpoint |
|-------|---------|--------|------------|
| **TRIAGE** | Reproduce, identify root cause | `.agents/outputs/triage.md` | `./orchestrate.sh approve triage` |
| **PLAN** | Create fix plan, assign tasks | `docs/plans/active/fix-<#>.md` | `./orchestrate.sh approve plan` |
| **FIX** | Implement fix (Claude + Codex) | Code changes | Auto-proceed when both complete |
| **VERIFY** | Test, push, create PR | PR created | `./orchestrate.sh bug-complete` |

### Severity-Based Model Selection

| Severity | Triage | Plan | Fix | Verify |
|----------|--------|------|-----|--------|
| critical | sonnet | opus | opus | sonnet |
| major | sonnet | sonnet | sonnet | haiku |
| minor | haiku | sonnet | haiku | haiku |

### GitHub Integration

**Issue Creation:**
```bash
./orchestrate.sh bug "Bug title" major
# Creates: GitHub issue #42 with labels "bug,severity:major"
# Creates: Branch fix/42-bug-title
```

**PR Creation (in VERIFY phase):**
```bash
gh pr create --title "Fix: Bug title" --body "Fixes #42"
# Auto-closes issue when PR is merged
```

### Commands Reference

```bash
# Start bug-fix
./orchestrate.sh bug "<title>" [severity]

# Check status
./orchestrate.sh bug-status
./orchestrate.sh status          # Auto-detects workflow type

# Resume workflow
./orchestrate.sh bug-resume
./orchestrate.sh resume          # Auto-detects workflow type

# Approve checkpoints
./orchestrate.sh approve triage  # After root cause identified
./orchestrate.sh approve plan    # After fix plan created

# Execution
./orchestrate.sh codex-dispatch  # Dispatch Codex tasks
./orchestrate.sh claude-complete # Mark Claude work done
./orchestrate.sh codex-complete  # Mark Codex work done

# Complete workflow
./orchestrate.sh bug-complete    # After PR created
```

### Codex Tasks for Bug Fixes

Codex handles parallelizable work:

| Task Type | File Pattern | Purpose |
|-----------|--------------|---------|
| Regression test | `bugfix-<#>-regression-test.md` | Write test that catches the bug |
| Similar fix | `bugfix-<#>-similar-fix.md` | Apply same fix elsewhere |
| Doc update | `bugfix-<#>-doc-update.md` | Update affected docs |
| Cleanup | `bugfix-<#>-cleanup.md` | Lint, format affected files |

### Example Session

```bash
# 1. Start bug-fix
./orchestrate.sh bug "Login fails on Safari" major
# → Creates issue #42
# → Creates branch fix/42-login-fails-on-safari

# 2. TRIAGE phase
# Claude reproduces, identifies root cause
./orchestrate.sh approve triage

# 3. PLAN phase
# Claude creates fix plan + Codex tasks
./orchestrate.sh approve plan

# 4. FIX phase
# Claude implements core fix
./orchestrate.sh codex-dispatch  # At HARD STOP
# Codex writes regression tests in parallel
./orchestrate.sh claude-complete
./orchestrate.sh codex-complete

# 5. VERIFY phase
# Claude runs tests, updates CHANGELOG, creates PR
./orchestrate.sh bug-complete

# Done! PR #43 linked to issue #42
```

### CHANGELOG Updates

Bug fixes should update `CHANGELOG.md`:

```markdown
## [Unreleased]

### Fixed
- Fix login failure on Safari browsers (#42)
```

---

## Ralph Plan Execution Workflow

When creating execution plans from Notion development phases:

### Plan Creation Checklist

Before creating a plan, ensure it follows this checklist:

- [ ] **Use template** - Copy from `docs/plans/templates/ralph-plan-template.md`
- [ ] **Checkbox format** - All tasks use `- [ ]` format (required for ralph-loop tracking)
- [ ] **Task workflow** - Each task includes: Implement -> Unit test -> Run -> Fix -> Mark complete
- [ ] **HARD STOPs** - Include commit points after each phase
- [ ] **Integration testing section** - Separate from unit tests
- [ ] **Documentation section** - Update docs after code complete
- [ ] **Deployment section** - Git commit, push, Notion update
- [ ] **Output file** - Copy `docs/plans/templates/output-template.md` alongside plan

### Template Files

| Template | Location | Purpose |
|----------|----------|---------|
| Plan Template | `docs/plans/templates/ralph-plan-template.md` | Standard plan structure |
| Output Template | `docs/plans/templates/output-template.md` | Execution log structure |

### Creating a Plan

1. **Read development phase from Notion** - Fetch the current/next phase from [Development Phases](https://www.notion.so/2e990999c65081ebb386ec334bcd346c)
2. **Copy plan template** - `cp docs/plans/templates/ralph-plan-template.md docs/plans/active/[name].md`
3. **Copy output template** - `cp docs/plans/templates/output-template.md docs/plans/active/[name]-output.md`
4. **Fill in placeholders** - Replace `[Plan Title]`, `[Phase Title]`, etc.
5. **Verify checkbox format** - All tasks must use `- [ ]` for tracking
6. **Include execution command** - Update Quick Start section with correct filename

### Plan File Structure

```
whatsapp-mcp/
├── docs/
│   └── plans/
│       ├── active/                    # Current plans being executed
│       │   ├── [plan-name].md         # The plan file
│       │   └── output.md              # Execution log
│       └── archive/                   # Completed plans
│           ├── 2026-01-14-feature-x-plan.md
│           └── 2026-01-14-feature-x-output.md
```

### Sample Prompts to Create Plans

```bash
# Simple
Ralph plan from Notion: algo_ranger_bot Phase 6

# With context
Create a ralph plan for the next development phase of algo_ranger_bot.
Read from Notion first, then generate plan to docs/plans/active/

# Specific phase
Read algo_ranger_bot Development Phases in Notion, find Phase 5: IDSA Testing,
and create a ralph execution plan with proper format.
```

### Executing a Plan

**Full plan execution:**
```bash
/ralph-loop:ralph-loop "Execute docs/plans/active/[plan-name].md. Rules: (1) ONE task at a time, (2) Mark [x] when done, (3) Commit after each, (4) Write to output.md at HARD STOPs, (5) Output <promise>PLAN_COMPLETE</promise> when ALL done." --completion-promise "PLAN_COMPLETE" --max-iterations 30
```

**Phase-by-phase (recommended for large plans):**
```bash
/ralph-loop:ralph-loop "Execute Phase 1 of docs/plans/active/[plan-name].md. ONE task, mark [x], commit. Output <promise>PHASE1_DONE</promise> when complete." --completion-promise "PHASE1_DONE" --max-iterations 15
```

### After Completion

1. Archive plan and output files with date prefix
2. Update Notion Development Phases (mark checkboxes)
3. Update Notion Changelog
