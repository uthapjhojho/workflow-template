#!/bin/bash
#
# AI Task Delegation - Universal Tool
# Delegates coding tasks to AI providers (GLM, DeepSeek, etc.) based on complexity routing
#
# Usage:
#   ai "fix validation bug in auth.js"
#   ai --complexity complex "refactor UserService to use repository pattern"
#   ai --type documentation "update API docs"
#   ai --wait "generate tests for UserService"  # Wait for result
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TASKS_DIR="$SCRIPT_DIR/codex-tasks"
OUTPUTS_DIR="$SCRIPT_DIR/outputs"
DISPATCH_SCRIPT="$SCRIPT_DIR/dispatch-ai.sh"

# Default values
TASK_TYPE="code_execution"
COMPLEXITY="medium"
WAIT_MODE=false
TASK_DESC=""
AUTO_COMPLEXITY=true

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --type)
      TASK_TYPE="$2"
      shift 2
      ;;
    --complexity)
      COMPLEXITY="$2"
      AUTO_COMPLEXITY=false
      shift 2
      ;;
    --wait)
      WAIT_MODE=true
      shift
      ;;
    --background)
      WAIT_MODE=false
      shift
      ;;
    *)
      TASK_DESC="$1"
      shift
      ;;
  esac
done

if [ -z "$TASK_DESC" ]; then
  echo "Usage: ai [options] \"<task description>\""
  echo ""
  echo "Options:"
  echo "  --type <type>              Task type (default: code_execution)"
  echo "  --complexity <level>       simple|medium|complex (auto-detected if not set)"
  echo "  --wait                     Wait for result (default: background)"
  echo ""
  echo "Examples:"
  echo "  ai \"fix typo in README\""
  echo "  ai --complexity complex \"refactor UserService\""
  echo "  ai --type documentation --wait \"update API docs\""
  exit 1
fi

# Auto-detect complexity if not manually set
if [ "$AUTO_COMPLEXITY" = true ]; then
  # Simple task indicators
  if [[ "$TASK_DESC" =~ (typo|fix|update|simple|trivial|small|quick|format|lint) ]]; then
    COMPLEXITY="simple"
  # Complex task indicators
  elif [[ "$TASK_DESC" =~ (complex|refactor|architect|design|restructure|migrate) ]]; then
    COMPLEXITY="complex"
  fi
fi

# Auto-detect task type from keywords
if [[ "$TASK_DESC" =~ (test|spec|unittest) ]]; then
  TASK_TYPE="test_generation"
elif [[ "$TASK_DESC" =~ (document|docs|readme|comment) ]]; then
  TASK_TYPE="documentation"
elif [[ "$TASK_DESC" =~ (review|check|audit) ]]; then
  TASK_TYPE="code_review"
elif [[ "$TASK_DESC" =~ (commit message|changelog) ]]; then
  TASK_TYPE="commit_message"
fi

# Create task file
mkdir -p "$TASKS_DIR"
TASK_ID=$(date +%s)
TASK_FILE="$TASKS_DIR/task-quick-${TASK_ID}.md"

cat > "$TASK_FILE" <<EOF
---
task_type: $TASK_TYPE
complexity: $COMPLEXITY
source: ai-delegate
created_at: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
---

# Quick Task (Auto-Generated)

$TASK_DESC

## Instructions
- Provide complete, working code
- Use markdown code blocks with filenames in comments
- Example: \`\`\`python
  # filename: src/utils.py
  def hello():
      print("world")
  \`\`\`
- Be precise and complete
- Follow project conventions
EOF

echo -e "${GREEN}✓${NC} Task created: task-quick-${TASK_ID}"
echo -e "${BLUE}  Type:${NC} $TASK_TYPE"
echo -e "${BLUE}  Complexity:${NC} $COMPLEXITY"
echo ""

# Determine which provider will handle this
if command -v jq &> /dev/null && [ -f "$SCRIPT_DIR/config.json" ]; then
  PROVIDER=$(jq -r ".ai_task_routing.${TASK_TYPE}.${COMPLEXITY} // .ai_provider.active" "$SCRIPT_DIR/config.json")
  PROVIDER_NAME=$(jq -r ".ai_provider.providers.${PROVIDER}.name // \"Unknown\"" "$SCRIPT_DIR/config.json")
  echo -e "${BLUE}  Provider:${NC} $PROVIDER_NAME ($PROVIDER)"
  echo ""
fi

# Dispatch
if [ "$WAIT_MODE" = true ]; then
  echo -e "${YELLOW}⏳${NC} Dispatching and waiting for result..."
  echo ""

  # Run dispatch in foreground (only this task)
  cd "$PROJECT_ROOT"
  "$DISPATCH_SCRIPT" --foreground

  # Show result
  OUTPUT_FILE="$OUTPUTS_DIR/task-quick-${TASK_ID}-response.md"
  if [ -f "$OUTPUT_FILE" ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${GREEN}✓ RESULT${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    cat "$OUTPUT_FILE"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  else
    echo -e "${YELLOW}⚠${NC} No output file found. Check logs: $SCRIPT_DIR/ai-dispatch.log"
  fi
else
  echo -e "${YELLOW}⏳${NC} Dispatching in background..."

  # Run dispatch in background
  cd "$PROJECT_ROOT"
  "$DISPATCH_SCRIPT" --background

  echo ""
  echo "Commands:"
  echo "  Check status:  ./orchestrate.sh codex-status"
  echo "  Attach:        ./orchestrate.sh ai-attach"
  echo "  View log:      tail -f .agents/ai-dispatch.log"
fi
