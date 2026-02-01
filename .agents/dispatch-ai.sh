#!/bin/bash
#
# Multi-Provider AI Task Dispatch
#
# Usage:
#   ./dispatch-ai.sh              # Run all tasks in parallel (foreground)
#   ./dispatch-ai.sh --background # Run in background with logging
#   ./dispatch-ai.sh --dry-run    # Print commands without executing
#   ./dispatch-ai.sh --status     # Check status of background run
#   ./dispatch-ai.sh --retry      # Run only retry tasks
#   ./dispatch-ai.sh --provider glm|codex|deepseek|moonshot  # Override provider
#
# Supports: GLM (Z.AI), Codex (OpenAI), DeepSeek, Moonshot
# Configure in config.json under "ai_provider"
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$SCRIPT_DIR/config.json"
TASKS_DIR="$SCRIPT_DIR/codex-tasks"
LOG_FILE="$SCRIPT_DIR/ai-dispatch.log"
PID_FILE="$SCRIPT_DIR/ai-dispatch.pid"
FAILURES_FILE="$SCRIPT_DIR/ai-failures.json"
OUTPUTS_DIR="$SCRIPT_DIR/outputs"

# Colors (disabled for log file output)
if [ -t 1 ]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  CYAN='\033[0;36m'
  NC='\033[0m'
else
  RED=''
  GREEN=''
  YELLOW=''
  BLUE=''
  CYAN=''
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
PROVIDER_OVERRIDE=""
FOREGROUND=false
FORCE_TMUX=false

while [[ $# -gt 0 ]]; do
  case "$1" in
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
    --foreground)
      FOREGROUND=true
      ;;
    --tmux)
      FORCE_TMUX=true
      ;;
    --provider)
      shift
      PROVIDER_OVERRIDE="$1"
      ;;
    --provider=*)
      PROVIDER_OVERRIDE="${1#*=}"
      ;;
  esac
  shift
done

# Read configuration
get_config() {
  jq -r "$1" "$CONFIG_FILE" 2>/dev/null
}

get_provider_config() {
  local provider="$1"
  local key="$2"
  jq -r ".ai_provider.providers.${provider}.${key} // empty" "$CONFIG_FILE" 2>/dev/null
}

# Determine active provider
if [ -n "$PROVIDER_OVERRIDE" ]; then
  ACTIVE_PROVIDER="$PROVIDER_OVERRIDE"
else
  ACTIVE_PROVIDER=$(get_config '.ai_provider.active')
fi

# Validate provider exists
PROVIDER_NAME=$(get_provider_config "$ACTIVE_PROVIDER" "name")
if [ -z "$PROVIDER_NAME" ] || [ "$PROVIDER_NAME" == "null" ]; then
  log_error "Unknown provider: $ACTIVE_PROVIDER"
  log_info "Available providers: $(jq -r '.ai_provider.providers | keys | join(", ")' "$CONFIG_FILE")"
  exit 1
fi

# Get provider settings
PROVIDER_TYPE=$(get_provider_config "$ACTIVE_PROVIDER" "type")
API_BASE=$(get_provider_config "$ACTIVE_PROVIDER" "api_base")
MODEL=$(get_provider_config "$ACTIVE_PROVIDER" "model")
ENV_KEY=$(get_provider_config "$ACTIVE_PROVIDER" "env_key")
CLI_COMMAND=$(get_provider_config "$ACTIVE_PROVIDER" "command")
MAX_TOKENS=$(get_config '.ai_provider.max_tokens')
TEMPERATURE=$(get_config '.ai_provider.temperature')

# Get API key - try Doppler first, then environment variable
API_KEY=""
if command -v doppler &> /dev/null; then
  # Try to get from Doppler (using algo_ranger_bot project)
  API_KEY=$(doppler secrets get "$ENV_KEY" --project algo_ranger_bot --config prd --plain 2>/dev/null || true)
  if [ -n "$API_KEY" ]; then
    log_info "Using API key from Doppler ($ENV_KEY)"
  fi
fi

# Fallback to environment variable
if [ -z "$API_KEY" ]; then
  API_KEY="${!ENV_KEY}"
fi

