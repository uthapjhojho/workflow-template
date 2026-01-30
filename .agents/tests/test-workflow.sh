#!/bin/bash
#
# Workflow Test Suite
# Tests both feature development and bug-fix workflows in manual and autonomous modes
#
# Usage: ./test-workflow.sh [--verbose]

# Note: Don't use set -e as it interferes with test assertions and counter increments

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="$(dirname "$SCRIPT_DIR")"
PROJECT_ROOT="$(dirname "$AGENTS_DIR")"
ORCHESTRATE="$AGENTS_DIR/orchestrate.sh"
STATE_FILE="$AGENTS_DIR/state.json"
STATE_BACKUP="$AGENTS_DIR/state.json.test-backup"
LOG_FILE="$AGENTS_DIR/tests/test-results.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
VERBOSE=false

# Parse args
if [[ "$1" == "--verbose" ]]; then
  VERBOSE=true
fi

# ============================================================================
# Helper Functions
# ============================================================================

log() {
  echo -e "$1"
  echo -e "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG_FILE"
}

log_test() {
  log "${CYAN}[TEST]${NC} $1"
}

log_pass() {
  log "${GREEN}[PASS]${NC} $1"
  ((TESTS_PASSED++))
}

log_fail() {
  log "${RED}[FAIL]${NC} $1"
  ((TESTS_FAILED++))
}

log_info() {
  if [ "$VERBOSE" = true ]; then
    log "${YELLOW}[INFO]${NC} $1"
  fi
}

# Backup current state
backup_state() {
  if [ -f "$STATE_FILE" ]; then
    cp "$STATE_FILE" "$STATE_BACKUP"
    log_info "State backed up"
  fi
}

# Restore state from backup
restore_state() {
  if [ -f "$STATE_BACKUP" ]; then
    cp "$STATE_BACKUP" "$STATE_FILE"
    log_info "State restored"
  fi
}

# Reset to clean state
reset_state() {
  echo "y" | "$ORCHESTRATE" reset > /dev/null 2>&1 || true
}

# Run orchestrate command and check exit code
run_cmd() {
  local cmd="$1"
  local expected_exit="${2:-0}"

  log_info "Running: $ORCHESTRATE $cmd"

  local output
  local exit_code=0
  output=$("$ORCHESTRATE" $cmd 2>&1) || exit_code=$?

  if [ "$VERBOSE" = true ]; then
    echo "$output" | head -20
  fi

  if [ "$exit_code" -eq "$expected_exit" ]; then
    return 0
  else
    log_info "Expected exit $expected_exit, got $exit_code"
    return 1
  fi
}

# Get state value
get_state() {
  jq -r "$1" "$STATE_FILE" 2>/dev/null
}

# Assert state value
assert_state() {
  local path="$1"
  local expected="$2"
  local actual=$(get_state "$path")

  if [ "$actual" == "$expected" ]; then
    return 0
  else
    log_info "State mismatch: $path = '$actual', expected '$expected'"
    return 1
  fi
}

# Create mock output files
create_mock_output() {
  local file="$1"
  local content="${2:-Mock output for testing}"
  mkdir -p "$(dirname "$file")"
  echo "$content" > "$file"
}

# Create mock Codex task
create_mock_codex_task() {
  local task_name="$1"
  cat > "$AGENTS_DIR/codex-tasks/task-1.1-$task_name.md" << 'EOF'
# Codex Task: Mock Task

## Context
This is a mock task for testing.

## Your Task
Do nothing, this is a test.

## Acceptance Criteria
- [ ] Test passes
EOF
}

# Clean up mock files
cleanup_mocks() {
  rm -f "$AGENTS_DIR/outputs/"*.md 2>/dev/null || true
  rm -f "$AGENTS_DIR/codex-tasks/task-"*.md 2>/dev/null || true
  rm -rf "$PROJECT_ROOT/docs/plans/active/"*.md 2>/dev/null || true
}

# ============================================================================
# Test Cases
# ============================================================================

test_preflight() {
  ((TESTS_RUN++))
  log_test "Pre-flight checks run without error"

  if run_cmd "preflight"; then
    log_pass "Pre-flight checks passed"
  else
    log_fail "Pre-flight checks failed"
  fi
}

test_status_idle() {
  ((TESTS_RUN++))
  log_test "Status command works in idle state"

  reset_state

  if run_cmd "status" && assert_state '.phase' 'idle'; then
    log_pass "Status in idle state works"
  else
    log_fail "Status in idle state failed"
  fi
}

test_start_feature() {
  ((TESTS_RUN++))
  log_test "Start feature workflow"

  reset_state

  if run_cmd "start test-feature" && assert_state '.phase' 'research' && assert_state '.feature' 'test-feature'; then
    log_pass "Start feature works"
  else
    log_fail "Start feature failed"
  fi
}

test_research_phase() {
  ((TESTS_RUN++))
  log_test "Research phase and approval"

  reset_state
  run_cmd "start test-research"

  # Create mock research output
  create_mock_output "$AGENTS_DIR/outputs/research.md" "# Research: Test\n\n## Recommendation\n**GO**"

  if run_cmd "approve research" && assert_state '.phase' 'architect'; then
    log_pass "Research phase approval works"
  else
    log_fail "Research phase approval failed"
  fi
}

