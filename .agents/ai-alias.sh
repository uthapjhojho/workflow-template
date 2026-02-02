#!/bin/bash
#
# AI Delegation Alias
# Source this file to get the 'ai' command in your shell
#
# Usage:
#   source .agents/ai-alias.sh
#   ai "fix typo in README"
#

# Get the directory where this script is located
AGENTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Define the ai function
ai() {
  "$AGENTS_DIR/ai-delegate.sh" "$@"
}

# Export so it's available in subshells
export -f ai 2>/dev/null || true

echo "✓ AI delegation command loaded!"
echo ""
echo "Usage:"
echo "  ai \"fix typo in README\""
echo "  ai --complexity complex \"refactor UserService\""
echo "  ai --wait \"generate tests\"   # Wait for result"
