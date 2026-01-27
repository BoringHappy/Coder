#!/bin/bash
set -e

# Source common utilities
source "$(dirname "$0")/shell/common.sh"

# Configuration
CLAUDE_SESSION="claude-code"
MONITOR_SESSION="pr-monitor"
CHECK_INTERVAL=30  # Check for PR comments every 30 seconds

printf "${GREEN}Starting CodeMate with tmux...${RESET}\n"

# Function to check if a tmux session exists
session_exists() {
    tmux has-session -t "$1" 2>/dev/null
}

# Function to check if latest session status ends with Stop
is_session_stopped() {
    local status_file="$HOME/.session_status"
    if [ -f "$status_file" ]; then
        # Get the last non-empty line and check if it ends with "Stop"
        local last_line=$(tail -n 10 "$status_file" | grep -v '^$' | tail -n 1)
        if [[ "$last_line" =~ Stop$ ]]; then
            return 0  # true
        else
            return 1  # false
        fi
    else
        return 1  # false if file doesn't exist
    fi
}

# Function to monitor PR comments
monitor_pr_comments() {
    local last_comment_count=0

    while true; do
        sleep "$CHECK_INTERVAL"

        # Check session status - only proceed if last line ends with "Stop"
        if ! is_session_stopped; then
            echo "$(date): Session not stopped, skipping comment check"
            continue
        fi

        # Get current PR number if available
        pr_number=$(gh pr view --json number -q .number 2>/dev/null || echo "")

        if [ -z "$pr_number" ]; then
            echo "$(date): No PR found, skipping comment check"
            continue
        fi

        # Get unsolved comments (top-level review comments without resolution)
        unsolved_count=$(gh api repos/:owner/:repo/pulls/"$pr_number"/comments --jq '[.[] | select(.in_reply_to_id == null)] | length' 2>/dev/null || echo "0")

        if [ "$unsolved_count" -gt 0 ] && [ "$unsolved_count" -gt "$last_comment_count" ]; then
            echo "$(date): Unsolved PR comments detected! ($unsolved_count total)"

            # Send "fix comments" command to Claude Code session
            if session_exists "$CLAUDE_SESSION"; then
                echo "$(date): Sending 'fix comments' to Claude Code session"
                tmux send-keys -t "$CLAUDE_SESSION" "fix comments" C-m
            fi

            last_comment_count="$unsolved_count"
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
printf "${GREEN}Starting Claude Code in tmux session: $CLAUDE_SESSION${RESET}\n"
tmux new-session -d -s "$CLAUDE_SESSION" "claude --dangerously-skip-permissions --append-system-prompt \"\$(cat /usr/local/bin/setup/prompt/system_prompt.txt)\""

# Give Claude a moment to start
sleep 2

# Start PR monitor in a separate tmux session
printf "${GREEN}Starting PR comment monitor in tmux session: $MONITOR_SESSION${RESET}\n"
tmux new-session -d -s "$MONITOR_SESSION" "$(declare -f is_session_stopped); $(declare -f monitor_pr_comments); $(declare -f session_exists); CLAUDE_SESSION='$CLAUDE_SESSION'; CHECK_INTERVAL=$CHECK_INTERVAL; monitor_pr_comments"

# Display session information
printf "${YELLOW}=== Tmux Sessions ===${RESET}\n"
echo "Claude Code session: $CLAUDE_SESSION"
echo "PR Monitor session: $MONITOR_SESSION"
echo ""
printf "${YELLOW}=== Commands ===${RESET}\n"
echo "Switch to monitor: tmux attach -t $MONITOR_SESSION"
echo "List sessions: tmux ls"
echo "Kill all: tmux kill-server"
echo ""
printf "${GREEN}Attaching to Claude Code session...${RESET}\n"
sleep 1

# Attach to Claude Code session
tmux attach -t "$CLAUDE_SESSION"