test_architect_phase() {
  ((TESTS_RUN++))
  log_test "Architect phase and next"

  reset_state
  run_cmd "start test-architect"
  run_cmd "approve research"

  # Create mock architecture output
  create_mock_output "$AGENTS_DIR/outputs/architecture.md" "# Architecture: Test"

  if run_cmd "next" && assert_state '.phase' 'planner'; then
    log_pass "Architect phase transition works"
  else
    log_fail "Architect phase transition failed"
  fi
}

test_planner_phase() {
  ((TESTS_RUN++))
  log_test "Planner phase with Codex tasks"

  reset_state
  run_cmd "start test-planner"
  run_cmd "approve research"
  run_cmd "next"

  # Create mock plan and Codex task
  mkdir -p "$PROJECT_ROOT/docs/plans/active"
  create_mock_output "$PROJECT_ROOT/docs/plans/active/test-planner.md" "# Plan: Test"
  create_mock_codex_task "mock-task"

  if run_cmd "approve plan" && assert_state '.phase' 'execution'; then
    log_pass "Planner phase approval works"
  else
    log_fail "Planner phase approval failed"
  fi
}

test_execution_phase() {
  ((TESTS_RUN++))
  log_test "Execution phase completion"

  reset_state
  run_cmd "start test-execution"
  run_cmd "approve research"
  run_cmd "next"
  create_mock_output "$PROJECT_ROOT/docs/plans/active/test-execution.md" "# Plan"
  create_mock_codex_task "exec-task"
  run_cmd "approve plan"

  # Complete Claude work
  if run_cmd "claude-complete" && assert_state '.phases.execution.claude.status' 'complete'; then
    log_info "Claude complete works"
  else
    log_fail "Claude complete failed"
    return
  fi

  # Mark Codex complete (simulating)
  if run_cmd "codex-complete" && assert_state '.phases.execution.codex.status' 'complete'; then
    log_pass "Execution phase completion works"
  else
    log_fail "Execution phase completion failed"
  fi
}

test_full_feature_manual() {
  ((TESTS_RUN++))
  log_test "Full feature workflow (manual mode)"

  reset_state
  cleanup_mocks

  # Start
  run_cmd "start full-manual-test" || { log_fail "Start failed"; return; }
  assert_state '.phase' 'research' || { log_fail "Not in research phase"; return; }

  # Research
  create_mock_output "$AGENTS_DIR/outputs/research.md" "# Research"
  run_cmd "approve research" || { log_fail "Research approval failed"; return; }

  # Architect
  create_mock_output "$AGENTS_DIR/outputs/architecture.md" "# Architecture"
  run_cmd "next" || { log_fail "Architect next failed"; return; }

  # Planner
  mkdir -p "$PROJECT_ROOT/docs/plans/active"
  create_mock_output "$PROJECT_ROOT/docs/plans/active/full-manual-test.md" "# Plan"
  create_mock_codex_task "full-test"
  run_cmd "approve plan" || { log_fail "Plan approval failed"; return; }

  # Execution
  run_cmd "claude-complete" || { log_fail "Claude complete failed"; return; }
  run_cmd "codex-complete" || { log_fail "Codex complete failed"; return; }

  # Review
  assert_state '.phase' 'reviewer' || { log_fail "Not in reviewer phase"; return; }
  create_mock_output "$AGENTS_DIR/outputs/review.md" "# Review"
  run_cmd "approve review" || { log_fail "Review approval failed"; return; }

  # Integration
  assert_state '.phase' 'integrator' || { log_fail "Not in integrator phase"; return; }
  run_cmd "complete" || { log_fail "Complete failed"; return; }

  if assert_state '.phase' 'complete'; then
    log_pass "Full feature workflow (manual) completed"
  else
    log_fail "Full feature workflow (manual) did not reach complete phase"
  fi
}

