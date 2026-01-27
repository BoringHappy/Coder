#!/bin/bash
set -e

# Source common utilities
source "$(dirname "$0")/shell/common.sh"

# Configuration
CLAUDE_SESSION="claude-code"
MONITOR_INTERVAL="${MONITOR_INTERVAL:-1}"  # Cron interval in minutes (default: 1)
MONITOR_LOG_FILE="${MONITOR_LOG_FILE:-/tmp/pr-monitor.log}"
HEARTBEAT_FILE="${HEARTBEAT_FILE:-/tmp/codemate-heartbeat}"
MONITOR_SCRIPT="$(dirname "$0")/shell/monitor-pr.sh"

printf "${GREEN}Starting CodeMate with tmux...${RESET}\n"

# Function to check if a tmux session exists
session_exists() {
    tmux has-session -t "$1" 2>/dev/null
}

# Function to setup cron for PR monitoring
setup_cron_monitor() {
    printf "${GREEN}Setting up cron for PR monitoring...${RESET}\n"

    # Install cron if not available
    if ! command -v cron &> /dev/null && ! command -v crond &> /dev/null; then
        printf "${YELLOW}Installing cron...${RESET}\n"
        if command -v apt-get &> /dev/null; then
            apt-get update -qq && apt-get install -y -qq cron
        elif command -v apk &> /dev/null; then
            apk add --no-cache dcron
        elif command -v yum &> /dev/null; then
            yum install -y cronie
        fi
    fi

    # Start cron daemon if not running
    if command -v cron &> /dev/null; then
        cron 2>/dev/null || true
    elif command -v crond &> /dev/null; then
        crond 2>/dev/null || true
    fi

    # Create cron job for PR monitor
    local cron_entry="*/${MONITOR_INTERVAL} * * * * REPO_DIR=\"$(pwd)\" LOG_FILE=\"$MONITOR_LOG_FILE\" HEARTBEAT_FILE=\"$HEARTBEAT_FILE\" $MONITOR_SCRIPT >> $MONITOR_LOG_FILE 2>&1"

    # Remove existing cron job if present, then add new one
    (crontab -l 2>/dev/null | grep -v "monitor-pr.sh" || true; echo "$cron_entry") | crontab -

    printf "${GREEN}Cron job installed: runs every ${MONITOR_INTERVAL} minute(s)${RESET}\n"
}

# Function to remove cron monitor
remove_cron_monitor() {
    (crontab -l 2>/dev/null | grep -v "monitor-pr.sh" || true) | crontab -
    printf "${YELLOW}Cron job removed${RESET}\n"
}

# Kill existing Claude session if it exists
if session_exists "$CLAUDE_SESSION"; then
    echo "Killing existing Claude Code session..."
    tmux kill-session -t "$CLAUDE_SESSION"
fi

# Remove any existing cron job before setting up new one
remove_cron_monitor 2>/dev/null || true

# Initialize log file
echo "$(date): === CodeMate session starting ===" >> "$MONITOR_LOG_FILE"

# Start Claude Code in a detached tmux session
printf "${GREEN}Starting Claude Code in tmux session: $CLAUDE_SESSION${RESET}\n"
tmux new-session -d -s "$CLAUDE_SESSION" "claude --dangerously-skip-permissions --append-system-prompt \"\$(cat /usr/local/bin/setup/prompt/system_prompt.txt)\""

# Send initial query if provided
if [ -n "$QUERY" ]; then
    printf "${GREEN}Waiting for Claude to initialize...${RESET}\n"
    sleep 5
    printf "${GREEN}Sending initial query to Claude...${RESET}\n"
    tmux send-keys -t "$CLAUDE_SESSION" "$QUERY"
    tmux send-keys -t "$CLAUDE_SESSION" C-m
else
    sleep 2
fi

# Setup cron-based PR monitoring
setup_cron_monitor

# Display session information
printf "${YELLOW}=== CodeMate Sessions ===${RESET}\n"
echo "Claude Code session: $CLAUDE_SESSION (tmux)"
echo "PR Monitor: cron job (every ${MONITOR_INTERVAL} minute(s))"
echo ""
printf "${YELLOW}=== Log Files ===${RESET}\n"
echo "Monitor log: $MONITOR_LOG_FILE"
echo "Heartbeat: $HEARTBEAT_FILE"
echo "State file: /tmp/pr-monitor-state"
echo ""
printf "${YELLOW}=== Commands ===${RESET}\n"
echo "View monitor log: tail -f $MONITOR_LOG_FILE"
echo "Check heartbeat: cat $HEARTBEAT_FILE"
echo "View cron jobs: crontab -l"
echo "Remove monitor: crontab -l | grep -v monitor-pr.sh | crontab -"
echo "List tmux sessions: tmux ls"
echo "Kill Claude: tmux kill-server"
echo ""
printf "${GREEN}Attaching to Claude Code session...${RESET}\n"
sleep 1

# Attach to Claude Code session
tmux attach -t "$CLAUDE_SESSION"
