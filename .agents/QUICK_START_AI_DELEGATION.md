# Quick Start: AI Delegation

Save 70%+ on Claude tokens by delegating routine tasks to cheaper AI providers.

---

## 5-Second Start

```bash
./.agents/ai-delegate.sh "your task description here"
```

That's it! The system auto-detects task type, complexity, and routes to the best provider.

---

## Common Examples

### Fix Bugs (Simple)
```bash
./.agents/ai-delegate.sh "fix validation bug in auth.js line 45"
# → Routes to Haiku (cheap, fast)
```

### Generate Tests
```bash
./.agents/ai-delegate.sh "generate unit tests for UserService class"
# → Routes to DeepSeek (specialized for code)
```

### Update Docs
```bash
./.agents/ai-delegate.sh "update README with installation instructions"
# → Routes to GLM (cheap for docs)
```

### Complex Refactoring
```bash
./.agents/ai-delegate.sh "refactor database layer to use repository pattern"
# → Routes to Sonnet (high quality for complex work)
```

---

## Wait for Result

Add `--wait` to get the result immediately instead of background mode:

```bash
./.agents/ai-delegate.sh --wait "add JSDoc comments to utils.js"
# Waits ~30 seconds, shows result
```

---

## Manual Overrides

### Force Complexity Level
```bash
# Override auto-detection
./.agents/ai-delegate.sh --complexity simple "task description"
./.agents/ai-delegate.sh --complexity complex "task description"
```

### Force Task Type
```bash
# Override task type routing
./.agents/ai-delegate.sh --type documentation "create API reference"
./.agents/ai-delegate.sh --type test_generation "add edge case tests"
```

---

## Check Status

```bash
# Check if tasks are running
./orchestrate.sh codex-status

# Attach to AI session
./orchestrate.sh ai-attach

# View logs
tail -f .agents/ai-dispatch.log
```

---

## Shell Alias (Optional)

For even faster usage, source the alias:

```bash
# Add to your shell session
source .agents/ai-alias.sh

# Now use 'ai' anywhere
ai "fix typo in README"
ai --wait "generate tests"
```

**Make it permanent:**
```bash
# Add to ~/.bashrc or ~/.zshrc
echo 'source ~/path/to/project/.agents/ai-alias.sh' >> ~/.bashrc
```

---

## Task Type Auto-Detection

Keywords that trigger specific routing:

| Keywords | Task Type | Routes To |
|----------|-----------|-----------|
| test, spec, unittest | test_generation | DeepSeek |
| document, docs, readme, comment | documentation | GLM |
| review, check, audit | code_review | GLM (simple) / DeepSeek (medium) |
| commit message, changelog | commit_message | GLM |
| typo, fix, update, simple | (any type) + simple | Haiku/GLM |
| refactor, architect, complex | (any type) + complex | Sonnet/Opus |

---

## For Claude Code Users

Claude automatically uses this system! Just ask normally:

```
You: "Fix the typo in README and add tests for UserService"

Claude: "I'll delegate these tasks:
  1. Fix typo → GLM (simple)
  2. Generate tests → DeepSeek (medium)"

[Claude calls ./.agents/ai-delegate.sh automatically]
[Waits for results, reviews, applies]
```

You save tokens without doing anything!

---

## Cost Comparison

### Old Way (All Claude Sonnet)
```
10 tasks × $0.015 = $0.15
```

### New Way (Auto-Delegated)
```
7 tasks → GLM/DeepSeek/Haiku × $0.0007 = $0.005
2 tasks → Sonnet × $0.015 = $0.030
1 task → Opus × $0.015 = $0.015
Total: $0.05 (67% savings)
```

---

## Troubleshooting

### Task not running?
```bash
# Check tmux sessions
tmux list-sessions | grep ai-dispatch

# View logs
tail -30 .agents/ai-dispatch.log
```

### Wrong provider selected?
```bash
# Override manually
./.agents/ai-delegate.sh --complexity simple "task"
```

### API rate limits?
The dispatch system runs tasks in parallel. If you hit rate limits:
- Tasks will fail and be logged
- Check `.agents/ai-failures.json`
- Re-run with: `./.agents/dispatch-ai.sh --retry`

---

## What Gets Auto-Delegated?

**✅ Auto-delegate (saves tokens):**
- Typos, formatting, linting
- Boilerplate code
- Test generation
- Documentation updates
- Simple refactoring
- Commit messages

**❌ Claude does directly:**
- Debugging (needs reasoning)
- Architecture decisions
- Complex refactoring (needs context)
- User questions
- Multi-step planning

---

## Learn More

- Full summary: `.agents/AI_DELEGATION_SUMMARY.md`
- Routing config: `.agents/config.json` (ai_task_routing section)
- Dispatch system: `.agents/dispatch-ai.sh`
- Claude behavior: `CLAUDE.md` (Auto-Delegation section)
