#!/bin/bash
# Docker integration script for Claude Code Agent
# This script can be used as an alternative CMD in the Dockerfile

set -e

# Source environment variables if .env exists
if [ -f /workspace/.env ]; then
    export $(cat /workspace/.env | grep -v '^#' | xargs)
fi

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default values
CHECK_INTERVAL=${CHECK_INTERVAL:-60}
RUN_ONCE=${RUN_ONCE:-false}

# Build command
CMD="uv run $SCRIPT_DIR/claude_agent.py"

if [ -n "$ANTHROPIC_API_KEY" ]; then
    CMD="$CMD --api-key $ANTHROPIC_API_KEY"
fi

if [ -n "$GITHUB_REPOSITORY" ]; then
    CMD="$CMD --repo $GITHUB_REPOSITORY"
fi

if [ -n "$PR_NUMBER" ]; then
    CMD="$CMD --pr $PR_NUMBER"
fi

if [ -n "$CHECK_INTERVAL" ]; then
    CMD="$CMD --interval $CHECK_INTERVAL"
fi

if [ -n "$SYSTEM_PROMPT_PATH" ]; then
    CMD="$CMD --system-prompt $SYSTEM_PROMPT_PATH"
fi

if [ "$RUN_ONCE" = "true" ]; then
    CMD="$CMD --once"
fi

echo "Starting Claude Code Agent..."
echo "Command: $CMD"
echo ""

# Execute the command
exec $CMD
