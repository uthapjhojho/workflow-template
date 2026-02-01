# Adoption Guide

How to add multi-agent orchestration to an existing project.

---

## Quick Adoption (5 minutes)

### 1. Copy the `.agents/` Directory

```bash
# From your project root
cp -r /path/to/workflow_template/.agents .

# Or clone the template and copy
git clone https://github.com/your-org/workflow-template /tmp/workflow-template
cp -r /tmp/workflow-template/.agents .
```

### 2. Copy Documentation

```bash
# Required docs
mkdir -p docs/plans/active docs/plans/archive docs/plans/templates

# Copy templates
cp -r /path/to/workflow_template/docs/plans/templates/* docs/plans/templates/

# Copy AGENTS_WORKFLOW.md
cp /path/to/workflow_template/docs/AGENTS_WORKFLOW.md docs/

# Optionally copy all documentation
cp /path/to/workflow_template/docs/*.md docs/
```

### 3. Initialize Configuration

```bash
./orchestrate.sh init
```

This creates `.agents/config.json` with your project settings.

Alternatively, create it manually:

```json
{
  "project_name": "your-project-name",
  "project_root": ".",
  "description": "Brief project description",
  "settings": {
    "notion_enabled": false,
    "github_enabled": true,
    "default_severity": "major",
    "default_complexity": "medium"
  }
}
```

### 4. Create CLAUDE.md

Create `CLAUDE.md` in your project root:

```markdown
# CLAUDE.md - Your Project Name

> **Last updated:** YYYY-MM-DD | **Current Phase:** Template Project

---

## CRITICAL RULES (Always Follow)

### Agent Workflow (Read First)
- Read `docs/AGENTS_WORKFLOW.md` at the start of every session
- If you are Claude-code, you are the executor
- All changes must be accompanied by a handoff note

### Testing (REQUIRED Before Completion)
<!-- Add your project-specific test commands -->
```bash
# Your test commands here
npm test
# or
pytest tests/ -v
# or
go test ./...
```

---

## Project Structure

<!-- Document your project structure -->

---

## Quick Reference

### Orchestration Commands

```bash
./orchestrate.sh start <feature-name>
./orchestrate.sh status
./orchestrate.sh resume
./orchestrate.sh approve research
./orchestrate.sh approve plan
./orchestrate.sh approve review
```

---

## Project-Specific Notes

<!-- Add your project-specific context -->
```

### 5. Verify Installation

```bash
# Run pre-flight checks
./orchestrate.sh preflight

# Check status (should show "idle")
./orchestrate.sh status
```

### 6. Add to .gitignore

```bash
# Add to .gitignore
echo ".agents/state.json" >> .gitignore
echo ".agents/state.json.lockdir" >> .gitignore
echo ".agents/codex-dispatch.log" >> .gitignore
echo ".agents/codex-dispatch.pid" >> .gitignore
echo ".agents/codex-failures.json" >> .gitignore
echo ".agents/model-hint.txt" >> .gitignore
echo ".agents/logs/*.json" >> .gitignore
```

---

## Full Adoption (Recommended)

### Additional Files to Copy

```bash
# All documentation
cp docs/GETTING_STARTED.md your-project/docs/
cp docs/COMMANDS.md your-project/docs/
cp docs/STATE_SCHEMA.md your-project/docs/
cp docs/TROUBLESHOOTING.md your-project/docs/
cp docs/ARCHITECTURE.md your-project/docs/

# Example workflows
mkdir -p docs/examples
cp docs/examples/*.md your-project/docs/examples/
```

### Update AGENTS_WORKFLOW.md

Edit `docs/AGENTS_WORKFLOW.md` to reflect your project:

1. Update "Repo Location and Key Directories" section
2. Update "Example Split" section
3. Remove references to `whatsapp-mcp`
4. Add your project-specific conventions

---

## Language-Specific Setup

### Python Projects

Update testing in CLAUDE.md:

```bash
# Testing
pytest tests/ -v --tb=short

# Type checking
mypy src/

# Linting
ruff check .
```

### Node.js Projects

Update testing in CLAUDE.md:

```bash
# Testing
npm test

# Type checking
npx tsc --noEmit

# Linting
npm run lint
```

### Go Projects

Update testing in CLAUDE.md:

```bash
# Testing
go test ./...

# Linting
golangci-lint run

# Build
go build ./...
```

### Rust Projects

Update testing in CLAUDE.md:

```bash
# Testing
cargo test

# Linting
cargo clippy

# Build
cargo build
```

---

## Integration with CI/CD

### GitHub Actions Example

```yaml
# .github/workflows/orchestration-check.yml
name: Orchestration Check

on: [push, pull_request]

jobs:
  preflight:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Install jq
        run: sudo apt-get install -y jq

      - name: Run preflight checks
        run: ./orchestrate.sh preflight
```

---

## Migration from Other Systems

### From Manual Git Workflow

1. Your existing branches continue to work
2. Start using orchestration for new features
3. Old PRs can complete normally

### From Other Task Systems

1. Copy the `.agents/` directory
2. Map your existing phases to orchestration phases
3. Migrate task tracking gradually

---

## Configuration Reference

### `.agents/config.json`

```json
{
  "project_name": "string",
  "project_root": "string",
  "description": "string",
  "settings": {
    "notion_enabled": "boolean",
    "github_enabled": "boolean",
    "default_severity": "critical | major | minor",
    "default_complexity": "simple | medium | complex"
  },
  "models": {
    "architect": "opus | sonnet | haiku",
    "planner": "opus | sonnet | haiku",
    "execution_simple": "opus | sonnet | haiku",
    "execution_medium": "opus | sonnet | haiku",
    "execution_complex": "opus | sonnet | haiku",
    "reviewer": "opus | sonnet | haiku",
    "integrator": "opus | sonnet | haiku"
  },
  "paths": {
    "plans_active": "string",
    "plans_archive": "string",
    "codex_tasks": "string",
    "outputs": "string"
  }
}
```

---

## Troubleshooting Adoption

### "Command not found: jq"

```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt install jq

# Fedora
sudo dnf install jq
```

### "Not in a git repository"

```bash
git init
```

### "State file not found"

Run any command to create it:

```bash
./orchestrate.sh status
```

### Prompts still reference old project

The prompts now read from `.agents/config.json` and `.agents/state.json`. Update your config file with the correct project name.

---

## Minimal Adoption

If you only want basic workflow tracking without the full system:

1. Copy only `.agents/orchestrate.sh`
2. Copy `.agents/state.json.template`
3. Use `./orchestrate.sh start/status/reset` commands

This gives you state tracking without prompts or Codex integration.

---

## Removing Orchestration

To remove orchestration from a project:

```bash
rm -rf .agents/
rm -f CLAUDE.md
rm -rf docs/plans/
rm -f docs/AGENTS_WORKFLOW.md
```

No other files are affected.
