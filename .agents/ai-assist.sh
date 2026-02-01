#!/bin/bash
#
# AI Assist - Multi-provider text generation for workflow tasks
#
# Usage:
#   ./ai-assist.sh <task_type> [options]
#
# Task Types (configured in config.json ai_task_routing):
#   pr_description    - Generate PR description from git diff
#   commit_message    - Generate commit message from staged changes
#   documentation     - Generate docs for a file or directory
#   changelog         - Generate changelog from commits
#   test_generation   - Generate test cases for code
#   research_summary  - Summarize research findings
#   error_explanation - Explain an error message
#   code_review       - Review code changes
#
# Options:
#   --dry-run         Print the prompt without calling API
#   --provider <name> Override the configured provider
#   --output <file>   Write output to file instead of stdout
#   --context <file>  Additional context file to include
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$SCRIPT_DIR/config.json"
OUTPUTS_DIR="$SCRIPT_DIR/outputs"

# Colors
if [ -t 1 ]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  CYAN='\033[0;36m'
  NC='\033[0m'
else
  RED='' GREEN='' YELLOW='' BLUE='' CYAN='' NC=''
fi

log_info() { echo -e "${BLUE}[INFO]${NC} $1" >&2; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1" >&2; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# Parse arguments
TASK_TYPE=""
DRY_RUN=false
PROVIDER_OVERRIDE=""
OUTPUT_FILE=""
CONTEXT_FILE=""
EXTRA_ARGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      ;;
    --provider)
      shift
      PROVIDER_OVERRIDE="$1"
      ;;
    --provider=*)
      PROVIDER_OVERRIDE="${1#*=}"
      ;;
    --output)
      shift
      OUTPUT_FILE="$1"
      ;;
    --output=*)
      OUTPUT_FILE="${1#*=}"
      ;;
    --context)
      shift
      CONTEXT_FILE="$1"
      ;;
    --context=*)
      CONTEXT_FILE="${1#*=}"
      ;;
    -*)
      log_error "Unknown option: $1"
      exit 1
      ;;
    *)
      if [ -z "$TASK_TYPE" ]; then
        TASK_TYPE="$1"
      else
        EXTRA_ARGS+=("$1")
      fi
      ;;
  esac
  shift
done

if [ -z "$TASK_TYPE" ]; then
  echo "Usage: $0 <task_type> [options]"
  echo ""
  echo "Task types: pr_description, commit_message, documentation, changelog,"
  echo "            test_generation, research_summary, error_explanation, code_review"
  echo ""
  echo "Options:"
  echo "  --dry-run          Print prompt without calling API"
  echo "  --provider <name>  Override configured provider"
  echo "  --output <file>    Write to file instead of stdout"
  echo "  --context <file>   Include additional context"
  exit 1
fi

# Read configuration
get_config() {
  jq -r "$1" "$CONFIG_FILE" 2>/dev/null
}

get_provider_config() {
  local provider="$1"
  local key="$2"
  jq -r ".ai_provider.providers.${provider}.${key} // empty" "$CONFIG_FILE" 2>/dev/null
}

# Get provider for this task type
if [ -n "$PROVIDER_OVERRIDE" ]; then
  PROVIDER="$PROVIDER_OVERRIDE"
else
  PROVIDER=$(jq -r ".ai_task_routing.${TASK_TYPE} // empty" "$CONFIG_FILE" 2>/dev/null)
fi

if [ -z "$PROVIDER" ] || [ "$PROVIDER" == "null" ]; then
  log_error "Task type '$TASK_TYPE' is not configured or disabled"
  log_info "Check ai_task_routing in config.json"
  exit 1
fi

# Get provider settings
PROVIDER_NAME=$(get_provider_config "$PROVIDER" "name")
PROVIDER_TYPE=$(get_provider_config "$PROVIDER" "type")
API_BASE=$(get_provider_config "$PROVIDER" "api_base")
MODEL=$(get_provider_config "$PROVIDER" "model")
ENV_KEY=$(get_provider_config "$PROVIDER" "env_key")
MAX_TOKENS=$(get_config '.ai_provider.max_tokens')
TEMPERATURE=$(get_config '.ai_provider.temperature')

if [ -z "$PROVIDER_NAME" ] || [ "$PROVIDER_NAME" == "null" ]; then
  log_error "Unknown provider: $PROVIDER"
  exit 1
fi

log_info "Task: $TASK_TYPE -> Provider: $PROVIDER_NAME ($MODEL)"

# Get API key
API_KEY=""
if command -v doppler &> /dev/null; then
  API_KEY=$(doppler secrets get "$ENV_KEY" --project algo_ranger_bot --config prd --plain 2>/dev/null || true)
