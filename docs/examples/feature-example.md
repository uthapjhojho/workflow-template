# Feature Workflow Example

A complete walkthrough of adding a "user preferences" feature.

---

## Phase 1: Start Feature

```bash
$ ./orchestrate.sh start user-preferences

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  STARTING NEW FEATURE: user-preferences
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[SUCCESS] Feature initialized!

Next steps:
  1. Run Claude Code in this project
  2. Claude will read .agents/prompts/researcher.md
  3. Research output goes to .agents/outputs/research.md
  4. Then run './orchestrate.sh resume' to continue

[DECISION] You will decide GO/NO-GO after research phase
```

---

## Phase 2: Research

Claude reads the researcher prompt and produces research output:

### Sample `.agents/outputs/research.md`

```markdown
# Research: User Preferences Feature

## Executive Summary
Adding user preferences will improve user experience by allowing customization
of notification settings, theme, and default behaviors. Recommended to proceed.

## Target Users
- Power users who want customization
- Enterprise users with compliance requirements

## Existing Patterns
- Settings pattern already exists in `src/settings/`
- Database schema supports JSON columns for flexibility

## Technical Approach
1. Add `user_preferences` table with JSON column
2. Create preferences API endpoints
3. Add UI settings page

## Build Recommendation: GO
Low complexity, high user value, clear implementation path.
```

### Approve Research

```bash
$ ./orchestrate.sh approve research

[SUCCESS] Research approved! Moving to ARCHITECT phase.
```

---

## Phase 3: Architecture

Claude reads architect prompt and designs the system:

### Sample `.agents/outputs/architecture.md`

```markdown
# Architecture: User Preferences

## Overview
Store user preferences in a dedicated table with JSON schema validation.

## Components

### Database
- Table: `user_preferences`
- Columns: `user_id (FK)`, `preferences (JSONB)`, `updated_at`

### API
- `GET /api/preferences` - Get current user preferences
- `PATCH /api/preferences` - Update preferences (partial)

### Frontend
- Settings page at `/settings/preferences`
- React context for preference access

## Interfaces
```typescript
interface UserPreferences {
  theme: 'light' | 'dark' | 'system';
  notifications: {
    email: boolean;
    push: boolean;
  };
  defaultView: 'list' | 'grid';
}
```
```

### Move to Planning

```bash
$ ./orchestrate.sh next

[SUCCESS] Moving to PLANNER phase
```

---

## Phase 4: Planning

Claude creates execution plan and Codex tasks:

### Sample Plan (`docs/plans/active/user-preferences.md`)

```markdown
# Plan: User Preferences

## Tasks

### [CLAUDE] Database Migration
Create Alembic migration for user_preferences table.
Files: `migrations/versions/xxx_add_preferences.py`

### [CODEX] Preferences API Endpoints
Create FastAPI router with CRUD operations.
Files: `src/api/preferences.py`, `src/schemas/preferences.py`

### [CODEX] Preferences Model
Create SQLAlchemy model with JSON validation.
Files: `src/models/preferences.py`

### [CLAUDE] Settings UI
Create React settings page with preference controls.
Files: `frontend/src/pages/Settings.tsx`
```

### Codex Task Files Created

```
.agents/codex-tasks/
├── task-1.1-preferences-api.md
└── task-1.2-preferences-model.md
```

### Approve Plan

```bash
$ ./orchestrate.sh approve plan

[SUCCESS] Plan approved! EXECUTION phase started.
```

---

## Phase 5: Execution

### Start Claude Work

Claude begins working on `[CLAUDE]` tasks sequentially.

### Dispatch Codex (Parallel)

```bash
$ ./orchestrate.sh codex-dispatch

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  DISPATCHING CODEX TASKS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[INFO] Found 2 Codex task(s)
[INFO] Starting task: task-1.1-preferences-api.md
[INFO] Starting task: task-1.2-preferences-model.md
```

### Check Status

```bash
$ ./orchestrate.sh status

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  WORKFLOW STATUS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Feature: user-preferences
Phase:   execution
Branch:  feature/user-preferences

Execution Status:
  Claude: in_progress (current task: Database Migration)
  Codex:  running (2/2 tasks)
```

### Mark Complete

```bash
$ ./orchestrate.sh claude-complete
[SUCCESS] Claude execution complete!

$ ./orchestrate.sh codex-complete
[SUCCESS] Codex execution complete!
[INFO] Both Claude and Codex complete. Moving to REVIEWER phase.
```

---

## Phase 6: Review

Claude reviews all changes:

### Sample `.agents/outputs/review.md`

```markdown
# Review: User Preferences

## Summary
All tasks completed successfully. Code quality is good.

## Findings

### Passed
- Database migration is reversible
- API endpoints follow existing patterns
- Frontend matches design system

### Minor Issues
- Missing input validation on theme enum
- Consider adding rate limiting to preferences endpoint

## Verdict: APPROVE with minor fixes
```

### Approve Review

```bash
$ ./orchestrate.sh approve review

[SUCCESS] Review approved! Moving to INTEGRATOR phase.
```

---

## Phase 7: Integration

Claude merges branches and updates documentation:

```bash
$ ./orchestrate.sh complete

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  COMPLETING INTEGRATION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[INFO] Merging codex/user-preferences into feature/user-preferences
[SUCCESS] Branches merged!
[INFO] Workflow summary added to memory

[SUCCESS] Feature 'user-preferences' completed!

Don't forget:
  1. Update Notion Development Phases
  2. Add Changelog entry
  3. PR to main when ready
```

---

## Final State

```bash
$ ./orchestrate.sh analytics

Workflows Completed:  1
Workflows Aborted:    0

Success Rate:         100%

Avg Duration:         2h 15m

Last Updated:         2026-02-01T14:30:00Z
```

---

## Commands Used

| Phase | Command |
|-------|---------|
| Start | `./orchestrate.sh start user-preferences` |
| Research GO | `./orchestrate.sh approve research` |
| Architect → Planner | `./orchestrate.sh next` |
| Plan GO | `./orchestrate.sh approve plan` |
| Dispatch Codex | `./orchestrate.sh codex-dispatch` |
| Check Progress | `./orchestrate.sh status` |
| Claude Done | `./orchestrate.sh claude-complete` |
| Codex Done | `./orchestrate.sh codex-complete` |
| Review GO | `./orchestrate.sh approve review` |
| Finish | `./orchestrate.sh complete` |
| Reset | `./orchestrate.sh reset` |