# Status check mode
if [ "$STATUS_CHECK" = true ]; then
  echo "=== AI Dispatch Status ==="
  echo ""
  echo "Provider: $PROVIDER_NAME ($ACTIVE_PROVIDER)"
  echo ""

  if [ -f "$PID_FILE" ]; then
    SESSION_OR_PID=$(cat "$PID_FILE")
    # Check if it's a tmux session name (starts with "ai-dispatch-") or a PID
    if [[ "$SESSION_OR_PID" == ai-dispatch-* ]]; then
      if tmux has-session -t "$SESSION_OR_PID" 2>/dev/null; then
        echo "Status: RUNNING in tmux session"
        echo "Session: $SESSION_OR_PID"
        echo ""
        echo "Attach with: tmux attach -t $SESSION_OR_PID"
        echo "Or:          ./orchestrate.sh ai-attach"
      else
        echo "Status: COMPLETED (session ended)"
        rm -f "$PID_FILE"
      fi
    else
      # Legacy PID-based check
      if ps -p "$SESSION_OR_PID" > /dev/null 2>&1; then
        echo "Status: RUNNING (PID: $SESSION_OR_PID)"
      else
        echo "Status: COMPLETED (process exited)"
        rm -f "$PID_FILE"
      fi
    fi
  else
    echo "Status: NOT RUNNING"
  fi

  echo ""

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

# Background mode: use tmux for persistent sessions
if [ "$BACKGROUND" = true ]; then
  SESSION_NAME="ai-dispatch-${ACTIVE_PROVIDER}"

  # Check if tmux is available
  if ! command -v tmux &> /dev/null; then
    log_warn "tmux not found, falling back to nohup"
    log_info "Install tmux for persistent sessions: brew install tmux"

    nohup "$0" > "$LOG_FILE" 2>&1 &
    echo $! > "$PID_FILE"

    log_success "AI dispatch started in background (PID: $(cat "$PID_FILE"))"
    echo ""
    echo "Monitor with: ./.agents/dispatch-ai.sh --status"
    echo "Or read log:  tail -f .agents/ai-dispatch.log"
    exit 0
  fi

  # Check if session already exists
  if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    log_warn "Session '$SESSION_NAME' already exists"
    log_info "Attach with: tmux attach -t $SESSION_NAME"
    log_info "Or kill it:  tmux kill-session -t $SESSION_NAME"
    exit 1
  fi

  log_info "Starting AI dispatch in tmux session..."
  log_info "Provider: $PROVIDER_NAME"
  log_info "Session: $SESSION_NAME"
  log_info "Log file: $LOG_FILE"

  # Start in detached tmux session with logging
  tmux new-session -d -s "$SESSION_NAME" "cd '$PROJECT_ROOT' && '$0' --foreground 2>&1 | tee '$LOG_FILE'"
  echo "$SESSION_NAME" > "$PID_FILE"

  log_success "AI dispatch started in tmux session: $SESSION_NAME"
  echo ""
  echo "Claude Code can continue working while tasks run."
  echo ""
  echo "Commands:"
  echo "  Attach:    tmux attach -t $SESSION_NAME"
  echo "  Status:    ./.agents/dispatch-ai.sh --status"
  echo "  Monitor:   tail -f .agents/ai-dispatch.log"
  echo "  Kill:      tmux kill-session -t $SESSION_NAME"
  exit 0
fi

# Validate requirements based on provider type
if [ "$PROVIDER_TYPE" == "cli" ]; then
  # CLI-based provider (Codex)
  CLI_NAME=$(echo "$CLI_COMMAND" | awk '{print $1}')
  if ! command -v "$CLI_NAME" &> /dev/null; then
    log_error "$CLI_NAME CLI not found. Install with: npm install -g @openai/codex"
    exit 1
  fi
else
  # API-based provider
  if [ -z "$API_KEY" ]; then
    log_error "API key not set. Please set $ENV_KEY environment variable."
    exit 1
  fi

  if ! command -v curl &> /dev/null; then
    log_error "curl not found. Please install curl."
    exit 1
  fi

  if ! command -v jq &> /dev/null; then
    log_error "jq not found. Please install jq."
    exit 1
  fi
fi

# Find task files
if [ "$RETRY_MODE" = true ]; then
  TASK_FILES=$(find "$TASKS_DIR" -maxdepth 1 -name "*-retry.md" 2>/dev/null | sort)
  log_time "RETRY MODE: Looking for retry tasks"
else
  TASK_FILES=$(find "$TASKS_DIR" -maxdepth 1 -name "task-*.md" ! -name "*-retry.md" ! -name "TEMPLATE.md" 2>/dev/null | sort)
