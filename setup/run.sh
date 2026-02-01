#!/bin/bash
set -e

# Source common utilities
source "$(dirname "$0")/shell/common.sh"

# Configuration
CLAUDE_SESSION="claude-code"

printf "${GREEN}Starting CodeMate with tmux...${RESET}\n"

# Function to check if a tmux session exists
session_exists() {
    tmux has-session -t "$1" 2>/dev/null
}

# Function to check session status and retry if needed
# Usage: check_and_retry_submit <session_name> <max_attempts>
check_and_retry_submit() {
    local session_name="$1"
    local max_attempts="${2:-3}"
    local attempt=1
    local SESSION_STATUS_FILE="$HOME/.config/claude-code/.session_status"

    while [ $attempt -le $max_attempts ]; do
        sleep 3

        if [ -f "$SESSION_STATUS_FILE" ]; then
            STATUS=$(cat "$SESSION_STATUS_FILE" 2>/dev/null || echo "")
            if [ "$STATUS" = "UserPromptSubmit" ]; then
                printf "${GREEN}Query submitted successfully (attempt $attempt)${RESET}\n"
                return 0
            else
                printf "${YELLOW}Query not submitted (status: $STATUS), attempt $attempt/$max_attempts${RESET}\n"
                if [ $attempt -lt $max_attempts ]; then
                    tmux send-keys -t "$session_name" C-m
                fi
            fi
        else
            printf "${YELLOW}Session status file not found on attempt $attempt${RESET}\n"
        fi

        attempt=$((attempt + 1))
    done

    printf "${YELLOW}Max retry attempts reached, continuing anyway${RESET}\n"
    return 1
}

# Kill existing Claude session if it exists
if session_exists "$CLAUDE_SESSION"; then
    echo "Killing existing Claude Code session..."
    tmux kill-session -t "$CLAUDE_SESSION"
fi

# Start Claude Code in a detached tmux session
printf "${GREEN}Starting Claude Code in tmux session: $CLAUDE_SESSION${RESET}\n"

# Choose system prompt based on workflow type
if [ -n "$UPSTREAM_REPO_URL" ]; then
    # Open-source workflow: use opensource system prompt
    SYSTEM_PROMPT_FILE="/usr/local/bin/setup/prompt/system_prompt_opensource.txt"
    printf "${CYAN}Using open-source workflow system prompt${RESET}\n"
else
    # Standard workflow: use default system prompt
    SYSTEM_PROMPT_FILE="/usr/local/bin/setup/prompt/system_prompt.txt"
    printf "${CYAN}Using standard workflow system prompt${RESET}\n"
fi

tmux new-session -d -s "$CLAUDE_SESSION" "claude --dangerously-skip-permissions --append-system-prompt \"\$(cat $SYSTEM_PROMPT_FILE)\""

# Send initial query if provided
if [ -n "$QUERY" ]; then
    printf "${GREEN}Waiting for Claude to initialize...${RESET}\n"
    sleep 5
    printf "${GREEN}Sending initial query to Claude...${RESET}\n"
    tmux send-keys -t "$CLAUDE_SESSION" "$QUERY"
    tmux send-keys -t "$CLAUDE_SESSION" C-m

    # Check if the query was submitted with retry mechanism
    check_and_retry_submit "$CLAUDE_SESSION" 3
else
    sleep 2
fi

# Display session information
printf "${YELLOW}=== CodeMate Sessions ===${RESET}\n"
echo "Claude Code session: $CLAUDE_SESSION (tmux)"
echo "PR Monitor: cron job (every minute)"
echo ""
printf "${YELLOW}=== Log Files ===${RESET}\n"
echo "Monitor log: /tmp/pr-monitor.log"
echo "State file: /tmp/pr-monitor-state"
echo ""
printf "${YELLOW}=== Commands ===${RESET}\n"
echo "View monitor log: tail -f /tmp/pr-monitor.log"
echo "View cron jobs: crontab -l"
echo "List tmux sessions: tmux ls"
echo "Kill Claude: tmux kill-server"
echo ""
printf "${GREEN}Attaching to Claude Code session...${RESET}\n"
sleep 1

# Attach to Claude Code session
tmux attach -t "$CLAUDE_SESSION"