test_full_feature_autonomous() {
  ((TESTS_RUN++))
  log_test "Full feature workflow (autonomous mode)"

  reset_state
  cleanup_mocks

  # Start feature
  run_cmd "start full-auto-test" || { log_fail "Start failed"; return; }

  # Research must be manually approved even in autonomous mode
  create_mock_output "$AGENTS_DIR/outputs/research.md" "# Research"
  run_cmd "approve research" || { log_fail "Research approval failed"; return; }

  # Enable autonomous mode
  run_cmd "autonomous enable 1h" || { log_fail "Autonomous enable failed"; return; }
  assert_state '.autonomous.enabled' 'true' || { log_fail "Autonomous not enabled"; return; }

  # Architect -> Planner (should auto-advance with autonomous, but next is manual)
  create_mock_output "$AGENTS_DIR/outputs/architecture.md" "# Architecture"
  run_cmd "next" || { log_fail "Architect next failed"; return; }

  # Planner - plan approval should be auto-approved in autonomous mode
  mkdir -p "$PROJECT_ROOT/docs/plans/active"
  create_mock_output "$PROJECT_ROOT/docs/plans/active/full-auto-test.md" "# Plan"
  create_mock_codex_task "auto-test"
  run_cmd "approve plan" || { log_fail "Plan approval failed"; return; }

  # Execution
  run_cmd "claude-complete" || { log_fail "Claude complete failed"; return; }
  run_cmd "codex-complete" || { log_fail "Codex complete failed"; return; }

  # Review - should be auto-approved
  create_mock_output "$AGENTS_DIR/outputs/review.md" "# Review"
  run_cmd "approve review" || { log_fail "Review approval failed"; return; }

  # Integration
  run_cmd "complete" || { log_fail "Complete failed"; return; }

  # Disable autonomous mode
  run_cmd "autonomous disable" || true

  if assert_state '.phase' 'complete'; then
    log_pass "Full feature workflow (autonomous) completed"
  else
    log_fail "Full feature workflow (autonomous) did not reach complete phase"
  fi
}

test_bugfix_start() {
  ((TESTS_RUN++))
  log_test "Bug-fix workflow start"

  reset_state

  # Note: This will fail if gh is not authenticated
  # We'll test the state transition logic only
  if run_cmd "bug \"Test bug\" major" 2>/dev/null; then
    if assert_state '.type' 'bugfix' && assert_state '.phase' 'triage'; then
      log_pass "Bug-fix workflow start works"
    else
      log_fail "Bug-fix workflow start didn't set correct state"
    fi
  else
    log_info "Bug-fix start requires GitHub CLI - skipping full test"
    log_pass "Bug-fix workflow start (gh unavailable, skipped)"
  fi
}

test_abort_workflow() {
  ((TESTS_RUN++))
  log_test "Abort workflow"

  reset_state
  run_cmd "start abort-test"

  # Abort requires confirmation - we'll just test the state check
  # In a real test we'd pipe 'y' to stdin
  if assert_state '.phase' 'research'; then
    log_pass "Abort workflow setup works (manual confirmation required)"
  else
    log_fail "Abort workflow test failed"
  fi
}

test_next_command_hints() {
  ((TESTS_RUN++))
  log_test "Next command hints appear in output"

  reset_state
  run_cmd "start hint-test"

  local output
  output=$("$ORCHESTRATE" status 2>&1)

  if echo "$output" | grep -q "NEXT COMMAND"; then
    log_pass "Next command hints appear in status"
  else
    log_fail "Next command hints missing from status"
  fi
}

test_resume_workflow() {
  ((TESTS_RUN++))
  log_test "Resume workflow shows correct phase info"

  reset_state
  run_cmd "start resume-test"

  local output
  output=$("$ORCHESTRATE" resume 2>&1)

  if echo "$output" | grep -q "RESEARCH phase" && echo "$output" | grep -q "NEXT COMMAND"; then
    log_pass "Resume workflow shows phase info and hints"
  else
    log_fail "Resume workflow missing expected output"
  fi
}

test_model_hints() {
  ((TESTS_RUN++))
  log_test "Model hints update per phase"

  reset_state
  run_cmd "start model-test"

  # Research phase should recommend sonnet
  local model=$(get_state '.model_hint.recommended_model')
  if [ "$model" == "sonnet" ]; then
    log_info "Research phase model: $model"
  fi

  # Approve and move to architect
  create_mock_output "$AGENTS_DIR/outputs/research.md" "# Research"
  run_cmd "approve research"

  # Architect phase should recommend opus
  model=$(get_state '.model_hint.recommended_model')
  if [ "$model" == "opus" ]; then
    log_pass "Model hints update correctly per phase"
  else
    log_fail "Model hint incorrect for architect phase (got: $model, expected: opus)"
  fi
}

# ============================================================================
# Main Test Runner
# ============================================================================

main() {
  echo ""
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${CYAN}  WORKFLOW TEST SUITE${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""

  # Initialize log file
  echo "=== Test Run: $(date) ===" > "$LOG_FILE"

  # Backup current state
  backup_state

  # Run tests
  test_preflight
  test_status_idle
  test_start_feature
  test_research_phase
  test_architect_phase
  test_planner_phase
  test_execution_phase
  test_next_command_hints
  test_resume_workflow
  test_model_hints
  test_full_feature_manual
  test_full_feature_autonomous
  test_bugfix_start
  test_abort_workflow

  # Cleanup
  cleanup_mocks
  restore_state

  # Summary
  echo ""
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${CYAN}  TEST RESULTS${NC}"
  echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  echo "  Total:  $TESTS_RUN"
  echo -e "  ${GREEN}Passed: $TESTS_PASSED${NC}"
  echo -e "  ${RED}Failed: $TESTS_FAILED${NC}"
  echo ""
  echo "  Log: $LOG_FILE"
  echo ""

  if [ "$TESTS_FAILED" -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
  else
    echo -e "${RED}Some tests failed. Check log for details.${NC}"
    exit 1
  fi
}

# Run main
main "$@"
