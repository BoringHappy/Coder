#!/bin/bash
set -e

# Configuration
CLAUDE_SESSION="claude-code"
MONITOR_SESSION="pr-monitor"
CHECK_INTERVAL=30  # Check for PR comments every 30 seconds

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Starting CodeMate with tmux...${NC}"

# Function to check if a tmux session exists
session_exists() {
    tmux has-session -t "$1" 2>/dev/null
}

# Function to monitor PR comments
monitor_pr_comments() {
    local last_comment_count=0

    while true; do
        sleep "$CHECK_INTERVAL"

        # Get current PR number if available
        pr_number=$(gh pr view --json number -q .number 2>/dev/null || echo "")

        if [ -z "$pr_number" ]; then
            echo "$(date): No PR found, skipping comment check"
            continue
        fi

        # Get current comment count (reviews + comments)
        current_count=$(gh pr view "$pr_number" --json comments,reviews --jq '(.comments | length) + (.reviews | length)' 2>/dev/null || echo "0")

        if [ "$current_count" -gt "$last_comment_count" ]; then
            echo "$(date): New PR comments detected! ($current_count total)"

            # Send "fix comments" command to Claude Code session
            if session_exists "$CLAUDE_SESSION"; then
                echo "$(date): Sending 'fix comments' to Claude Code session"
                tmux send-keys -t "$CLAUDE_SESSION" "fix comments" C-m
            fi

            last_comment_count="$current_count"
        fi
    done
}

# Kill existing sessions if they exist
if session_exists "$CLAUDE_SESSION"; then
    echo "Killing existing Claude Code session..."
    tmux kill-session -t "$CLAUDE_SESSION"
fi

if session_exists "$MONITOR_SESSION"; then
    echo "Killing existing PR monitor session..."
    tmux kill-session -t "$MONITOR_SESSION"
fi

# Start Claude Code in a detached tmux session
echo -e "${GREEN}Starting Claude Code in tmux session: $CLAUDE_SESSION${NC}"
tmux new-session -d -s "$CLAUDE_SESSION" "claude --dangerously-skip-permissions --append-system-prompt \"\$(cat /usr/local/bin/setup/prompt/system_prompt.txt)\""

# Give Claude a moment to start
sleep 2

# Start PR monitor in a separate tmux session
echo -e "${GREEN}Starting PR comment monitor in tmux session: $MONITOR_SESSION${NC}"
tmux new-session -d -s "$MONITOR_SESSION" "$(declare -f monitor_pr_comments); $(declare -f session_exists); CLAUDE_SESSION='$CLAUDE_SESSION'; CHECK_INTERVAL=$CHECK_INTERVAL; monitor_pr_comments"

# Display session information
echo -e "${YELLOW}=== Tmux Sessions ===${NC}"
echo "Claude Code session: $CLAUDE_SESSION"
echo "PR Monitor session: $MONITOR_SESSION"
echo ""
echo -e "${YELLOW}=== Commands ===${NC}"
echo "Switch to monitor: tmux attach -t $MONITOR_SESSION"
echo "List sessions: tmux ls"
echo "Kill all: tmux kill-server"
echo ""
echo -e "${GREEN}Attaching to Claude Code session...${NC}"
sleep 1

# Attach to Claude Code session
tmux attach -t "$CLAUDE_SESSION"
