#!/bin/bash
#
# Multi-Agent Orchestration Script
# Coordinates Claude (sequential) + Codex (parallel) execution
#
# Usage:
#   ./orchestrate.sh start <feature-name>   # Start new feature
#   ./orchestrate.sh status                 # Show current state
#   ./orchestrate.sh resume                 # Resume from checkpoint
#   ./orchestrate.sh codex-dispatch         # Dispatch pending Codex tasks
#   ./orchestrate.sh codex-status           # Check Codex task status
#   ./orchestrate.sh approve <checkpoint>   # Approve checkpoint (research|plan|review)
#   ./orchestrate.sh reject research        # Reject feature (stop development)
#   ./orchestrate.sh reset                  # Reset to idle state

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
STATE_FILE="$SCRIPT_DIR/state.json"
CODEX_TASKS_DIR="$SCRIPT_DIR/codex-tasks"
OUTPUTS_DIR="$SCRIPT_DIR/outputs"
PLANS_DIR="$PROJECT_ROOT/docs/plans/active"
CODEX_LOG_FILE="$SCRIPT_DIR/codex-dispatch.log"
CODEX_FAILURES_FILE="$SCRIPT_DIR/codex-failures.json"
CONFIG_FILE="$SCRIPT_DIR/config.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Helper functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_phase() { echo -e "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"; echo -e "${CYAN}  $1${NC}"; echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"; }
log_decision() { echo -e "${MAGENTA}[DECISION]${NC} $1"; }

# Show next command hint based on current phase
# Usage: show_next_command [workflow_type]
show_next_command() {
  local workflow_type="${1:-feature}"
  local phase=$(get_state '.phase')
  local autonomous=$(get_state '.autonomous.enabled // false')

  echo ""
  echo -e "${CYAN}┌─────────────────────────────────────────────────────────────┐${NC}"
  echo -e "${CYAN}│${NC}  ${YELLOW}▶ NEXT COMMAND${NC}                                            ${CYAN}│${NC}"
  echo -e "${CYAN}├─────────────────────────────────────────────────────────────┤${NC}"

  if [ "$workflow_type" == "bugfix" ]; then
    case "$phase" in
      idle)
        echo -e "${CYAN}│${NC}  ./orchestrate.sh bug \"<title>\" [critical|major|minor]     ${CYAN}│${NC}"
        ;;
      triage)
        echo -e "${CYAN}│${NC}  # After identifying root cause:                           ${CYAN}│${NC}"
        echo -e "${CYAN}│${NC}  ./orchestrate.sh approve triage                           ${CYAN}│${NC}"
        ;;
      plan)
        echo -e "${CYAN}│${NC}  # After creating fix plan:                                ${CYAN}│${NC}"
        echo -e "${CYAN}│${NC}  ./orchestrate.sh approve plan                             ${CYAN}│${NC}"
        ;;
      fix)
        echo -e "${CYAN}│${NC}  # After implementing fix:                                 ${CYAN}│${NC}"
        echo -e "${CYAN}│${NC}  ./orchestrate.sh fix-complete                             ${CYAN}│${NC}"
        ;;
      verify)
        echo -e "${CYAN}│${NC}  # After verification and PR:                              ${CYAN}│${NC}"
        echo -e "${CYAN}│${NC}  ./orchestrate.sh bug-complete                             ${CYAN}│${NC}"
        ;;
      *)
        echo -e "${CYAN}│${NC}  ./orchestrate.sh bug-status                               ${CYAN}│${NC}"
        ;;
    esac
  else
    case "$phase" in
      idle)
        echo -e "${CYAN}│${NC}  ./orchestrate.sh start <feature-name>                     ${CYAN}│${NC}"
        ;;
      research)
        echo -e "${CYAN}│${NC}  # Claude: Read .agents/prompts/researcher.md              ${CYAN}│${NC}"
        echo -e "${CYAN}│${NC}  # After research complete:                                ${CYAN}│${NC}"
        echo -e "${CYAN}│${NC}  ./orchestrate.sh approve research   # GO                  ${CYAN}│${NC}"
        echo -e "${CYAN}│${NC}  ./orchestrate.sh reject research    # NO-GO               ${CYAN}│${NC}"
        ;;
      architect)
        echo -e "${CYAN}│${NC}  # Claude: Read .agents/prompts/architect.md               ${CYAN}│${NC}"
        echo -e "${CYAN}│${NC}  # After architecture complete:                            ${CYAN}│${NC}"
        echo -e "${CYAN}│${NC}  ./orchestrate.sh next                                     ${CYAN}│${NC}"
        ;;
      planner)
        echo -e "${CYAN}│${NC}  # Claude: Read .agents/prompts/planner.md                 ${CYAN}│${NC}"
        echo -e "${CYAN}│${NC}  # After plan + Codex tasks created:                       ${CYAN}│${NC}"
        echo -e "${CYAN}│${NC}  ./orchestrate.sh approve plan                             ${CYAN}│${NC}"
        ;;
      execution)
        local claude_status=$(get_state '.phases.execution.claude.status')
        local codex_status=$(get_state '.phases.execution.codex.status')
        if [ "$codex_status" == "pending" ]; then
          echo -e "${CYAN}│${NC}  ./orchestrate.sh codex-dispatch      # Start Codex        ${CYAN}│${NC}"
        elif [ "$codex_status" == "running" ]; then
          echo -e "${CYAN}│${NC}  ./orchestrate.sh codex-status        # Check Codex        ${CYAN}│${NC}"
          echo -e "${CYAN}│${NC}  ./orchestrate.sh codex-complete      # When done          ${CYAN}│${NC}"
        fi
        if [ "$claude_status" == "in_progress" ]; then
          echo -e "${CYAN}│${NC}  ./orchestrate.sh claude-complete     # When Claude done   ${CYAN}│${NC}"
        fi
        if [ "$claude_status" == "complete" ] && [ "$codex_status" == "complete" ]; then
          echo -e "${CYAN}│${NC}  # Both complete! Moving to review...                      ${CYAN}│${NC}"
        fi
        ;;
      reviewer)
        echo -e "${CYAN}│${NC}  # Claude: Read .agents/prompts/reviewer.md                ${CYAN}│${NC}"
        echo -e "${CYAN}│${NC}  # After review complete:                                  ${CYAN}│${NC}"
        echo -e "${CYAN}│${NC}  ./orchestrate.sh approve review                           ${CYAN}│${NC}"
        ;;
      integrator)
        echo -e "${CYAN}│${NC}  # Claude: Read .agents/prompts/integrator.md              ${CYAN}│${NC}"
        echo -e "${CYAN}│${NC}  # After integration complete:                             ${CYAN}│${NC}"
        echo -e "${CYAN}│${NC}  ./orchestrate.sh complete                                 ${CYAN}│${NC}"
        ;;
      complete)
        echo -e "${CYAN}│${NC}  ./orchestrate.sh reset               # Start new feature  ${CYAN}│${NC}"
        ;;
      *)
        echo -e "${CYAN}│${NC}  ./orchestrate.sh status                                   ${CYAN}│${NC}"
        ;;
    esac
  fi

  echo -e "${CYAN}└─────────────────────────────────────────────────────────────┘${NC}"

  # Show autonomous mode hint if enabled
  if [ "$autonomous" == "true" ]; then
    local expires=$(get_state '.autonomous.expires_at // "unknown"')
    echo -e "  ${GREEN}⚡ Autonomous mode ON${NC} (expires: $expires)"
  fi
}

# ============================================================================
# PRE-FLIGHT CHECK FUNCTIONS
# ============================================================================

# Check if a command exists
command_exists() {
  command -v "$1" &> /dev/null
}

# Run all pre-flight checks
# Returns 0 if all pass, 1 if any fail
# Set PREFLIGHT_STRICT=1 to fail on warnings too
run_preflight_checks() {
  local strict="${PREFLIGHT_STRICT:-0}"
  local errors=0
  local warnings=0

  log_phase "PRE-FLIGHT CHECKS"

  # 1. Check required tools
  echo "Checking required tools..."

  if command_exists git; then
    echo -e "  ${GREEN}✓${NC} git"
  else
    echo -e "  ${RED}✗${NC} git - Required for version control"
    ((errors++))
  fi

  if command_exists jq; then
    echo -e "  ${GREEN}✓${NC} jq"
  else
    echo -e "  ${RED}✗${NC} jq - Required for JSON parsing"
    echo "    Install: brew install jq (macOS) or apt install jq (Linux)"
    ((errors++))
  fi

  if command_exists gh; then
    echo -e "  ${GREEN}✓${NC} gh (GitHub CLI)"
  else
    echo -e "  ${YELLOW}⚠${NC} gh (GitHub CLI) - Required for bug-fix workflow"
    echo "    Install: brew install gh (macOS) or https://cli.github.com"
    ((warnings++))
  fi

  echo ""

  # 2. Check if in a git repository
  echo "Checking git repository..."

  if git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "  ${GREEN}✓${NC} Inside git repository"

    # 3. Check for uncommitted changes
    if git diff --quiet && git diff --staged --quiet; then
      echo -e "  ${GREEN}✓${NC} Working directory clean"
    else
      local changed_files=$(git status --short | wc -l | tr -d ' ')
      echo -e "  ${YELLOW}⚠${NC} Uncommitted changes ($changed_files files)"
      echo "    Consider committing or stashing before starting workflow"
      ((warnings++))
    fi

    # 4. Check current branch
    local current_branch=$(git branch --show-current 2>/dev/null || echo "detached")
    local default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")

    if [ "$current_branch" == "$default_branch" ] || [ "$current_branch" == "main" ] || [ "$current_branch" == "master" ]; then
      echo -e "  ${GREEN}✓${NC} On base branch: $current_branch"
    else
      echo -e "  ${YELLOW}⚠${NC} Not on base branch (current: $current_branch)"
      echo "    Consider switching to $default_branch before starting"
      ((warnings++))
    fi

    # 5. Check if remote is configured
    if git remote get-url origin > /dev/null 2>&1; then
      local remote_url=$(git remote get-url origin)
      echo -e "  ${GREEN}✓${NC} Remote configured: $remote_url"
    else
      echo -e "  ${YELLOW}⚠${NC} No remote 'origin' configured"
      ((warnings++))
    fi

  else
    echo -e "  ${RED}✗${NC} Not inside a git repository"
    echo "    Run: git init"
    ((errors++))
  fi

  echo ""

  # 6. Check GitHub CLI authentication (if gh is available)
  if command_exists gh; then
    echo "Checking GitHub CLI..."

    if gh auth status > /dev/null 2>&1; then
      local gh_user=$(gh api user --jq '.login' 2>/dev/null || echo "unknown")
      echo -e "  ${GREEN}✓${NC} Authenticated as: $gh_user"
    else
      echo -e "  ${YELLOW}⚠${NC} GitHub CLI not authenticated"
      echo "    Run: gh auth login"
      ((warnings++))
    fi
    echo ""
  fi

  # 7. Check state file
  echo "Checking orchestration state..."

  if [ -f "$STATE_FILE" ]; then
    local current_phase=$(jq -r '.phase // "unknown"' "$STATE_FILE" 2>/dev/null)
    if [ "$current_phase" == "idle" ]; then
      echo -e "  ${GREEN}✓${NC} State: idle (ready for new workflow)"
    else
      echo -e "  ${YELLOW}⚠${NC} Workflow in progress (phase: $current_phase)"
      echo "    Run: ./orchestrate.sh reset to clear"
      ((warnings++))
    fi
  else
    echo -e "  ${YELLOW}⚠${NC} State file not found (will be created)"
    ((warnings++))
  fi

  echo ""

  # Summary
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  if [ "$errors" -gt 0 ]; then
    echo -e "${RED}Pre-flight failed: $errors error(s), $warnings warning(s)${NC}"
    echo ""
    echo "Fix the errors above before proceeding."
    return 1
  elif [ "$warnings" -gt 0 ]; then
    echo -e "${YELLOW}Pre-flight passed with $warnings warning(s)${NC}"
    if [ "$strict" -eq 1 ]; then
      echo ""
      echo "Strict mode enabled. Fix warnings before proceeding."
      return 1
    fi
    return 0
  else
    echo -e "${GREEN}Pre-flight passed: All checks OK${NC}"
    return 0
  fi
}

