# Multi-Agent Workflow Template

A reusable template for Claude + Codex multi-agent orchestration workflows.

## Features

- **Two-agent coordination**: Claude (sequential) + Codex (parallel) execution
- **Phase-based workflow**: Research -> Architect -> Planner -> Execution -> Reviewer -> Integrator
- **Autonomous mode**: Enable overnight unattended work with auto-approval
- **Model auto-selection**: Automatically recommends optimal model per phase
- **Retry mechanism**: Failed Codex tasks are automatically retried (max 2 attempts)

## Quick Start

1. **Copy to your project:**
   ```bash
   cp -r workflow_template/.agents your-project/
   cp -r workflow_template/docs your-project/
   ```

2. **Initialize a feature:**
   ```bash
   ./orchestrate.sh start "my-feature"
   ```

3. **Follow the workflow:**
   ```bash
   ./orchestrate.sh resume    # See next steps
   ./orchestrate.sh status    # Check progress
   ```

## Directory Structure

```
.agents/
├── orchestrate.sh          # Main orchestration script
├── dispatch-codex.sh       # Codex task dispatcher
├── state.json              # Workflow state tracking
├── README.md               # Agent-specific docs
├── codex-tasks/            # Codex task files
│   └── TEMPLATE.md         # Task file template
├── outputs/                # Agent outputs (research.md, architecture.md, etc.)
└── prompts/                # Phase-specific prompts
    ├── researcher.md
    ├── architect.md
    ├── planner.md
    ├── reviewer.md
    └── integrator.md

docs/
├── AGENTS_WORKFLOW.md      # Full workflow documentation
└── plans/
    ├── active/             # Current plans being executed
    ├── archive/            # Completed plans
    └── templates/          # Plan templates
```

## Commands

### Basic Workflow
```bash
./orchestrate.sh start <feature>    # Start new feature
./orchestrate.sh status             # Show current state
./orchestrate.sh resume             # Resume from checkpoint
./orchestrate.sh approve <type>     # Approve checkpoint (research|plan|review)
```

### Autonomous Mode
```bash
./orchestrate.sh autonomous enable   # Enable auto-approval (requires research approved)
./orchestrate.sh autonomous disable  # Return to manual mode
./orchestrate.sh autonomous status   # Check state
```

### Claude-Codex Auto
```bash
./orchestrate.sh claude-codex-auto           # Launch Codex in background
./orchestrate.sh claude-codex-auto --wait    # Wait for completion
./orchestrate.sh claude-codex-auto --check   # Check & finalize
```

### Codex Control
```bash
./orchestrate.sh codex-dispatch      # Dispatch tasks
./orchestrate.sh codex-status        # Check status
./orchestrate.sh codex-commit [msg]  # Commit changes
./orchestrate.sh codex-complete      # Mark complete
```

## Model Selection

| Phase | Model | Reason |
|-------|-------|--------|
| research | sonnet | Balanced research |
| architect | **opus** | Critical decisions |
| planner | sonnet | Task breakdown |
| execution | sonnet | Implementation |
| reviewer | sonnet | Code review |
| integrator | sonnet | Final integration |

Check model hint: `./orchestrate.sh status` or `cat .agents/model-hint.txt`

## Customization

1. **Edit prompts**: Modify `.agents/prompts/*.md` for your project context
2. **Update CLAUDE.md**: Add project-specific instructions
3. **Adjust models**: Edit `get_model_for_phase()` in orchestrate.sh

## Documentation

- See `docs/AGENTS_WORKFLOW.md` for full workflow documentation
- See `.agents/README.md` for agent-specific documentation
