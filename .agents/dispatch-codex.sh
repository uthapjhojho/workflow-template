#!/bin/bash
#
# Auto-dispatch all Codex tasks in parallel
#
# Usage:
#   ./dispatch-codex.sh              # Run all tasks in parallel (foreground)
#   ./dispatch-codex.sh --background # Run in background with logging
#   ./dispatch-codex.sh --dry-run    # Print commands without executing
#   ./dispatch-codex.sh --status     # Check status of background run
#   ./dispatch-codex.sh --retry      # Run only retry tasks (created by orchestrate.sh)
#
# This script runs Codex tasks independently of the orchestration state,
# useful for quick parallel execution when you don't need full workflow tracking.
#
# For Claude Code:
#   Run with --background to dispatch Codex while continuing your work.
#   Use --status or read .agents/codex-dispatch.log to monitor progress.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CODEX_TASKS_DIR="$SCRIPT_DIR/codex-tasks"
LOG_FILE="$SCRIPT_DIR/codex-dispatch.log"
PID_FILE="$SCRIPT_DIR/codex-dispatch.pid"

# Colors (disabled for log file output)
if [ -t 1 ]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  NC='\033[0m'
else
  RED=''
  GREEN=''
  YELLOW=''
  BLUE=''
  NC=''
fi

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_time() { echo "[$(date '+%H:%M:%S')] $1"; }

# Parse arguments
DRY_RUN=false
BACKGROUND=false
STATUS_CHECK=false
RETRY_MODE=false

for arg in "$@"; do
  case "$arg" in
    --dry-run)
      DRY_RUN=true
      ;;
    --background)
      BACKGROUND=true
      ;;
    --status)
      STATUS_CHECK=true
      ;;
    --retry)
      RETRY_MODE=true
      ;;
  esac
done

# Status check mode
if [ "$STATUS_CHECK" = true ]; then
  echo "=== Codex Dispatch Status ==="
  echo ""

  # Check if running
  if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if ps -p "$PID" > /dev/null 2>&1; then
      echo "Status: RUNNING (PID: $PID)"
    else
      echo "Status: COMPLETED (process exited)"
      rm -f "$PID_FILE"
    fi
  else
    echo "Status: NOT RUNNING"
  fi

  echo ""

  # Show recent log
  if [ -f "$LOG_FILE" ]; then
    echo "Recent log (last 15 lines):"
    echo "---"
    tail -15 "$LOG_FILE"
    echo "---"
    echo ""
    echo "Full log: $LOG_FILE"
  else
    echo "No log file found."
  fi

  exit 0
fi

# Background mode: fork and run with logging
if [ "$BACKGROUND" = true ]; then
  log_info "Starting Codex dispatch in background..."
  log_info "Log file: $LOG_FILE"
  log_info "Check status: $0 --status"

  # Fork to background with nohup
  nohup "$0" > "$LOG_FILE" 2>&1 &
  echo $! > "$PID_FILE"

  log_success "Codex dispatch started in background (PID: $(cat "$PID_FILE"))"
  echo ""
  echo "Claude Code can continue working while Codex runs."
  echo "Monitor with: ./.agents/dispatch-codex.sh --status"
  echo "Or read log:  tail -f .agents/codex-dispatch.log"
  exit 0
fi

# Check for Codex CLI
if ! command -v codex &> /dev/null; then
  log_error "Codex CLI not found. Install with: npm install -g @openai/codex"
  exit 1
fi

# Find task files (exclude TEMPLATE.md)
if [ "$RETRY_MODE" = true ]; then
  # In retry mode, only run retry tasks
  TASK_FILES=$(find "$CODEX_TASKS_DIR" -maxdepth 1 -name "*-retry.md" 2>/dev/null | sort)
  log_time "RETRY MODE: Looking for retry tasks"
else
  TASK_FILES=$(find "$CODEX_TASKS_DIR" -maxdepth 1 -name "task-*.md" ! -name "*-retry.md" 2>/dev/null | sort)
fi
TASK_COUNT=$(echo "$TASK_FILES" | grep -c . || true)

if [ "$TASK_COUNT" -eq 0 ]; then
  if [ "$RETRY_MODE" = true ]; then
    log_warn "No retry tasks found in $CODEX_TASKS_DIR"
    echo "Retry tasks should be named: task-X.X-<name>-retry.md"
  else
    log_warn "No Codex tasks found in $CODEX_TASKS_DIR"
    echo "Task files should be named: task-X.X-<name>.md"
  fi
  exit 0
fi

log_time "Found $TASK_COUNT Codex task(s)"

cd "$PROJECT_ROOT"

if [ "$DRY_RUN" = true ]; then
  log_info "Dry run mode - printing commands:"
  echo ""
  for task_file in $TASK_FILES; do
    task_name=$(basename "$task_file" .md)
    echo "  # $task_name"
    echo "  codex exec --full-auto < $task_file &"
    echo ""
  done
  exit 0
fi

# Run all tasks in parallel (max 6 concurrent - Codex CLI limit)
log_time "Starting all tasks in parallel..."
pids=()
task_names=()

for task_file in $TASK_FILES; do
  task_name=$(basename "$task_file" .md)
  log_time "Starting: $task_name"
  task_names+=("$task_name")

  # Run Codex in background
  (codex exec --full-auto < "$task_file") &
  pids+=($!)
done

echo ""
log_time "Waiting for ${#pids[@]} task(s) to complete..."
echo ""

# Wait for all tasks and collect results
failed=0
failed_tasks=()
completed_tasks=()

for i in "${!pids[@]}"; do
  pid="${pids[$i]}"
  task="${task_names[$i]}"

  if wait "$pid"; then
    log_time "COMPLETED: $task"
    completed_tasks+=("$task")
  else
    log_time "FAILED: $task"
    failed_tasks+=("$task")
    ((failed++))
  fi
done

# Write failure tracking file (for orchestrate.sh to read)
FAILURES_FILE="$SCRIPT_DIR/codex-failures.json"
cat > "$FAILURES_FILE" << EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "total": ${#pids[@]},
  "completed": ${#completed_tasks[@]},
  "failed": $failed,
  "failed_tasks": $(printf '%s\n' "${failed_tasks[@]}" | jq -R . | jq -s .),
  "completed_tasks": $(printf '%s\n' "${completed_tasks[@]}" | jq -R . | jq -s .)
}
EOF

# Cleanup PID file
rm -f "$PID_FILE"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_time "CODEX DISPATCH COMPLETE"

if [ $failed -gt 0 ]; then
  log_warn "Completed with $failed failure(s) out of ${#pids[@]} task(s)"
  echo ""
  echo "Next steps:"
  echo "  1. Check failed task outputs for errors"
  echo "  2. Fix issues and re-run failed tasks manually"
  echo "  3. Run './orchestrate.sh codex-commit' when ready"
  exit 1
else
  log_success "All $TASK_COUNT Codex task(s) completed successfully!"
  echo ""
  echo "Next steps:"
  echo "  1. Review changes: git diff"
  echo "  2. Commit: ./orchestrate.sh codex-commit"
  echo "  3. Mark complete: ./orchestrate.sh codex-complete"
fi