# Quick pre-flight for start/bug commands (non-blocking warnings)
quick_preflight() {
  local errors=0

  # Must have git
  if ! command_exists git; then
    log_error "git not found. Please install git."
    return 1
  fi

  # Must have jq
  if ! command_exists jq; then
    log_error "jq not found. Install: brew install jq (macOS) or apt install jq (Linux)"
    return 1
  fi

  # Must be in a git repo
  if ! git rev-parse --git-dir > /dev/null 2>&1; then
    log_error "Not in a git repository. Run: git init"
    return 1
  fi

  # Check for existing workflow
  if [ -f "$STATE_FILE" ]; then
    local current_phase=$(jq -r '.phase // "idle"' "$STATE_FILE" 2>/dev/null)
    if [ "$current_phase" != "idle" ] && [ "$current_phase" != "null" ]; then
      log_error "Workflow already in progress (phase: $current_phase)"
      log_info "Run: ./orchestrate.sh reset to clear"
      return 1
    fi
  fi

  # Warn about uncommitted changes (non-blocking)
  if ! git diff --quiet || ! git diff --staged --quiet; then
    local changed_files=$(git status --short | wc -l | tr -d ' ')
    log_warn "You have $changed_files uncommitted file(s). Consider committing first."
  fi

  return 0
}

# Bug-fix specific pre-flight (requires gh)
bugfix_preflight() {
  # Run quick preflight first
  if ! quick_preflight; then
    return 1
  fi

  # Must have gh for bug-fix workflow
  if ! command_exists gh; then
    log_error "GitHub CLI (gh) not found. Required for bug-fix workflow."
    echo "Install: brew install gh (macOS) or https://cli.github.com"
    return 1
  fi

  # Must be authenticated
  if ! gh auth status > /dev/null 2>&1; then
    log_error "GitHub CLI not authenticated."
    echo "Run: gh auth login"
    return 1
  fi

  return 0
}

# ============================================================================
# ABORT / ROLLBACK FUNCTIONS
# ============================================================================

# Soft abort - saves current state and marks workflow as aborted
# User can resume later or rollback
abort_workflow() {
  local phase=$(get_state '.phase')

  if [ "$phase" == "idle" ]; then
    log_warn "No active workflow to abort"
    return 0
  fi

  log_phase "ABORTING WORKFLOW"

  local feature=$(get_state '.feature')
  local bug_title=$(get_state '.bug.title')
  local workflow_type=$(get_state '.type // "feature"')

  echo "Current phase: $phase"
  if [ "$workflow_type" == "bugfix" ]; then
    echo "Bug: $bug_title"
  else
    echo "Feature: $feature"
  fi
  echo ""

  log_warn "This will pause the workflow. You can resume later."
  echo "Continue? (y/N)"
  read -r confirm
  if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    log_info "Cancelled"
    return 0
  fi

  # Save abort state
  set_state '.aborted' 'true'
  set_state '.aborted_at' "\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\""
  set_state '.aborted_phase' "\"$phase\""
  add_history "Workflow aborted at phase: $phase"

  log_success "Workflow aborted"
  echo ""
  echo "To resume: ./orchestrate.sh resume"
  echo "To rollback: ./orchestrate.sh rollback"
  echo "To reset: ./orchestrate.sh reset"
}

# Hard rollback - discards all changes and resets to clean state
# WARNING: This is destructive!
rollback_workflow() {
  local phase=$(get_state '.phase')

  if [ "$phase" == "idle" ]; then
    log_warn "No active workflow to rollback"
    return 0
  fi

  log_phase "ROLLBACK WORKFLOW"

  local feature=$(get_state '.feature')
  local bug_title=$(get_state '.bug.title')
  local workflow_type=$(get_state '.type // "feature"')
  local main_branch=$(get_state '.branch.main')
  local codex_branch=$(get_state '.branch.codex')

  echo -e "${RED}WARNING: This is a DESTRUCTIVE operation!${NC}"
  echo ""
  echo "This will:"
  echo "  1. Discard all uncommitted changes"
  echo "  2. Delete feature/fix branches (if created)"
  echo "  3. Reset orchestration state to idle"
  echo "  4. Return to the base branch"
  echo ""

  if [ "$workflow_type" == "bugfix" ]; then
    echo "Bug: $bug_title"
    local issue_number=$(get_state '.bug.issue_number')
    if [ -n "$issue_number" ] && [ "$issue_number" != "null" ]; then
      echo "Note: GitHub issue #$issue_number will NOT be deleted"
      echo "      Close it manually if needed: gh issue close $issue_number"
    fi
  else
    echo "Feature: $feature"
  fi
  echo ""

  echo -e "${RED}Type 'ROLLBACK' to confirm:${NC}"
  read -r confirm
  if [ "$confirm" != "ROLLBACK" ]; then
    log_info "Cancelled (did not type ROLLBACK)"
    return 0
  fi

  cd "$PROJECT_ROOT"

  # Get default branch
  local default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo "main")

  # Stash orchestrate.sh changes before checkout (preserve our changes)
  # This is important because git checkout . would revert uncommitted edits

  # Discard all changes EXCEPT orchestrate.sh
  log_info "Discarding uncommitted changes..."
  git checkout -- . ':!.agents/orchestrate.sh' 2>/dev/null || git checkout . 2>/dev/null || true
  git clean -fd 2>/dev/null || true

  # Switch to default branch
  log_info "Switching to $default_branch..."
  git checkout "$default_branch" 2>/dev/null || git checkout main 2>/dev/null || git checkout master 2>/dev/null || true

  # Delete feature branches (local only, not remote)
  if [ -n "$main_branch" ] && [ "$main_branch" != "null" ]; then
    if git show-ref --verify --quiet "refs/heads/$main_branch"; then
      log_info "Deleting branch: $main_branch"
      git branch -D "$main_branch" 2>/dev/null || true
    fi
  fi

  if [ -n "$codex_branch" ] && [ "$codex_branch" != "null" ]; then
    if git show-ref --verify --quiet "refs/heads/$codex_branch"; then
      log_info "Deleting branch: $codex_branch"
      git branch -D "$codex_branch" 2>/dev/null || true
    fi
  fi

  # Record in history before reset
  add_history "Rollback performed from phase: $phase"

  # Reset state
  reset_state_silent

  log_success "Rollback complete!"
  echo ""
  echo "State has been reset to idle."
  echo "You can start fresh with: ./orchestrate.sh start <feature-name>"
}

# Model selection based on phase and complexity
# Usage: get_model_for_phase <phase> [complexity]
# Complexity: simple | medium | complex (default: medium)
get_model_for_phase() {
  local phase="$1"
  local complexity="${2:-medium}"

  case "$phase" in
    research)
      [[ "$complexity" == "simple" ]] && echo "haiku" || echo "sonnet"
      ;;
    architect)
      echo "opus"
      ;;
    planner|integrator)
      echo "sonnet"
      ;;
    execution)
      case "$complexity" in
        simple) echo "haiku" ;;
        complex) echo "opus" ;;
        *) echo "sonnet" ;;
      esac
      ;;
    reviewer)
      [[ "$complexity" == "simple" ]] && echo "haiku" || echo "sonnet"
      ;;
    *)
      echo "sonnet"
      ;;
  esac
}

# Update model hint in state (called on phase transitions)
# Claude Code should read this to know which model to use for subagents
update_model_hint() {
  local phase="$1"
  local complexity="${2:-medium}"
  local model=$(get_model_for_phase "$phase" "$complexity")

  set_state '.model_hint.phase' "\"$phase\""
  set_state '.model_hint.complexity' "\"$complexity\""
  set_state '.model_hint.recommended_model' "\"$model\""
  set_state '.model_hint.updated_at' "\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\""

  # Also write to a simple file for easy reading
  local hint_file="$SCRIPT_DIR/model-hint.txt"
  echo "$model" > "$hint_file"

  log_info "Model hint updated: $model (phase: $phase, complexity: $complexity)"
}

# Get current model hint
get_model_hint() {
  local hint=$(get_state '.model_hint.recommended_model // "sonnet"')
  echo "$hint"
}

# Show model recommendation
show_model_recommendation() {
  local phase="$1"
  local complexity="$2"

  local model=$(get_model_for_phase "$phase" "$complexity")

  echo ""
  echo "Phase:      $phase"
  echo "Complexity: ${complexity:-medium}"
  echo "Model:      $model"
  echo ""
  echo "Model capabilities:"
  case "$model" in
    haiku)
      echo "  - Fast, cheap"
      echo "  - Good for: scanning, formatting, boilerplate"
      echo "  - Always use with fallback to sonnet"
      ;;
    sonnet)
      echo "  - Balanced, good coding"
      echo "  - Good for: implementation, review, testing"
      echo "  - Default choice for most tasks"
      ;;
    opus)
      echo "  - Complex reasoning, architecture"
      echo "  - Good for: design, debugging, security"
      echo "  - Use when sonnet fails or task is critical"
      ;;
  esac
}

# Estimate context tokens from file
# Rough estimate: 1 token ~= 4 characters
estimate_context() {
  local file="$1"
  if [ -f "$file" ]; then
    local chars=$(wc -c < "$file" | tr -d ' ')
    local tokens=$((chars / 4))
    echo "$tokens"
  else
    echo "0"
  fi
}