fi
if [ -z "$API_KEY" ]; then
  API_KEY="${!ENV_KEY}"
fi

if [ -z "$API_KEY" ] && [ "$DRY_RUN" = false ]; then
  log_error "API key not set. Please set $ENV_KEY environment variable."
  exit 1
fi

# Build prompt based on task type
build_prompt() {
  local task="$1"
  local context=""

  # Add context file if provided
  if [ -n "$CONTEXT_FILE" ] && [ -f "$CONTEXT_FILE" ]; then
    context=$(cat "$CONTEXT_FILE")
  fi

  case "$task" in
    pr_description)
      local base_branch="${EXTRA_ARGS[0]:-main}"
      local diff=$(git diff "$base_branch"...HEAD 2>/dev/null || git diff HEAD~5..HEAD 2>/dev/null || echo "No diff available")
      local commits=$(git log "$base_branch"..HEAD --oneline 2>/dev/null || git log -5 --oneline 2>/dev/null || echo "No commits")
      cat <<EOF
Generate a pull request description for the following changes.

## Commits
$commits

## Diff Summary
$(echo "$diff" | head -200)
$([ $(echo "$diff" | wc -l) -gt 200 ] && echo "... (truncated, $(echo "$diff" | wc -l) total lines)")

${context:+## Additional Context
$context}

## Instructions
Write a PR description with:
1. A clear, concise title (under 70 chars)
2. A "## Summary" section with 2-4 bullet points
3. A "## Changes" section listing key modifications
4. A "## Test Plan" section with testing checklist

Use markdown formatting. Be concise but complete.
EOF
      ;;

    commit_message)
      local diff=$(git diff --cached 2>/dev/null || git diff HEAD~1 2>/dev/null || echo "No staged changes")
      cat <<EOF
Generate a commit message for the following staged changes.

## Staged Diff
$(echo "$diff" | head -150)
$([ $(echo "$diff" | wc -l) -gt 150 ] && echo "... (truncated)")

${context:+## Context
$context}

## Instructions
Write a commit message following conventional commits format:
- First line: type(scope): description (under 72 chars)
- Types: feat, fix, docs, style, refactor, test, chore
- Blank line, then body if needed (wrap at 72 chars)
- Focus on WHY, not just WHAT

Output ONLY the commit message, no explanations.
EOF
      ;;

    documentation)
      local target="${EXTRA_ARGS[0]:-}"
      local content=""
      if [ -n "$target" ] && [ -f "$target" ]; then
        content=$(cat "$target" | head -300)
      elif [ -n "$target" ] && [ -d "$target" ]; then
        content=$(find "$target" -type f -name "*.py" -o -name "*.js" -o -name "*.ts" -o -name "*.go" -o -name "*.sh" | head -10 | xargs head -50 2>/dev/null || echo "Directory listing")
      fi
      cat <<EOF
Generate documentation for the following code.

## Code
$content
$([ -n "$target" ] && [ $(wc -l < "$target" 2>/dev/null || echo 0) -gt 300 ] && echo "... (truncated)")

${context:+## Context
$context}

## Instructions
Generate clear documentation including:
1. Overview - what this code does
2. Key functions/classes with descriptions
3. Usage examples
4. Any important notes or caveats

Use markdown formatting.
EOF
      ;;

    changelog)
      local from_ref="${EXTRA_ARGS[0]:-$(git describe --tags --abbrev=0 2>/dev/null || echo 'HEAD~20')}"
      local to_ref="${EXTRA_ARGS[1]:-HEAD}"
      local commits=$(git log "$from_ref".."$to_ref" --pretty=format:"%h %s" 2>/dev/null || git log -20 --pretty=format:"%h %s")
      cat <<EOF
Generate a changelog from the following commits.

## Commits ($from_ref..$to_ref)
$commits

${context:+## Context
$context}

## Instructions
Generate a changelog with sections:
- **Added** - new features
- **Changed** - changes in existing functionality
- **Fixed** - bug fixes
- **Removed** - removed features (if any)

Group related commits. Use clear, user-facing language.
Omit empty sections. Use markdown formatting.
EOF
      ;;

    test_generation)
      local target="${EXTRA_ARGS[0]:-}"
      local content=""
      if [ -n "$target" ] && [ -f "$target" ]; then
        content=$(cat "$target")
      fi
      cat <<EOF
Generate test cases for the following code.

## Code to Test
$content

${context:+## Context
$context}

## Instructions
Generate comprehensive test cases including:
1. Unit tests for each function/method
2. Edge cases and boundary conditions
3. Error handling tests
4. Integration tests if applicable

Use the appropriate testing framework for the language.
Include setup/teardown if needed.
EOF
      ;;

    research_summary)
      local topic="${EXTRA_ARGS[0]:-}"
      cat <<EOF