fi
TASK_COUNT=$(echo "$TASK_FILES" | grep -c . || true)

if [ "$TASK_COUNT" -eq 0 ]; then
  if [ "$RETRY_MODE" = true ]; then
    log_warn "No retry tasks found in $TASKS_DIR"
  else
    log_warn "No AI tasks found in $TASKS_DIR"
    echo "Task files should be named: task-X.X-<name>.md"
  fi
  exit 0
fi

log_time "Found $TASK_COUNT task(s) for $PROVIDER_NAME"

cd "$PROJECT_ROOT"

# Create outputs directory
mkdir -p "$OUTPUTS_DIR"

# Function to call API provider
call_api_provider() {
  local task_file="$1"
  local task_name="$2"
  local output_file="$OUTPUTS_DIR/${task_name}-response.md"
  
  # Read task content
  local task_content
  task_content=$(cat "$task_file")
  
  # Build system prompt
  local system_prompt="You are a coding assistant executing a task. Read the task carefully and provide the complete implementation. Output code in markdown code blocks with the filename as a comment on the first line. Be precise and complete."
  
  # Escape for JSON
  local escaped_task
  escaped_task=$(echo "$task_content" | jq -Rs .)
  local escaped_system
  escaped_system=$(echo "$system_prompt" | jq -Rs .)
  
  # Build request body
  local request_body
  request_body=$(cat <<EOF
{
  "model": "$MODEL",
  "messages": [
    {"role": "system", "content": $escaped_system},
    {"role": "user", "content": $escaped_task}
  ],
  "max_tokens": $MAX_TOKENS,
  "temperature": $TEMPERATURE
}
EOF
)
  
  # Make API call
  local response
  response=$(curl -s -X POST "${API_BASE}/chat/completions" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $API_KEY" \
    -d "$request_body")
  
  # Check for errors
  local error
  error=$(echo "$response" | jq -r '.error.message // empty')
  if [ -n "$error" ]; then
    log_error "API error for $task_name: $error"
    echo "ERROR: $error" > "$output_file"
    return 1
  fi
  
  # Extract response content
  local content
  content=$(echo "$response" | jq -r '.choices[0].message.content // empty')
  
  if [ -z "$content" ]; then
    log_error "Empty response for $task_name"
    echo "ERROR: Empty response" > "$output_file"
    return 1
  fi
  
  # Save response
  echo "$content" > "$output_file"
  log_time "Response saved: $output_file"
  
  # Parse and apply code blocks (extract files from response)
  apply_code_blocks "$content" "$task_name"
  
  return 0
}

# Function to apply code blocks from response
apply_code_blocks() {
  local content="$1"
  local task_name="$2"
  
  # Extract code blocks with file paths
  # Look for patterns like: ```language\n// filename: path/to/file.ext
  # or ```language:path/to/file.ext
  
  local temp_file=$(mktemp)
  echo "$content" > "$temp_file"
  
  # Use awk to extract and apply code blocks
  awk '
    /^```[a-z]*:/ {
      # Format: ```lang:path/to/file
      split($0, parts, ":")
      gsub(/```[a-z]*/, "", parts[1])
      filepath = parts[2]
      in_block = 1
      code = ""
      next
    }
    /^```[a-z]*$/ && !in_block {
      in_block = 1
      filepath = ""
      code = ""
      next
    }
    /^\/\/ filename:/ && in_block && filepath == "" {
      gsub(/^\/\/ filename: */, "")
      filepath = $0
      next
    }
    /^# filename:/ && in_block && filepath == "" {
      gsub(/^# filename: */, "")
      filepath = $0
      next
    }
    /^```$/ && in_block {
      if (filepath != "" && code != "") {
        # Write to file
        print code > filepath
        close(filepath)
        print "[APPLIED] " filepath
      }
      in_block = 0
      filepath = ""
      code = ""
      next
    }
    in_block {
      if (code != "") code = code "\n"
      code = code $0
    }
  ' "$temp_file"
  
  rm -f "$temp_file"
}

# Function to call CLI provider (Codex)
call_cli_provider() {
  local task_file="$1"
  local task_name="$2"
  
  # Run Codex CLI
  eval "$CLI_COMMAND" < "$task_file"
}

# Dry run mode
if [ "$DRY_RUN" = true ]; then
  log_info "Dry run mode - printing commands:"
  log_info "Provider: $PROVIDER_NAME ($ACTIVE_PROVIDER)"
  echo ""
  
  for task_file in $TASK_FILES; do
    task_name=$(basename "$task_file" .md)
    echo "  # $task_name"
    
    if [ "$PROVIDER_TYPE" == "cli" ]; then
      echo "  $CLI_COMMAND < $task_file &"
    else
      echo "  curl -X POST \"${API_BASE}/chat/completions\" \\"
      echo "    -H \"Authorization: Bearer \$${ENV_KEY}\" \\"
      echo "    -d '{\"model\": \"$MODEL\", \"messages\": [...]}' &"
    fi
    echo ""
  done
  exit 0
fi

# Run all tasks in parallel
log_time "Starting all tasks with $PROVIDER_NAME..."
pids=()
task_names=()

for task_file in $TASK_FILES; do
  task_name=$(basename "$task_file" .md)
  log_time "Starting: $task_name"
  task_names+=("$task_name")
  
  if [ "$PROVIDER_TYPE" == "cli" ]; then
    (call_cli_provider "$task_file" "$task_name") &
  else
    (call_api_provider "$task_file" "$task_name") &
  fi
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

# Write failure tracking file
cat > "$FAILURES_FILE" <<EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "provider": "$ACTIVE_PROVIDER",
  "total": ${#pids[@]},
  "completed": ${#completed_tasks[@]},
  "failed": $failed,
  "failed_tasks": $(printf '%s\n' "${failed_tasks[@]}" | jq -R . | jq -s .),
  "completed_tasks": $(printf '%s\n' "${completed_tasks[@]}" | jq -R . | jq -s .)
}
EOF

# Sync results back to state.json
STATE_FILE="$SCRIPT_DIR/state.json"
STATE_LOCK_DIR="${STATE_FILE}.lockdir"

if [ -f "$STATE_FILE" ]; then
  log_time "Syncing results to state.json..."
  
  max_attempts=50
  attempt=0
  while ! mkdir "$STATE_LOCK_DIR" 2>/dev/null; do
    ((attempt++))
    if [ "$attempt" -ge "$max_attempts" ]; then
      log_time "WARNING: Failed to acquire state lock after $max_attempts attempts"
      break
    fi
    sleep 0.1
  done
  
  if [ "$attempt" -lt "$max_attempts" ]; then
    tmp="${STATE_FILE}.tmp"
    if jq \
      --argjson completed "${#completed_tasks[@]}" \
      --argjson failed "$failed" \
      --argjson total "${#pids[@]}" \
      --arg provider "$ACTIVE_PROVIDER" \
      '.phases.execution.codex.tasks_completed = $completed |
       .phases.execution.codex.tasks_failed = $failed |
       .phases.execution.codex.tasks_total = $total |
       .phases.execution.codex.provider = $provider |
       .phases.execution.codex.last_sync = "'"$(date -u +"%Y-%m-%dT%H:%M:%SZ")"'"' \
      "$STATE_FILE" > "$tmp" 2>/dev/null && mv "$tmp" "$STATE_FILE"; then
      log_time "State synced: $((${#completed_tasks[@]}))/${#pids[@]} completed, $failed failed"
    else
      log_time "WARNING: Failed to sync state"
    fi
    rmdir "$STATE_LOCK_DIR" 2>/dev/null || true
  fi
fi

# Cleanup PID file
rm -f "$PID_FILE"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_time "AI DISPATCH COMPLETE ($PROVIDER_NAME)"

if [ $failed -gt 0 ]; then
  log_warn "Completed with $failed failure(s) out of ${#pids[@]} task(s)"
  echo ""
  echo "Next steps:"
  echo "  1. Check failed task outputs in $OUTPUTS_DIR"
  echo "  2. Fix issues and re-run: $0 --retry"
  echo "  3. Run './orchestrate.sh codex-commit' when ready"
  exit 1
else
  log_success "All $TASK_COUNT task(s) completed successfully!"
  echo ""
  echo "Next steps:"
  echo "  1. Review outputs: ls $OUTPUTS_DIR"
  echo "  2. Review changes: git diff"
  echo "  3. Commit: ./orchestrate.sh codex-commit"
  echo "  4. Mark complete: ./orchestrate.sh codex-complete"
fi