# Check context budget and warn if over threshold
show_context_budget() {
  log_phase "CONTEXT BUDGET ESTIMATE"

  local total=0
  local threshold=50000

  echo "File                                          Tokens"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # Core files always loaded
  for file in "$PROJECT_ROOT/CLAUDE.md" "$STATE_FILE"; do
    if [ -f "$file" ]; then
      local tokens=$(estimate_context "$file")
      local name=$(basename "$file")
      printf "%-44s %6d\n" "$name" "$tokens"
      total=$((total + tokens))
    fi
  done

  # Active plan files
  if [ -d "$PLANS_DIR" ]; then
    for file in "$PLANS_DIR"/*.md; do
      if [ -f "$file" ]; then
        local tokens=$(estimate_context "$file")
        local name="plans/active/$(basename "$file")"
        printf "%-44s %6d\n" "$name" "$tokens"
        total=$((total + tokens))
      fi
    done
  fi

  # Agent outputs
  if [ -d "$OUTPUTS_DIR" ]; then
    for file in "$OUTPUTS_DIR"/*.md; do
      if [ -f "$file" ]; then
        local tokens=$(estimate_context "$file")
        local name="outputs/$(basename "$file")"
        printf "%-44s %6d\n" "$name" "$tokens"
        total=$((total + tokens))
      fi
    done
  fi

  # Codex task files
  local codex_total=0
  for file in "$CODEX_TASKS_DIR"/task-*.md; do
    if [ -f "$file" ]; then
      local tokens=$(estimate_context "$file")
      codex_total=$((codex_total + tokens))
    fi
  done
  if [ "$codex_total" -gt 0 ]; then
    printf "%-44s %6d\n" "codex-tasks/*.md (combined)" "$codex_total"
    total=$((total + codex_total))
  fi

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  printf "%-44s %6d\n" "TOTAL" "$total"
  echo ""

  if [ "$total" -gt "$threshold" ]; then
    log_warn "Context budget over ${threshold} tokens!"
    echo ""
    echo "Recommendations:"
    echo "  - Archive completed plan files"
    echo "  - Compress handoff notes"
    echo "  - Split large files into sections"
  else
    local remaining=$((threshold - total))
    log_success "Context budget OK ($remaining tokens remaining)"
  fi
}

# Read state
get_state() {
  local key="$1"
  jq -r "$key" "$STATE_FILE"
}

# Update state
set_state() {
  local key="$1"
  local value="$2"
  local tmp=$(mktemp)
  jq "$key = $value" "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
}

# Add history entry
add_history() {
  local message="$1"
  local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local tmp=$(mktemp)
  jq ".history += [{\"timestamp\": \"$timestamp\", \"message\": \"$message\"}]" "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
}

# ============================================================================
# BUG-FIX WORKFLOW FUNCTIONS
# ============================================================================

# Get severity-based model for bug-fix phases
get_bugfix_model() {
  local phase="$1"
  local severity="$2"

  case "$phase" in
    triage)
      [[ "$severity" == "minor" ]] && echo "haiku" || echo "sonnet"
      ;;
    plan)
      [[ "$severity" == "critical" ]] && echo "opus" || echo "sonnet"
      ;;
    fix)
      case "$severity" in
        critical) echo "opus" ;;
        major) echo "sonnet" ;;
        minor) echo "haiku" ;;
        *) echo "sonnet" ;;
      esac
      ;;
    verify)
      [[ "$severity" == "critical" ]] && echo "sonnet" || echo "haiku"
      ;;
    *)
      echo "sonnet"
      ;;
  esac
}

# Convert title to kebab-case for branch names
to_kebab_case() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//' | cut -c1-50
}

# Start a bug-fix workflow
start_bugfix() {
  local bug_title="$1"
  local severity="${2:-major}"

  if [ -z "$bug_title" ]; then
    log_error "Usage: ./orchestrate.sh bug \"<bug title>\" [severity]"
    echo ""
    echo "Severity options: critical, major (default), minor"
    exit 1
  fi

  # Validate severity
  case "$severity" in
    critical|major|minor) ;;
    *)
      log_error "Invalid severity: $severity"
      echo "Valid options: critical, major, minor"
      exit 1
      ;;
  esac

  # Run pre-flight checks (includes gh auth check)
  if ! bugfix_preflight; then
    exit 1
  fi

  log_phase "STARTING BUG-FIX WORKFLOW"

  # Create GitHub issue
  log_info "Creating GitHub issue..."

  local issue_output
  issue_output=$(gh issue create \
    --title "$bug_title" \
    --label "bug,severity:$severity" \
    --body "## Bug Report

**Severity:** $severity

## Description
[To be filled during triage]

## Steps to Reproduce
1. [Step 1]
2. [Step 2]
3. [Step 3]

## Expected Behavior
[What should happen]

## Actual Behavior
[What happens instead]

---
*Created via orchestration workflow*" 2>&1)

  if [ $? -ne 0 ]; then
    log_error "Failed to create GitHub issue: $issue_output"
    exit 1
  fi

  # Extract issue number from URL
  local issue_url=$(echo "$issue_output" | grep -o 'https://github.com/[^[:space:]]*')
  local issue_number=$(echo "$issue_url" | grep -o '[0-9]*$')

  if [ -z "$issue_number" ]; then
    log_error "Failed to extract issue number from: $issue_output"
    exit 1
  fi

  log_success "Created issue #$issue_number"

  # Create branch name
  local kebab_title=$(to_kebab_case "$bug_title")
  local branch_name="fix/${issue_number}-${kebab_title}"

  # Create branch
  log_info "Creating branch: $branch_name"
  cd "$PROJECT_ROOT"
  git checkout -b "$branch_name" 2>/dev/null || {
    log_error "Failed to create branch: $branch_name"
    exit 1
  }

  # Initialize state for bug-fix workflow
  set_state '.type' '"bugfix"'
  set_state '.feature' "null"
  set_state '.bug.title' "\"$bug_title\""
  set_state '.bug.issue_number' "$issue_number"
  set_state '.bug.issue_url' "\"$issue_url\""
  set_state '.bug.severity' "\"$severity\""
  set_state '.bug.branch' "\"$branch_name\""
  set_state '.branch.main' "\"$branch_name\""
  set_state '.branch.codex' "\"codex/${issue_number}-${kebab_title}\""
  set_state '.phase' '"triage"'
  set_state '.phases.triage.status' '"in_progress"'
  add_history "Started bug-fix: #$issue_number - $bug_title (severity: $severity)"

  # Set model hint based on severity
  local model=$(get_bugfix_model "triage" "$severity")
  set_state '.model_hint.phase' '"triage"'
  set_state '.model_hint.severity' "\"$severity\""
  set_state '.model_hint.recommended_model' "\"$model\""
  echo "$model" > "$SCRIPT_DIR/model-hint.txt"

  log_success "Bug-fix workflow initialized!"
  echo ""
  echo "Issue:    #$issue_number"
  echo "URL:      $issue_url"
  echo "Branch:   $branch_name"
  echo "Severity: $severity"
  echo "Model:    $model"
  echo ""
  echo "Next steps:"
  echo "  1. Claude reads .agents/prompts/triage.md"
  echo "  2. Reproduce and analyze the bug"
  echo "  3. Output triage report to .agents/outputs/triage.md"
  echo "  4. Then run './orchestrate.sh approve triage'"
}

# Show bug-fix status
show_bugfix_status() {
  log_phase "BUG-FIX STATUS"

  local bug_title=$(get_state '.bug.title')
  local issue_number=$(get_state '.bug.issue_number')
  local issue_url=$(get_state '.bug.issue_url')
  local severity=$(get_state '.bug.severity')
  local branch=$(get_state '.bug.branch')
  local phase=$(get_state '.phase')

  echo "Bug:      $bug_title"
  echo "Issue:    #$issue_number"
  echo "URL:      $issue_url"
  echo "Severity: $severity"
  echo "Branch:   $branch"
  echo "Phase:    $phase"
  echo ""

  # Show phase-specific status
  case "$phase" in
    triage)
      echo "Status: Awaiting triage"
      echo ""
      echo "Next: Reproduce bug, identify root cause"
      echo "Then: ./orchestrate.sh approve triage"
      ;;
    plan)
      echo "Status: Awaiting fix plan"
      echo ""
      echo "Next: Create fix plan with task assignments"
      echo "Then: ./orchestrate.sh approve plan"
      ;;
    fix)
      local claude_status=$(get_state '.phases.execution.claude.status')
      local codex_status=$(get_state '.phases.execution.codex.status')
      echo "Status: Fix in progress"
      echo "  Claude: $claude_status"
      echo "  Codex:  $codex_status"
      ;;
    verify)
      echo "Status: Awaiting verification"
      echo ""
      echo "Next: Verify fix, create PR"
      echo "Then: ./orchestrate.sh bug-complete"
      ;;
  esac

  # Show model hint
  local model=$(get_state '.model_hint.recommended_model')
  echo ""
  echo -e "Model: ${CYAN}$model${NC} (based on severity: $severity)"

  # Show next command hint
  show_next_command "bugfix"
}

# Resume bug-fix workflow
resume_bugfix() {
  local phase=$(get_state '.phase')
  local severity=$(get_state '.bug.severity')
  local model=$(get_bugfix_model "$phase" "$severity")

  log_phase "RESUMING BUG-FIX - Phase: $phase"
  echo -e "${YELLOW}Recommended model: $model${NC}"
  echo ""

  case "$phase" in
    triage)
      log_info "TRIAGE phase in progress"
      echo ""
      echo "Claude should:"
      echo "  1. Read .agents/prompts/triage.md"
      echo "  2. Reproduce the bug"
      echo "  3. Identify root cause"
      echo "  4. Output to .agents/outputs/triage.md"
      echo ""
      echo "When done: ./orchestrate.sh approve triage"
      ;;
    plan)
      log_info "PLAN phase in progress"
      echo ""
      echo "Claude should:"
      echo "  1. Read .agents/prompts/bugfix-planner.md"
      echo "  2. Create fix plan in docs/plans/active/"
      echo "  3. Generate Codex task files"
      echo ""
      echo "When done: ./orchestrate.sh approve plan"
      ;;
    fix)
      log_info "FIX phase in progress"
      echo ""
      echo "Claude: Implement the core fix"
      echo "Codex:  Run ./orchestrate.sh codex-dispatch"
      echo ""
      echo "When Claude done: ./orchestrate.sh claude-complete"
      echo "When Codex done:  ./orchestrate.sh codex-complete"
      ;;
    verify)
      log_info "VERIFY phase in progress"
      echo ""
      echo "Claude should:"
      echo "  1. Read .agents/prompts/verify.md"
      echo "  2. Run full test suite"
      echo "  3. Update CHANGELOG.md"
      echo "  4. Push and create PR"
      echo ""
      echo "When done: ./orchestrate.sh bug-complete"
      ;;
    *)
      log_error "Unknown phase: $phase"
      ;;
  esac

  # Show next command hint
  show_next_command "bugfix"
}

# Approve triage checkpoint
approve_triage() {
  local severity=$(get_state '.bug.severity')

  # Check for auto-approval in autonomous mode
  if check_autonomous_approval "triage"; then
    log_info "Auto-approved triage (autonomous mode)"
  fi

  set_state '.phases.triage.status' '"complete"'
  set_state '.phases.triage.approved' 'true'
  set_state '.phase' '"plan"'
  set_state '.phases.plan.status' '"in_progress"'
  add_history "Triage approved - proceeding to planning"

  # Update model hint for plan phase
  local model=$(get_bugfix_model "plan" "$severity")
  set_state '.model_hint.phase' '"plan"'
  set_state '.model_hint.recommended_model' "\"$model\""
  echo "$model" > "$SCRIPT_DIR/model-hint.txt"

  log_success "Triage approved! Moving to PLAN phase."
  echo ""
  echo "Next steps:"
  echo "  1. Claude reads .agents/prompts/bugfix-planner.md"
  echo "  2. Create fix plan in docs/plans/active/"
  echo "  3. Then run './orchestrate.sh approve plan'"
}

# Approve plan and start fix phase (for bug-fix workflow)
approve_bugfix_plan() {
  local issue_number=$(get_state '.bug.issue_number')
  local severity=$(get_state '.bug.severity')

  # Check for Codex task files
  local codex_task_count=$(find "$CODEX_TASKS_DIR" -maxdepth 1 -name "bugfix-*.md" 2>/dev/null | wc -l | tr -d ' ')

  if [ "$codex_task_count" -eq 0 ]; then
    log_warn "No Codex bugfix task files found in .agents/codex-tasks/"
    echo ""
    echo "Either:"
    echo "  a) This fix has NO parallel tasks (Claude-only) - proceed anyway? (y/N)"
    echo "  b) Planner forgot to create them - run planner again"
    echo ""
    read -r confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
      log_info "Cancelled. Please ensure Codex task files are created."
      exit 1
    fi
  else
    log_success "Found $codex_task_count Codex bugfix task file(s)"
    set_state '.phases.execution.codex.tasks_total' "$codex_task_count"
  fi

  set_state '.phases.plan.status' '"complete"'
  set_state '.phases.plan.approved' 'true'
  set_state '.phase' '"fix"'
  set_state '.phases.execution.status' '"in_progress"'
  set_state '.phases.execution.claude.status' '"in_progress"'
  add_history "Fix plan approved - starting implementation"

  # Update model hint for fix phase
  local model=$(get_bugfix_model "fix" "$severity")
  set_state '.model_hint.phase' '"fix"'
  set_state '.model_hint.recommended_model' "\"$model\""
  echo "$model" > "$SCRIPT_DIR/model-hint.txt"

  log_success "Plan approved! FIX phase started."
  echo ""
  echo "Next steps:"
  echo "  1. Claude: Implement the core fix"
  echo "  2. At HARD STOP: ./orchestrate.sh codex-dispatch"
  echo "  3. When done: ./orchestrate.sh claude-complete"
}

# Complete bug-fix workflow
complete_bugfix() {
  log_phase "COMPLETING BUG-FIX"

  local issue_number=$(get_state '.bug.issue_number')
  local bug_title=$(get_state '.bug.title')
  local branch=$(get_state '.bug.branch')

  set_state '.phases.verify.status' '"complete"'
  set_state '.phase' '"complete"'
  add_history "Bug-fix complete: #$issue_number - $bug_title"

  # Archive plan if exists
  local plan_file="$PLANS_DIR/fix-${issue_number}.md"
  if [ -f "$plan_file" ]; then
    local archive_dir="$PROJECT_ROOT/docs/plans/archive"
    mkdir -p "$archive_dir"
    local archive_name="$(date +%Y-%m-%d)-fix-${issue_number}.md"
    mv "$plan_file" "$archive_dir/$archive_name"
    log_info "Plan archived to: docs/plans/archive/$archive_name"
  fi

  log_success "Bug-fix workflow complete!"
  echo ""
  echo "Issue #$issue_number will auto-close when PR is merged."
  echo ""
  echo "Next steps:"
  echo "  1. Wait for PR review"
  echo "  2. Address review comments if any"
  echo "  3. Merge when approved"
  echo ""
  echo "To start a new workflow: ./orchestrate.sh reset"
}

# Move to verify phase after fix is complete
start_verify_phase() {
  local severity=$(get_state '.bug.severity')

  set_state '.phases.execution.status' '"complete"'
  set_state '.phase' '"verify"'
  set_state '.phases.verify.status' '"in_progress"'
  add_history "Fix complete - starting verification"

  # Update model hint for verify phase
  local model=$(get_bugfix_model "verify" "$severity")
  set_state '.model_hint.phase' '"verify"'
  set_state '.model_hint.recommended_model' "\"$model\""
  echo "$model" > "$SCRIPT_DIR/model-hint.txt"

  log_success "Moving to VERIFY phase"
  echo ""
  echo "Next steps:"
  echo "  1. Claude reads .agents/prompts/verify.md"
  echo "  2. Run full test suite"
  echo "  3. Update CHANGELOG.md"
  echo "  4. Push and create PR"
  echo "  5. Then run './orchestrate.sh bug-complete'"
}

# ============================================================================
# AUTONOMOUS MODE FUNCTIONS
# ============================================================================

# Parse duration string (e.g., "4h", "30m", "2h30m", "1d") to seconds
# Works with both bash and zsh
parse_duration() {
  local duration="$1"
  local seconds=0

  # Extract and process days (look for digits followed by 'd')
  local days=$(echo "$duration" | grep -oE '[0-9]+d' | grep -oE '[0-9]+' | head -1)
  if [ -n "$days" ]; then
    seconds=$((seconds + days * 86400))
  fi

  # Extract and process hours (look for digits followed by 'h')
  local hours=$(echo "$duration" | grep -oE '[0-9]+h' | grep -oE '[0-9]+' | head -1)
  if [ -n "$hours" ]; then
    seconds=$((seconds + hours * 3600))
  fi

  # Extract and process minutes (look for digits followed by 'm', but not 'min')
  local minutes=$(echo "$duration" | grep -oE '[0-9]+m' | grep -oE '[0-9]+' | head -1)
  if [ -n "$minutes" ]; then
    seconds=$((seconds + minutes * 60))
  fi

  # Handle raw number (assume hours for convenience)
  if echo "$duration" | grep -qE '^[0-9]+$'; then
    seconds=$((seconds + duration * 3600))
  fi

  echo "$seconds"
}

# Format seconds as human-readable duration
format_duration() {
  local seconds="$1"
  local hours=$((seconds / 3600))
  local minutes=$(((seconds % 3600) / 60))

  if [ "$hours" -gt 0 ] && [ "$minutes" -gt 0 ]; then
    echo "${hours}h ${minutes}m"
  elif [ "$hours" -gt 0 ]; then
    echo "${hours}h"
  elif [ "$minutes" -gt 0 ]; then
    echo "${minutes}m"
  else
    echo "${seconds}s"
  fi
}

# Convert ISO8601 UTC timestamp to epoch seconds (portable)
iso_to_epoch() {
  local iso="$1"
  # Remove trailing Z and parse as UTC
  local clean="${iso%Z}"

  # Try macOS date format first, then GNU date
  if date -j -u -f "%Y-%m-%dT%H:%M:%S" "$clean" "+%s" 2>/dev/null; then
    return
  elif date -u -d "$clean" "+%s" 2>/dev/null; then
    return
  else
    echo "0"
  fi
}

# Check if autonomous mode timeout has expired
is_autonomous_expired() {
  local expires_at=$(get_state '.autonomous.expires_at // null')

  if [ "$expires_at" == "null" ] || [ -z "$expires_at" ]; then
    # No timeout set - not expired
    return 1
  fi

  # Convert expires_at to epoch seconds
  local expires_epoch
  expires_epoch=$(iso_to_epoch "$expires_at")

  local now_epoch=$(date "+%s")

  if [ "$now_epoch" -ge "$expires_epoch" ]; then
    return 0  # Expired
  else
    return 1  # Not expired
  fi
}

# Get remaining time in seconds (0 if expired or no timeout)
get_remaining_seconds() {
  local expires_at=$(get_state '.autonomous.expires_at // null')

  if [ "$expires_at" == "null" ] || [ -z "$expires_at" ]; then
    echo "-1"  # No timeout set
    return
  fi

  local expires_epoch
  expires_epoch=$(iso_to_epoch "$expires_at")

  local now_epoch=$(date "+%s")
  local remaining=$((expires_epoch - now_epoch))

  if [ "$remaining" -lt 0 ]; then
    echo "0"
  else
    echo "$remaining"
  fi
}

# Check if autonomous mode is enabled (and not expired)
is_autonomous_enabled() {
  local enabled=$(get_state '.autonomous.enabled // false')

  if [ "$enabled" != "true" ]; then
    return 1
  fi

  # Check if timeout has expired
  if is_autonomous_expired; then
    # Auto-disable on timeout
    log_warn "Autonomous mode timeout expired - auto-disabling"
    set_state '.autonomous.enabled' 'false'
    add_history "Autonomous mode auto-disabled (timeout expired)"
    return 1
  fi

  return 0
}

# Check if a checkpoint should be auto-approved (autonomous mode)
# Returns 0 if auto-approved, 1 if needs human approval
check_autonomous_approval() {
  local checkpoint="$1"

  # Research ALWAYS requires human approval (safety gate)
  if [ "$checkpoint" == "research" ]; then
    return 1
  fi

  if is_autonomous_enabled; then
    log_info "Autonomous mode: auto-approving $checkpoint"

    # Track what was auto-approved
    local tmp=$(mktemp)
    jq ".autonomous.auto_approved += [\"$checkpoint\"]" "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"

    add_history "Auto-approved checkpoint: $checkpoint (autonomous mode)"
    return 0
  fi

  return 1
}

# Manage autonomous mode (enable/disable/status/extend)
autonomous_mode() {
  local action="${1:-status}"
  local param="$2"

  case "$action" in
    enable)
      # Safety gate: require research approval first
      local research_approved=$(get_state '.phases.research.approved // false')
      local triage_approved=$(get_state '.phases.triage.approved // false')
      local workflow_type=$(get_state '.type // "feature"')

      # For bug-fix workflow, check triage instead of research
      if [ "$workflow_type" == "bugfix" ]; then
        if [ "$triage_approved" != "true" ]; then
          log_error "Cannot enable autonomous mode before triage is approved"
          log_info "First run: ./orchestrate.sh approve triage"
          echo ""
          echo "Safety gate: Triage phase must be human-approved to prevent"
          echo "runaway fixes on misunderstood bugs."
          return 1
        fi
      else
        if [ "$research_approved" != "true" ]; then
          log_error "Cannot enable autonomous mode before research is approved"
          log_info "First run: ./orchestrate.sh approve research"
          echo ""
          echo "Safety gate: Research phase must be human-approved to prevent"
          echo "runaway development on invalid features."
          return 1
        fi
      fi

      # Check if already enabled
      if is_autonomous_enabled; then
        log_warn "Autonomous mode is already enabled"
        autonomous_mode status
        return 0
      fi

      # Parse optional timeout duration
      local timeout_seconds=0
      local expires_at="null"
      local timeout_display="unlimited"

      if [ -n "$param" ]; then
        timeout_seconds=$(parse_duration "$param")
        if [ "$timeout_seconds" -gt 0 ]; then
          local now_epoch=$(date "+%s")
          local expires_epoch=$((now_epoch + timeout_seconds))
          # Use portable date format
          expires_at=$(date -u -r "$expires_epoch" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || \
                       date -u -d "@$expires_epoch" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null)
          timeout_display=$(format_duration "$timeout_seconds")
        else
          log_error "Invalid timeout format: $param"
          echo "Examples: 4h, 30m, 2h30m, 8h, 1d"
          return 1
        fi
      fi

      # Enable autonomous mode
      local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
      set_state '.autonomous.enabled' 'true'
      set_state '.autonomous.enabled_at' "\"$timestamp\""
      set_state '.autonomous.enabled_by' '"user"'
      set_state '.autonomous.auto_approved' '[]'

      if [ "$expires_at" != "null" ]; then
        set_state '.autonomous.timeout_hours' "$((timeout_seconds / 3600))"
        set_state '.autonomous.expires_at' "\"$expires_at\""
        add_history "Autonomous mode enabled (timeout: $timeout_display)"
      else
        set_state '.autonomous.timeout_hours' 'null'
        set_state '.autonomous.expires_at' 'null'
        add_history "Autonomous mode enabled (no timeout)"
      fi

      log_success "Autonomous mode ENABLED"
      echo ""
      if [ "$timeout_display" != "unlimited" ]; then
        echo -e "Timeout:      ${YELLOW}$timeout_display${NC}"
        echo "Expires at:   $expires_at"
        echo ""
      else
        echo -e "Timeout:      ${YELLOW}unlimited${NC} (use './orchestrate.sh autonomous enable 4h' to set)"
        echo ""
      fi
      echo "What will be auto-approved:"
      echo "  - Plan checkpoint"
      echo "  - Review checkpoint"
      echo "  - Integration checkpoint"
      echo ""
      echo "What still requires human approval:"
      if [ "$workflow_type" == "bugfix" ]; then
        echo "  - Triage checkpoint (ALWAYS requires human - safety gate)"
      else
        echo "  - Research checkpoint (ALWAYS requires human - safety gate)"
      fi
      echo ""
      echo "To disable: ./orchestrate.sh autonomous disable"
      echo "To extend:  ./orchestrate.sh autonomous extend 2h"
      echo ""
      log_warn "Claude will now work autonomously until timeout or disabled"
      ;;
    disable)
      local enabled=$(get_state '.autonomous.enabled // false')
      if [ "$enabled" != "true" ]; then
        log_warn "Autonomous mode is already disabled"
        return 0
      fi

      set_state '.autonomous.enabled' 'false'
      set_state '.autonomous.expires_at' 'null'
      add_history "Autonomous mode disabled"

      log_success "Autonomous mode DISABLED"
      echo "All checkpoints now require human approval"
      ;;
    extend)
      local enabled=$(get_state '.autonomous.enabled // false')
      if [ "$enabled" != "true" ]; then
        log_error "Autonomous mode is not enabled. Enable it first."
        return 1
      fi

      if [ -z "$param" ]; then
        log_error "Usage: ./orchestrate.sh autonomous extend <duration>"
        echo "Examples: 2h, 30m, 4h"
        return 1
      fi

      local extend_seconds=$(parse_duration "$param")
      if [ "$extend_seconds" -le 0 ]; then
        log_error "Invalid duration: $param"
        return 1
      fi

      # Get current expiry or use now
      local current_expires=$(get_state '.autonomous.expires_at // null')
      local base_epoch

      if [ "$current_expires" == "null" ] || [ -z "$current_expires" ]; then
        # No current timeout - extend from now
        base_epoch=$(date "+%s")
      else
        # Extend from current expiry using portable iso_to_epoch
        base_epoch=$(iso_to_epoch "$current_expires")
        # If expired, extend from now instead
        local now_epoch=$(date "+%s")
        if [ "$base_epoch" -lt "$now_epoch" ]; then
          base_epoch="$now_epoch"
        fi
      fi

      local new_expires_epoch=$((base_epoch + extend_seconds))
      local new_expires=$(date -u -r "$new_expires_epoch" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || \
                          date -u -d "@$new_expires_epoch" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null)

      set_state '.autonomous.expires_at' "\"$new_expires\""
      add_history "Autonomous mode extended by $(format_duration $extend_seconds)"

      local remaining=$(get_remaining_seconds)
      log_success "Timeout extended by $(format_duration $extend_seconds)"
      echo "New expiry: $new_expires"
      echo "Remaining:  $(format_duration $remaining)"
      ;;
    status)
      local enabled=$(get_state '.autonomous.enabled // false')
      local enabled_at=$(get_state '.autonomous.enabled_at // "never"')
      local enabled_by=$(get_state '.autonomous.enabled_by // "n/a"')
      local expires_at=$(get_state '.autonomous.expires_at // null')
      local auto_approved=$(get_state '.autonomous.auto_approved // []')

      log_phase "AUTONOMOUS MODE STATUS"

      # Check if expired (this will auto-disable if expired)
      if [ "$enabled" == "true" ]; then
        is_autonomous_enabled > /dev/null  # Trigger expiry check
        enabled=$(get_state '.autonomous.enabled // false')  # Re-read after check
      fi

      if [ "$enabled" == "true" ]; then
        echo -e "Status:       ${GREEN}ENABLED${NC}"
      else
        echo -e "Status:       ${YELLOW}DISABLED${NC}"
      fi
      echo "Enabled At:   $enabled_at"
      echo "Enabled By:   $enabled_by"

      # Show timeout info
      if [ "$enabled" == "true" ]; then
        if [ "$expires_at" != "null" ] && [ -n "$expires_at" ]; then
          local remaining=$(get_remaining_seconds)
          if [ "$remaining" -gt 0 ]; then
            echo -e "Timeout:      $(format_duration $remaining) remaining"
            echo "Expires:      $expires_at"
          else
            echo -e "Timeout:      ${RED}EXPIRED${NC}"
          fi
        else
          echo "Timeout:      unlimited"
        fi
      fi
      echo ""

      echo "Auto-approved checkpoints this session:"
      if [ "$auto_approved" == "[]" ] || [ "$auto_approved" == "null" ]; then
        echo "  (none)"
      else
        echo "$auto_approved" | jq -r '.[]' | while read -r item; do
          echo "  - $item"
        done
      fi
      echo ""

      echo "Checkpoint approval rules:"
      local workflow_type=$(get_state '.type // "feature"')
      if [ "$workflow_type" == "bugfix" ]; then
        echo "  Triage:      ALWAYS requires human approval"
      else
        echo "  Research:    ALWAYS requires human approval"
      fi
      if [ "$enabled" == "true" ]; then
        echo "  Plan:        Will be auto-approved"
        echo "  Review:      Will be auto-approved"
        echo "  Integration: Will be auto-approved"
      else
        echo "  Plan:        Requires human approval"
        echo "  Review:      Requires human approval"
        echo "  Integration: Requires human approval"
      fi
      ;;
    *)
      log_error "Unknown autonomous action: $action"
      echo "Usage: ./orchestrate.sh autonomous <enable|disable|extend|status> [duration]"
      echo ""
      echo "Commands:"
      echo "  enable [timeout]   Enable autonomous mode (optional timeout: 4h, 2h30m, 8h)"
      echo "  disable            Disable autonomous mode"
      echo "  extend <duration>  Extend timeout (e.g., 2h, 30m)"
      echo "  status             Show current status"
      return 1
      ;;
  esac
}

# ============================================================================
# CLAUDE-CODEX AUTO ORCHESTRATION FUNCTIONS
# ============================================================================

# Check if Codex dispatch is currently running
codex_is_running() {
  local pid_file="$SCRIPT_DIR/codex-dispatch.pid"
  if [ -f "$pid_file" ]; then
    local pid=$(cat "$pid_file")
    if ps -p "$pid" > /dev/null 2>&1; then
      return 0
    fi
  fi
  return 1
}

# Check if Codex had failures (parse log file)
codex_has_failures() {
  if [ -f "$CODEX_LOG_FILE" ]; then
    grep -q "FAILED:" "$CODEX_LOG_FILE" 2>/dev/null
    return $?
  fi
  return 1
}

# Get list of failed tasks from log
get_failed_tasks() {
  if [ -f "$CODEX_LOG_FILE" ]; then
    grep "FAILED:" "$CODEX_LOG_FILE" 2>/dev/null | sed 's/.*FAILED: //' | tr -d '[:space:]'
  fi
}

# Create retry task with error context
create_retry_task() {
  local task_name="$1"
  local original_task="$CODEX_TASKS_DIR/${task_name}.md"

  if [ ! -f "$original_task" ]; then
    log_warn "Original task file not found: $original_task"
    return 1
  fi

  local retry_task="$CODEX_TASKS_DIR/${task_name}-retry.md"

  # Extract relevant error from log
  local error_context=$(grep -A 5 "FAILED: $task_name" "$CODEX_LOG_FILE" 2>/dev/null | head -10)

  cat > "$retry_task" << EOF
# RETRY: $task_name

## Previous Error
\`\`\`
$error_context
\`\`\`

## Instructions
This is a retry attempt. The previous execution failed with the error above.
Please:
1. Analyze the error
2. Fix the issue
3. Complete the original task

## Original Task
$(cat "$original_task")
EOF

  log_info "Created retry task: $retry_task"
}

# Retry failed Codex tasks
codex_retry_failed() {
  local retry_count=$(get_state '.phases.execution.codex.retry_count // 0')
  local max_retries=2

  if [ "$retry_count" -ge "$max_retries" ]; then
    log_error "Max retries ($max_retries) reached. Human intervention required."
    echo ""
    echo "Failed tasks need manual attention:"
    get_failed_tasks | while read -r task; do
      echo "  - $task"
    done
    echo ""
    echo "Review the log: $CODEX_LOG_FILE"
    add_history "Codex max retries reached - human intervention required"
    return 1
  fi

  log_phase "RETRYING FAILED CODEX TASKS (attempt $((retry_count + 1))/$max_retries)"

  # Get failed tasks
  local failures=$(get_failed_tasks)
  local failure_count=$(echo "$failures" | grep -c . || echo "0")

  if [ "$failure_count" -eq 0 ]; then
    log_info "No failed tasks to retry"
    return 0
  fi

  log_info "Found $failure_count failed task(s) to retry"

  # Create retry tasks
  echo "$failures" | while read -r task; do
    if [ -n "$task" ]; then
      create_retry_task "$task"
    fi
  done

  # Increment retry count
  set_state '.phases.execution.codex.retry_count' "$((retry_count + 1))"
  add_history "Retrying $failure_count failed Codex task(s) (attempt $((retry_count + 1)))"

  # Re-dispatch Codex in background
  log_info "Re-dispatching Codex..."
  "$SCRIPT_DIR/dispatch-codex.sh" --background --retry

  log_success "Codex retry dispatched"
  echo "Monitor with: ./orchestrate.sh codex-status"
}

# Finalize Codex work (commit and mark complete)
claude_codex_finalize() {
  log_phase "FINALIZING CODEX WORK"

  cd "$PROJECT_ROOT"

  # Check if there are changes to commit
  if git diff --quiet && git diff --staged --quiet; then
    log_info "No changes to commit - Codex may not have made changes"
  else
    # Commit all Codex changes
    log_info "Committing Codex changes..."
    codex_commit "feat: automated codex changes"
  fi

  # Mark Codex complete
  codex_complete

  log_success "Codex work finalized"
  echo ""
  echo "Claude can proceed with integration tasks."

  # If autonomous mode is on, auto-approve review if needed
  local phase=$(get_state '.phase')
  if [ "$phase" == "reviewer" ] && is_autonomous_enabled; then
    log_info "Autonomous mode: proceeding to review phase..."
  fi
}

# Main claude-codex-auto command
claude_codex_auto() {
  local mode="${1:-launch}"

  case "$mode" in
    launch|"")
      log_phase "CLAUDE-CODEX AUTO ORCHESTRATION"

      # Check if already running
      if codex_is_running; then
        log_warn "Codex is already running"
        echo "Check status: ./orchestrate.sh codex-status"
        return 0
      fi

      # Check for pending tasks
      local pending_tasks=$(find "$CODEX_TASKS_DIR" -maxdepth 1 -name "task-*.md" 2>/dev/null | wc -l | tr -d ' ')
      if [ "$pending_tasks" -eq 0 ]; then
        log_warn "No Codex tasks found in $CODEX_TASKS_DIR"
        return 0
      fi

      # Reset retry count for fresh run
      set_state '.phases.execution.codex.retry_count' '0'

      # Launch Codex in background
      "$SCRIPT_DIR/dispatch-codex.sh" --background

      log_success "Codex launched in background ($pending_tasks tasks)"
      echo ""
      echo "Claude can continue working on [CLAUDE] tasks."
      echo ""
      echo "Commands:"
      echo "  Check progress:  ./orchestrate.sh claude-codex-auto --check"
      echo "  View status:     ./orchestrate.sh codex-status"
      echo "  View log:        tail -f .agents/codex-dispatch.log"

      add_history "Claude-Codex auto: launched $pending_tasks task(s) in background"
      ;;
    --wait)
      log_phase "CLAUDE-CODEX AUTO (BLOCKING MODE)"

      # Reset retry count
      set_state '.phases.execution.codex.retry_count' '0'

      # Run Codex synchronously
      "$SCRIPT_DIR/dispatch-codex.sh"

      # Check for failures and retry if needed
      if codex_has_failures; then
        log_warn "Some Codex tasks failed. Attempting retry..."
        codex_retry_failed
        # Wait for retry
        "$SCRIPT_DIR/dispatch-codex.sh" --status
      fi

      # Finalize
      claude_codex_finalize
      ;;
    --check)
      log_phase "CLAUDE-CODEX AUTO CHECK"

      if codex_is_running; then
        echo "Codex is still running."
        echo ""
        "$SCRIPT_DIR/dispatch-codex.sh" --status
        echo ""
        echo "Claude can continue working. Check again later."
        return 0
      fi

      echo "Codex has completed."
      echo ""

      if codex_has_failures; then
        local retry_count=$(get_state '.phases.execution.codex.retry_count // 0')
        local max_retries=2

        if [ "$retry_count" -lt "$max_retries" ]; then
          log_warn "Codex had failures. Initiating retry..."
          codex_retry_failed
        else
          log_error "Codex failed after max retries. Human intervention required."
          echo ""
          echo "Review failed tasks:"
          get_failed_tasks
          echo ""
          echo "Log file: $CODEX_LOG_FILE"
        fi
      else
        log_success "Codex completed successfully!"
        echo ""
        claude_codex_finalize
      fi
      ;;
    --status)
      # Alias for codex-status
      codex_status
      ;;
    *)
      log_error "Unknown mode: $mode"
      echo "Usage: ./orchestrate.sh claude-codex-auto [--wait|--check|--status]"
      return 1
      ;;
  esac
}

# Show status
show_status() {
  log_phase "ORCHESTRATION STATUS"
  
  local feature=$(get_state '.feature')
  local phase=$(get_state '.phase')
  local main_branch=$(get_state '.branch.main')
  local codex_branch=$(get_state '.branch.codex')
  
  echo "Feature:      ${feature:-"(none)"}"
  echo "Phase:        $phase"
  echo "Main Branch:  ${main_branch:-"(none)"}"
  echo "Codex Branch: ${codex_branch:-"(none)"}"
  echo ""
  
  echo "Checkpoints:"
  echo "  Research Approved:   $(get_state '.checkpoints.research_approved')"
  echo "  Plan Approved:       $(get_state '.checkpoints.plan_approved')"
  echo "  Execution Complete:  $(get_state '.checkpoints.execution_complete')"
  echo "  Review Approved:     $(get_state '.checkpoints.review_approved')"
  echo "  Integration Complete: $(get_state '.checkpoints.integration_complete')"
  echo ""
  
  echo "Phase Status:"
  echo "  Research:   $(get_state '.phases.research.status') (approved: $(get_state '.phases.research.approved'))"
  echo "  Architect:  $(get_state '.phases.architect.status')"
  echo "  Planner:    $(get_state '.phases.planner.status') (approved: $(get_state '.phases.planner.approved'))"
  echo "  Execution:"
  echo "    Claude:   $(get_state '.phases.execution.claude.status')"
  echo "    Codex:    $(get_state '.phases.execution.codex.status') ($(get_state '.phases.execution.codex.tasks_completed')/$(get_state '.phases.execution.codex.tasks_total') tasks)"
  echo "  Reviewer:   $(get_state '.phases.reviewer.status') (approved: $(get_state '.phases.reviewer.approved'))"
  echo "  Integrator: $(get_state '.phases.integrator.status')"
  echo ""

  # Show autonomous mode status
  local autonomous_enabled=$(get_state '.autonomous.enabled // false')
  if [ "$autonomous_enabled" == "true" ]; then
    echo -e "Autonomous Mode: ${GREEN}ENABLED${NC} (checkpoints auto-approved except research)"
  else
    echo "Autonomous Mode: DISABLED"
  fi

  # Show model hint
  local model_hint=$(get_state '.model_hint.recommended_model // "sonnet"')
  local model_phase=$(get_state '.model_hint.phase // "unknown"')
  echo ""
  echo -e "Model Hint: ${CYAN}$model_hint${NC} (for phase: $model_phase)"
  echo "  Claude should use this model for subagents in current phase"

  # Show next command hint
  show_next_command "feature"
}

# Start new feature
start_feature() {
  local feature_name="$1"

  if [ -z "$feature_name" ]; then
    log_error "Usage: ./orchestrate.sh start <feature-name>"
    exit 1
  fi

  # Run pre-flight checks
  if ! quick_preflight; then
    exit 1
  fi
  
  # Normalize feature name (kebab-case)
  local normalized=$(echo "$feature_name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
  local branch_name="feature/$normalized"
  local codex_branch="codex/$normalized"
  
  log_phase "STARTING NEW FEATURE: $normalized"

  # Initialize state - START WITH RESEARCH PHASE
  set_state '.feature' "\"$normalized\""
  set_state '.branch.main' "\"$branch_name\""
  set_state '.branch.codex' "\"$codex_branch\""
  set_state '.phase' '"research"'
  set_state '.phases.research.status' '"in_progress"'
  add_history "Started feature: $normalized (research phase)"

  # Set model hint for research phase
  update_model_hint "research"
  
  log_success "Feature initialized!"
  echo ""
  echo "Next steps:"
  echo "  1. Run Claude Code in this project"
  echo "  2. Claude will read .agents/prompts/researcher.md"
  echo "  3. Research output goes to .agents/outputs/research.md"
  echo "  4. Then run './orchestrate.sh resume' to continue"
  echo ""
  log_decision "You will decide GO/NO-GO after research phase"
}

# Dispatch Codex tasks
dispatch_codex() {
  local auto_mode=false
  if [[ "$1" == "--auto" ]]; then
    auto_mode=true
  fi

  log_phase "DISPATCHING CODEX TASKS"

  local codex_branch=$(get_state '.branch.codex')
  if [ -z "$codex_branch" ] || [ "$codex_branch" == "null" ]; then
    log_error "No Codex branch configured"
    exit 1
  fi

  # Check for pending tasks (exclude TEMPLATE.md)
  local pending_tasks=$(find "$CODEX_TASKS_DIR" -maxdepth 1 -name "task-*.md" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$pending_tasks" -eq 0 ]; then
    log_warn "No Codex tasks found in $CODEX_TASKS_DIR"
    exit 0
  fi

  log_info "Found $pending_tasks Codex task(s)"

  # Create Codex branch from main feature branch
  cd "$PROJECT_ROOT"
  local main_branch=$(get_state '.branch.main')
  git checkout "$main_branch"
  git checkout -b "$codex_branch" 2>/dev/null || git checkout "$codex_branch"

  # Update state
  set_state '.phases.execution.codex.status' '"running"'
  set_state '.phases.execution.codex.tasks_total' "$pending_tasks"

  if [ "$auto_mode" = true ]; then
    # Auto-execute mode: run all tasks in parallel
    log_info "Auto-execute mode: running all tasks in parallel..."
    local pids=()

    for task_file in "$CODEX_TASKS_DIR"/task-*.md; do
      local task_name=$(basename "$task_file" .md)
      log_info "Starting: $task_name"

      # Run Codex in background and capture PID
      (cd "$PROJECT_ROOT" && codex exec --full-auto < "$task_file") &
      pids+=($!)
    done

    # Wait for all tasks to complete
    log_info "Waiting for ${#pids[@]} Codex task(s) to complete..."
    local failed=0
    for pid in "${pids[@]}"; do
      if ! wait $pid; then
        ((failed++))
      fi
    done

    if [ $failed -gt 0 ]; then
      log_warn "$failed task(s) failed"
    else
      log_success "All Codex tasks completed successfully!"
    fi

    add_history "Auto-executed $pending_tasks Codex task(s) ($failed failed)"
  else
    # Manual mode: print commands
    for task_file in "$CODEX_TASKS_DIR"/task-*.md; do
      local task_name=$(basename "$task_file" .md)
      log_info "Dispatching: $task_name"

      echo ""
      echo "Run this command in a separate terminal:"
      echo ""
      echo "  cd $PROJECT_ROOT && codex exec --full-auto < $task_file"
      echo ""
    done

    add_history "Dispatched $pending_tasks Codex task(s)"

    log_success "Codex tasks dispatched!"
    echo ""
    echo "After Codex completes:"
    echo "  1. Commit changes with './orchestrate.sh codex-commit'"
    echo "  2. Run './orchestrate.sh codex-complete'"
    echo ""
    echo "Or use --auto flag to run tasks automatically:"
    echo "  ./orchestrate.sh codex-dispatch --auto"
  fi
}

# Mark Codex complete
codex_complete() {
  log_info "Marking Codex execution as complete"

  local total=$(get_state '.phases.execution.codex.tasks_total')
  local workflow_type=$(get_state '.type // "feature"')

  set_state '.phases.execution.codex.status' '"complete"'
  set_state '.phases.execution.codex.tasks_completed' "$total"
  add_history "Codex execution completed"

  # Check if Claude is also complete
  local claude_status=$(get_state '.phases.execution.claude.status')
  if [ "$claude_status" == "complete" ]; then
    set_state '.phases.execution.status' '"complete"'
    set_state '.checkpoints.execution_complete' 'true'

    if [ "$workflow_type" == "bugfix" ]; then
      # Bug-fix: move to verify phase
      start_verify_phase
    else
      # Feature: move to reviewer phase
      set_state '.phase' '"reviewer"'
      update_model_hint "reviewer"
      log_success "All execution complete! Moving to REVIEWER phase."
    fi
  else
    log_info "Waiting for Claude execution to complete"
  fi
}

# Commit Codex changes (handles sandbox git restrictions)
codex_commit() {
  local message="${1:-refactor: apply Codex task changes}"

  log_phase "COMMITTING CODEX CHANGES"

  cd "$PROJECT_ROOT"

  # Check if there are changes to commit
  if git diff --quiet && git diff --staged --quiet; then
    log_warn "No changes to commit"
    exit 0
  fi

  # Stage all changes
  git add -A

  # Show what will be committed
  log_info "Changes to commit:"
  git status --short

  # Create commit with Codex attribution
  git commit -m "$(cat <<EOF
$message

Co-Authored-By: Codex <noreply@openai.com>
EOF
  )"

  local commit_hash=$(git rev-parse --short HEAD)
  add_history "Codex changes committed: $commit_hash"

  log_success "Codex changes committed: $commit_hash"
  echo ""
  echo "Next steps:"
  echo "  1. Run './orchestrate.sh codex-complete' to mark Codex phase done"
}

# Mark Claude complete
claude_complete() {
  log_info "Marking Claude execution as complete"

  local workflow_type=$(get_state '.type // "feature"')

  set_state '.phases.execution.claude.status' '"complete"'
  add_history "Claude execution completed"

  # Check if Codex is also complete
  local codex_status=$(get_state '.phases.execution.codex.status')
  local codex_total=$(get_state '.phases.execution.codex.tasks_total')

  if [ "$codex_total" -eq 0 ] || [ "$codex_status" == "complete" ]; then
    set_state '.phases.execution.status' '"complete"'
    set_state '.checkpoints.execution_complete' 'true'

    if [ "$workflow_type" == "bugfix" ]; then
      # Bug-fix: move to verify phase
      start_verify_phase
    else
      # Feature: move to reviewer phase
      set_state '.phase' '"reviewer"'
      update_model_hint "reviewer"
      log_success "All execution complete! Moving to REVIEWER phase."
    fi
  else
    log_info "Waiting for Codex execution to complete"
    log_info "You can dispatch Codex tasks now: ./orchestrate.sh codex-dispatch"
  fi
}

# Check Codex status (for monitoring background tasks)
codex_status() {
  log_phase "CODEX TASK STATUS"

  local codex_state=$(get_state '.phases.execution.codex.status')
  local codex_total=$(get_state '.phases.execution.codex.tasks_total')
  local codex_completed=$(get_state '.phases.execution.codex.tasks_completed')

  echo "State:     $codex_state"
  echo "Progress:  $codex_completed / $codex_total tasks"
  echo ""

  # Check for running Codex processes
  local running_procs=$(pgrep -f "codex exec" 2>/dev/null | wc -l | tr -d ' ')
  if [ "$running_procs" -gt 0 ]; then
    echo -e "${GREEN}Running Codex processes: $running_procs${NC}"
    echo ""
    echo "Process details:"
    ps aux | grep "[c]odex exec" | head -5
  else
    if [ "$codex_state" == "running" ]; then
      echo -e "${YELLOW}No running Codex processes detected.${NC}"
      echo "Codex may have completed. Check git diff for changes."
      echo ""
      echo "If complete, run: ./orchestrate.sh codex-complete"
    else
      echo "No Codex processes running."
    fi
  fi

  echo ""

  # Show pending task files (exclude archive)
  local pending_tasks=$(find "$CODEX_TASKS_DIR" -maxdepth 1 -name "task-*.md" 2>/dev/null)
  if [ -n "$pending_tasks" ]; then
    echo "Task files in queue:"
    for task in $pending_tasks; do
      echo "  - $(basename "$task")"
    done
  else
    echo "No task files in queue (all dispatched or none created)"
  fi

  # Check git status for Codex changes
  echo ""
  echo "Git status (Codex changes):"
  cd "$PROJECT_ROOT"
  local changes=$(git status --short 2>/dev/null | wc -l | tr -d ' ')
  if [ "$changes" -gt 0 ]; then
    git status --short | head -10
    if [ "$changes" -gt 10 ]; then
      echo "  ... and $((changes - 10)) more files"
    fi
  else
    echo "  No uncommitted changes"
  fi
}

# Approve checkpoint
approve_checkpoint() {
  local checkpoint="$1"
  local auto_mode=false
  local workflow_type=$(get_state '.type // "feature"')

  # Check if this should be auto-approved (autonomous mode)
  if check_autonomous_approval "$checkpoint"; then
    auto_mode=true
  fi

  case "$checkpoint" in
    triage)
      if [ "$workflow_type" != "bugfix" ]; then
        log_error "Triage checkpoint only available in bug-fix workflow"
        exit 1
      fi
      approve_triage
      return
      ;;
    research)
      local feature=$(get_state '.feature')
      local branch_name=$(get_state '.branch.main')
      
      set_state '.phases.research.approved' 'true'
      set_state '.checkpoints.research_approved' 'true'
      set_state '.phase' '"architect"'
      set_state '.phases.architect.status' '"in_progress"'
      add_history "Research approved - proceeding to build"

      # Set model hint for architect phase (OPUS for architecture decisions)
      update_model_hint "architect"

      # Now create the feature branch (only after research approval)
      log_info "Creating branch: $branch_name"
      cd "$PROJECT_ROOT"
      git checkout -b "$branch_name" 2>/dev/null || git checkout "$branch_name"

      log_success "Research approved! GO decision confirmed."
      echo ""
      echo "Next steps:"
      echo "  1. Claude reads .agents/prompts/architect.md"
      echo "  2. Create architecture in .agents/outputs/architecture.md"
      echo "  3. Then run './orchestrate.sh next'"
      ;;
    plan)
      # Check workflow type and route accordingly
      if [ "$workflow_type" == "bugfix" ]; then
        approve_bugfix_plan
        return
      fi

      # Feature workflow: Validate Codex tasks exist before approving
      local feature=$(get_state '.feature')
      local codex_task_count=$(find "$CODEX_TASKS_DIR" -maxdepth 1 -name "task-*.md" 2>/dev/null | wc -l | tr -d ' ')

      if [ "$codex_task_count" -eq 0 ]; then
        log_warn "⚠️  NO CODEX TASK FILES FOUND in .agents/codex-tasks/"
        echo ""
        echo "The PLANNER phase should have created Codex task files."
        echo "Either:"
        echo "  a) This feature has NO parallel tasks (all CLAUDE) - proceed anyway? (y/N)"
        echo "  b) PLANNER forgot to create them - run PLANNER again"
        echo ""
        read -r confirm
        if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
          log_info "Cancelled. Please ensure PLANNER creates Codex task files."
          log_info "Codex tasks should be in: .agents/codex-tasks/task-X.X-<name>.md"
          exit 1
        fi
        log_warn "Proceeding without Codex tasks (Claude-only execution)"
      else
        log_success "Found $codex_task_count Codex task file(s)"
        # Update Codex task count in state
        set_state '.phases.execution.codex.tasks_total' "$codex_task_count"
      fi

      set_state '.phases.planner.approved' 'true'
      set_state '.checkpoints.plan_approved' 'true'
      set_state '.phase' '"execution"'
      set_state '.phases.execution.status' '"in_progress"'
      set_state '.phases.execution.claude.status' '"in_progress"'
      add_history "Plan approved - starting execution"

      # Set model hint for execution phase
      update_model_hint "execution"

      log_success "Plan approved! Execution phase started."
      echo ""
      echo "Next steps:"
      echo "  1. Claude: Follow the plan in docs/plans/active/"
      if [ "$codex_task_count" -gt 0 ]; then
        echo "  2. Codex: Run './orchestrate.sh codex-dispatch' (when Claude hits HARD STOP)"
        echo ""
        echo "⚠️  IMPORTANT: Claude must WAIT for Codex dispatch before continuing past HARD STOPs!"
      else
        echo "  (No Codex tasks - Claude-only execution)"
      fi
      ;;
    review)
      set_state '.phases.reviewer.approved' 'true'
      set_state '.checkpoints.review_approved' 'true'
      set_state '.phase' '"integrator"'
      set_state '.phases.integrator.status' '"in_progress"'
      add_history "Review approved - starting integration"

      # Set model hint for integrator phase
      update_model_hint "integrator"

      log_success "Review approved! Integration phase started."
      echo ""
      echo "Next steps:"
      echo "  1. Merge Codex branch into main feature branch"
      echo "  2. Update Notion (Development Phases + Changelog)"
      echo "  3. Run './orchestrate.sh complete'"
      ;;
    *)
      log_error "Unknown checkpoint: $checkpoint"
      echo "Valid checkpoints: research, plan, review"
      exit 1
      ;;
  esac
}

# Reject research (NO-GO decision)
reject_research() {
  local feature=$(get_state '.feature')
  
  log_phase "REJECTING FEATURE: $feature"
  
  log_warn "This will mark the feature as NO-GO and reset state. Continue? (y/N)"
  read -r confirm
  if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    log_info "Cancelled"
    exit 0
  fi
  
  add_history "Research rejected - NO-GO decision for $feature"
  
  # Archive research output if exists
  if [ -f "$OUTPUTS_DIR/research.md" ]; then
    local archive_dir="$PROJECT_ROOT/docs/research-archive"
    mkdir -p "$archive_dir"
    local timestamp=$(date +"%Y%m%d")
    mv "$OUTPUTS_DIR/research.md" "$archive_dir/${feature}-${timestamp}-rejected.md"
    log_info "Research archived to docs/research-archive/"
  fi
  
  # Reset state
  reset_state_silent
  
  log_decision "Feature '$feature' marked as NO-GO"
  echo ""
  echo "Research has been archived for future reference."
  echo "Ready to start a new feature with: ./orchestrate.sh start <feature-name>"
}

# Silent reset (no confirmation)
reset_state_silent() {
  cat > "$STATE_FILE" << 'EOF'
{
  "type": "feature",
  "feature": null,
  "bug": {
    "title": null,
    "issue_number": null,
    "issue_url": null,
    "severity": null,
    "branch": null
  },
  "branch": {
    "main": null,
    "codex": null
  },
  "phase": "idle",
  "phases": {
    "triage": { "status": "pending", "output": null, "approved": false },
    "research": { "status": "pending", "output": null, "approved": false },
    "architect": { "status": "pending", "output": null },
    "planner": { "status": "pending", "output": null, "approved": false },
    "plan": { "status": "pending", "output": null, "approved": false },
    "execution": {
      "status": "pending",
      "claude": { "status": "pending", "current_task": null },
      "codex": { "status": "pending", "tasks_completed": 0, "tasks_total": 0, "retry_count": 0 }
    },
    "fix": { "status": "pending" },
    "verify": { "status": "pending", "output": null },
    "reviewer": { "status": "pending", "output": null, "approved": false },
    "integrator": { "status": "pending", "notion_updated": false, "merged": false }
  },
  "autonomous": {
    "enabled": false,
    "enabled_at": null,
    "enabled_by": null,
    "timeout_hours": null,
    "expires_at": null,
    "auto_approved": []
  },
  "model_hint": {
    "phase": null,
    "complexity": "medium",
    "severity": null,
    "recommended_model": "sonnet",
    "updated_at": null
  },
  "tasks": {},
  "checkpoints": {
    "triage_approved": false,
    "research_approved": false,
    "plan_approved": false,
    "execution_complete": false,
    "review_approved": false,
    "integration_complete": false
  },
  "history": []
}
EOF

  rm -f "$CODEX_TASKS_DIR"/task-*.md 2>/dev/null || true
  rm -f "$CODEX_TASKS_DIR"/bugfix-*.md 2>/dev/null || true
  rm -f "$OUTPUTS_DIR"/*.md 2>/dev/null || true
  rm -f "$CODEX_LOG_FILE" 2>/dev/null || true
  rm -f "$CODEX_FAILURES_FILE" 2>/dev/null || true
  rm -f "$SCRIPT_DIR/model-hint.txt" 2>/dev/null || true
}

# Complete integration
complete_integration() {
  log_phase "COMPLETING INTEGRATION"
  
  local feature=$(get_state '.feature')
  local main_branch=$(get_state '.branch.main')
  local codex_branch=$(get_state '.branch.codex')
  
  # Merge Codex branch if it exists
  cd "$PROJECT_ROOT"
  if git show-ref --verify --quiet "refs/heads/$codex_branch"; then
    log_info "Merging $codex_branch into $main_branch"
    git checkout "$main_branch"
    git merge "$codex_branch" -m "Merge Codex work for $feature"
    log_success "Branches merged!"
  fi
  
  set_state '.phases.integrator.status' '"complete"'
  set_state '.phases.integrator.merged' 'true'
  set_state '.checkpoints.integration_complete' 'true'
  set_state '.phase' '"complete"'
  add_history "Integration complete"
  
  log_success "Feature '$feature' completed!"
  echo ""
  echo "Don't forget:"
  echo "  1. Update Notion Development Phases"
  echo "  2. Add Changelog entry"
  echo "  3. PR to main when ready"
}

# Reset state
reset_state() {
  log_warn "This will reset all orchestration state. Continue? (y/N)"
  read -r confirm
  if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    log_info "Cancelled"
    exit 0
  fi
  
  reset_state_silent
  
  log_success "State reset to idle"
}

# Resume workflow
resume_workflow() {
  local phase=$(get_state '.phase')
  local model=$(get_model_for_phase "$phase")

  log_phase "RESUMING WORKFLOW - Phase: $phase"
  echo -e "${YELLOW}Recommended model: $model${NC}"
  echo ""

  case "$phase" in
    idle)
      log_info "No active feature. Start one with: ./orchestrate.sh start <feature-name>"
      ;;
    research)
      log_info "RESEARCH phase in progress"
      echo ""
      echo "Model: Use haiku for quick scans, sonnet for deep research"
      echo ""
      echo "Claude should:"
      echo "  1. Read .agents/prompts/researcher.md"
      echo "  2. Research the feature (web search, analyze codebase, etc.)"
      echo "  3. Output to .agents/outputs/research.md"
      echo ""
      echo "Research covers:"
      echo "  - Problem statement"
      echo "  - Target users & impact"
      echo "  - Existing alternatives"
      echo "  - Technical feasibility"
      echo "  - Build recommendation"
      echo ""
      log_decision "You will review research and decide:"
      echo "  GO:    ./orchestrate.sh approve research"
      echo "  NO-GO: ./orchestrate.sh reject research"
      ;;
    architect)
      log_info "ARCHITECT phase in progress"
      echo ""
      echo "Model: Use OPUS for architecture decisions"
      echo ""
      echo "Claude should:"
      echo "  1. Read .agents/prompts/architect.md"
      echo "  2. Analyze the feature requirements"
      echo "  3. Output to .agents/outputs/architecture.md"
      echo ""
      echo "When done, update state:"
      echo "  ./orchestrate.sh next"
      ;;
    planner)
      log_info "PLANNER phase in progress"
      echo ""
      echo "Model: Use sonnet for planning"
      echo ""
      echo "Claude should:"
      echo "  1. Read .agents/prompts/planner.md"
      echo "  2. Create plan in docs/plans/active/<feature>.md"
      echo "  3. Generate Codex tasks in .agents/codex-tasks/"
      echo ""
      echo "When done, request approval:"
      echo "  [HARD STOP] Review the plan, then: ./orchestrate.sh approve plan"
      ;;
    execution)
      local claude_status=$(get_state '.phases.execution.claude.status')
      local codex_status=$(get_state '.phases.execution.codex.status')
      local codex_total=$(get_state '.phases.execution.codex.tasks_total')

      log_info "EXECUTION phase in progress"
      echo "  Claude: $claude_status"
      echo "  Codex:  $codex_status ($codex_total tasks)"
      echo ""
      echo "Model: Use haiku for simple tasks, sonnet for medium, opus for complex"
      echo ""

      if [ "$claude_status" == "in_progress" ]; then
        echo "Claude: Continue executing tasks in the plan"
        echo ""
        echo "To dispatch Codex in background (Claude can continue working):"
        echo "  ./.agents/dispatch-codex.sh &"
        echo "  # Then check status with: ./orchestrate.sh codex-status"
        echo ""
        echo "When Claude completes: ./orchestrate.sh claude-complete"
      fi

      if [ "$codex_status" == "pending" ] && [ "$codex_total" -gt 0 ]; then
        echo ""
        echo "Codex: $codex_total task(s) ready to dispatch"
        echo "  Manual:     ./orchestrate.sh codex-dispatch"
        echo "  Auto:       ./orchestrate.sh codex-dispatch --auto"
        echo "  Background: ./.agents/dispatch-codex.sh &"
      elif [ "$codex_status" == "running" ]; then
        echo ""
        echo "Codex: Tasks running. Check status: ./orchestrate.sh codex-status"
        echo "When complete: ./orchestrate.sh codex-complete"
      fi
      ;;
    reviewer)
      log_info "REVIEWER phase - awaiting review"
      echo ""
      echo "Model: Use sonnet for thorough review"
      echo ""
      echo "Claude should:"
      echo "  1. Read .agents/prompts/reviewer.md"
      echo "  2. Review ALL changes (Claude + Codex)"
      echo "  3. Output to .agents/outputs/review.md"
      echo ""
      echo "[HARD STOP] Review the findings, then: ./orchestrate.sh approve review"
      ;;
    integrator)
      log_info "INTEGRATOR phase in progress"
      echo ""
      echo "Model: Use sonnet for integration"
      echo ""
      echo "Claude should:"
      echo "  1. Read .agents/prompts/integrator.md"
      echo "  2. Merge branches"
      echo "  3. Update Notion (Development Phases + Changelog)"
      echo ""
      echo "When done: ./orchestrate.sh complete"
      ;;
    complete)
      log_success "Feature complete!"
      echo "Run './orchestrate.sh reset' to start a new feature"
      ;;
    *)
      log_error "Unknown phase: $phase"
      ;;
  esac

  # Show next command hint
  show_next_command "feature"
}

# Move to next phase
next_phase() {
  local phase=$(get_state '.phase')
  
  case "$phase" in
    research)
      log_error "Research phase requires approval decision"
      echo "  GO:    ./orchestrate.sh approve research"
      echo "  NO-GO: ./orchestrate.sh reject research"
      ;;
    architect)
      set_state '.phases.architect.status' '"complete"'
      set_state '.phase' '"planner"'
      set_state '.phases.planner.status' '"in_progress"'
      add_history "Architect phase complete - moving to Planner"

      # Set model hint for planner phase
      update_model_hint "planner"

      log_success "Moving to PLANNER phase"
      ;;
    *)
      log_error "Cannot auto-advance from phase: $phase"
      log_info "Use specific commands for this phase"
      ;;
  esac
}

# Main command router
case "${1:-status}" in
  preflight)
    run_preflight_checks
    ;;
  start)
    start_feature "$2"
    ;;
  bug)
    start_bugfix "$2" "$3"
    ;;
  bug-status)
    show_bugfix_status
    ;;
  bug-resume)
    resume_bugfix
    ;;
  bug-complete)
    complete_bugfix
    ;;
  status)
    # Check workflow type
    workflow_type=$(get_state '.type // "feature"')
    if [ "$workflow_type" == "bugfix" ]; then
      show_bugfix_status
    else
      show_status
    fi
    ;;
  resume)
    # Check workflow type and route accordingly
    workflow_type=$(get_state '.type // "feature"')
    if [ "$workflow_type" == "bugfix" ]; then
      resume_bugfix
    else
      resume_workflow
    fi
    ;;
  next)
    next_phase
    ;;
  approve)
    approve_checkpoint "$2"
    ;;
  reject)
    if [ "$2" == "research" ]; then
      reject_research
    else
      log_error "Can only reject: research"
      exit 1
    fi
    ;;
  autonomous)
    autonomous_mode "$2" "$3"
    ;;
  claude-codex-auto)
    claude_codex_auto "$2"
    ;;
  codex-dispatch)
    dispatch_codex "$2"
    ;;
  codex-commit)
    codex_commit "$2"
    ;;
  codex-complete)
    codex_complete
    ;;
  codex-status)
    codex_status
    ;;
  claude-complete)
    claude_complete
    ;;
  complete)
    complete_integration
    ;;
  reset)
    reset_state
    ;;
  abort)
    abort_workflow
    ;;
  rollback)
    rollback_workflow
    ;;
  budget)
    show_context_budget
    ;;
  model)
    show_model_recommendation "$2" "$3"
    ;;
  *)
    echo "Usage: ./orchestrate.sh <command>"
    echo ""
    echo "FEATURE WORKFLOW:"
    echo "  start <feature>      Start new feature (begins with RESEARCH)"
    echo "  status               Show current state"
    echo "  resume               Resume from checkpoint"
    echo "  next                 Move to next phase (architect only)"
    echo "  approve <type>       Approve checkpoint (research|plan|review)"
    echo "  reject research      Reject feature (NO-GO decision)"
    echo ""
    echo "BUG-FIX WORKFLOW:"
    echo "  bug \"<title>\" [severity]   Start bug-fix (creates GitHub issue)"
    echo "                              Severity: critical, major (default), minor"
    echo "  bug-status           Show bug-fix status"
    echo "  bug-resume           Resume bug-fix workflow"
    echo "  approve triage       Approve triage (root cause identified)"
    echo "  approve plan         Approve fix plan"
    echo "  bug-complete         Complete bug-fix (after PR created)"
    echo ""
    echo "Autonomous mode (overnight unattended work):"
    echo "  autonomous enable [timeout]  Enable auto-approval (e.g., enable 4h, enable 8h)"
    echo "  autonomous disable           Return to manual approval mode"
    echo "  autonomous extend <duration> Add time to timeout (e.g., extend 2h)"
    echo "  autonomous status            Check autonomous mode state"
    echo ""
    echo "Claude-Codex auto-orchestration:"
    echo "  claude-codex-auto           Launch Codex in background, return immediately"
    echo "  claude-codex-auto --wait    Launch Codex and wait for completion"
    echo "  claude-codex-auto --check   Check if complete, finalize if ready"
    echo ""
    echo "Codex manual control:"
    echo "  codex-dispatch       Dispatch Codex tasks (add --auto for auto-execution)"
    echo "  codex-status         Check running Codex tasks and git changes"
    echo "  codex-commit [msg]   Commit all Codex changes with attribution"
    echo "  codex-complete       Mark Codex execution complete"
    echo ""
    echo "Claude control:"
    echo "  claude-complete      Mark Claude execution complete"
    echo "  complete             Complete integration"
    echo ""
    echo "Workflow control:"
    echo "  abort                Soft stop - pause workflow (can resume later)"
    echo "  rollback             Hard reset - discard all changes, delete branches"
    echo "  reset                Reset to idle state"
    echo ""
    echo "Utilities:"
    echo "  preflight            Run pre-flight checks (git, tools, auth)"
    echo "  budget               Show context token budget estimate"
    echo "  model <phase> [complexity]  Get recommended model for phase"
    ;;
esac