Summarize research findings on the following topic.

## Topic
$topic

${context:+## Research Materials
$context}

## Instructions
Provide a structured summary including:
1. Key findings (bullet points)
2. Recommendations
3. Trade-offs or considerations
4. Next steps

Be concise but thorough.
EOF
      ;;

    error_explanation)
      local error="${EXTRA_ARGS[0]:-}"
      if [ -z "$error" ] && [ -n "$CONTEXT_FILE" ]; then
        error=$(cat "$CONTEXT_FILE")
      fi
      cat <<EOF
Explain the following error and suggest fixes.

## Error
$error

${context:+## Code Context
$context}

## Instructions
Provide:
1. What the error means in plain language
2. Common causes
3. Step-by-step fix suggestions
4. How to prevent it in the future

Be clear and actionable.
EOF
      ;;

    code_review)
      local diff=$(git diff HEAD~1 2>/dev/null || git diff 2>/dev/null || echo "No changes")
      if [ -n "${EXTRA_ARGS[0]}" ] && [ -f "${EXTRA_ARGS[0]}" ]; then
        diff=$(cat "${EXTRA_ARGS[0]}")
      fi
      cat <<EOF
Review the following code changes.

## Changes
$diff

${context:+## Context
$context}

## Instructions
Provide a code review covering:
1. **Issues** - bugs, security concerns, logic errors
2. **Improvements** - better approaches, performance
3. **Style** - naming, formatting, clarity
4. **Positive** - what's done well

Be constructive and specific. Reference line numbers where helpful.
EOF
      ;;

    *)
      log_error "Unknown task type: $task"
      exit 1
      ;;
  esac
}

# Build the prompt
PROMPT=$(build_prompt "$TASK_TYPE")

# Dry run mode
if [ "$DRY_RUN" = true ]; then
  echo "=== DRY RUN ==="
  echo "Provider: $PROVIDER_NAME ($MODEL)"
  echo "Task: $TASK_TYPE"
  echo ""
  echo "=== PROMPT ==="
  echo "$PROMPT"
  exit 0
fi

# Call the API based on provider type
call_api() {
  local prompt="$1"
  local escaped_prompt
  escaped_prompt=$(echo "$prompt" | jq -Rs .)

  case "$PROVIDER_TYPE" in
    anthropic)
      # Anthropic API format
      local response
      response=$(curl -s -X POST "${API_BASE}/messages" \
        -H "Content-Type: application/json" \
        -H "x-api-key: $API_KEY" \
        -H "anthropic-version: 2023-06-01" \
        -d "{
          \"model\": \"$MODEL\",
          \"max_tokens\": $MAX_TOKENS,
          \"messages\": [{\"role\": \"user\", \"content\": $escaped_prompt}]
        }")

      # Check for errors
      local error
      error=$(echo "$response" | jq -r '.error.message // empty')
      if [ -n "$error" ]; then
        log_error "API error: $error"
        exit 1
      fi

      # Extract content
      echo "$response" | jq -r '.content[0].text // empty'
      ;;

    api)
      # OpenAI-compatible API format (GLM, DeepSeek, Moonshot)
      local system_prompt="You are a helpful assistant for software development tasks. Be concise, accurate, and follow instructions precisely."
      local escaped_system
      escaped_system=$(echo "$system_prompt" | jq -Rs .)

      local response
      response=$(curl -s -X POST "${API_BASE}/chat/completions" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $API_KEY" \
        -d "{
          \"model\": \"$MODEL\",
          \"messages\": [
            {\"role\": \"system\", \"content\": $escaped_system},
            {\"role\": \"user\", \"content\": $escaped_prompt}
          ],
          \"max_tokens\": $MAX_TOKENS,
          \"temperature\": $TEMPERATURE
        }")

      # Check for errors
      local error
      error=$(echo "$response" | jq -r '.error.message // empty')
      if [ -n "$error" ]; then
        log_error "API error: $error"
        exit 1
      fi

      # Extract content
      echo "$response" | jq -r '.choices[0].message.content // empty'
      ;;

    *)
      log_error "Unsupported provider type: $PROVIDER_TYPE"
      exit 1
      ;;
  esac
}

# Make the API call
log_info "Calling $PROVIDER_NAME API..."
RESULT=$(call_api "$PROMPT")

if [ -z "$RESULT" ]; then
  log_error "Empty response from API"
  exit 1
fi

# Output result
if [ -n "$OUTPUT_FILE" ]; then
  echo "$RESULT" > "$OUTPUT_FILE"
  log_success "Output written to: $OUTPUT_FILE"
else
  echo "$RESULT"
fi

log_success "Task completed: $TASK_TYPE"
