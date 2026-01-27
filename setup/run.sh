#!/bin/bash
set -e

# Source common utilities
source "$(dirname "$0")/shell/common.sh"

# Configuration
CLAUDE_SESSION="claude-code"
CHECK_INTERVAL=30  # Check for PR comments every 30 seconds
MONITOR_LOG_FILE="${MONITOR_LOG_FILE:-/tmp/pr-monitor.log}"
HEARTBEAT_FILE="${HEARTBEAT_FILE:-/tmp/codemate-heartbeat}"
IDLE_TIMEOUT="${IDLE_TIMEOUT:-3600}"  # Default 1 hour idle timeout (in seconds)

printf "${GREEN}Starting CodeMate with tmux...${RESET}\n"

# Function to check if a tmux session exists
session_exists() {
    tmux has-session -t "$1" 2>/dev/null
}

# Function to update heartbeat file (for keep-alive monitoring)
update_heartbeat() {
    local status="${1:-alive}"
    echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ') $status" > "$HEARTBEAT_FILE"
}

# Function to check if we should keep the machine alive
# Returns 0 (true) if there's activity, 1 (false) if idle too long
check_keep_alive() {
    local last_activity_file="/tmp/codemate-last-activity"
    local current_time=$(date +%s)

    # Check for any activity indicators
    local has_activity=false

    # 1. Check if Claude session is busy (not stopped)
    if ! is_session_stopped 2>/dev/null; then
        has_activity=true
    fi

    # 2. Check for unstaged git changes
    if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
        has_activity=true
    fi

    # Update last activity time if there's activity
    if [ "$has_activity" = true ]; then
        echo "$current_time" > "$last_activity_file"
        return 0
    fi

    # Check if we've been idle too long
    if [ -f "$last_activity_file" ]; then
        local last_activity=$(cat "$last_activity_file")
        local idle_time=$((current_time - last_activity))

        if [ "$idle_time" -gt "$IDLE_TIMEOUT" ]; then
            echo "$(date): Idle timeout reached ($idle_time seconds)"
            return 1
        fi
    else
        # First run, initialize activity file
        echo "$current_time" > "$last_activity_file"
    fi

    return 0
}

# Function to check if latest session status ends with Stop
is_session_stopped() {
    local status_file="$HOME/.session_status"
    if [ -f "$status_file" ]; then
        # Get the last non-empty line and check if it ends with "Stop"
        local last_line=$(tail -n 10 "$status_file" | grep -v '^$' | tail -n 1)
        echo "$(date): [Session] status=$last_line"
        if [[ "$last_line" =~ Stop$ ]]; then
            return 0  # true
        else
            return 1  # false
        fi
    else
        echo "$(date): [Session] status_file not found"
        return 1  # false if file doesn't exist
    fi
}

# Function to monitor PR comments and git changes
monitor_pr_comments() {
    local last_comment_count=0
    local last_check_time=""
    local git_changes_notified=false
    local consecutive_failures=0
    local max_failures=5

    # Initialize heartbeat
    update_heartbeat "starting"

    # Wait at least 1 minute before checking PR number to allow session to initialize
    echo "$(date): Waiting 60 seconds before starting monitoring..."
    sleep 60

    # Get PR number once at the start (it won't change during monitoring)
    local pr_number=""
    for attempt in 1 2 3; do
        pr_number=$(gh pr view --json number -q .number 2>/dev/null || echo "")
        if [ -n "$pr_number" ]; then
            break
        fi
        echo "$(date): Attempt $attempt to get PR number failed, retrying..."
        sleep 5
    done

    if [ -z "$pr_number" ]; then
        echo "$(date): No PR found, monitoring disabled"
        update_heartbeat "no-pr"
        return
    fi

    echo "$(date): Monitoring PR #$pr_number for new comments"
    echo "$(date): Monitoring for unstaged git changes"
    update_heartbeat "monitoring"

    while true; do
        sleep "$CHECK_INTERVAL"

        # Update heartbeat on each iteration
        update_heartbeat "alive"

        # Check keep-alive status
        if ! check_keep_alive; then
            echo "$(date): Keep-alive check failed, machine may be terminated"
            update_heartbeat "idle-timeout"
            # Continue monitoring but signal idle state
        fi

        # Check session status - only proceed if last line ends with "Stop"
        if ! is_session_stopped; then
            consecutive_failures=0  # Reset on successful check
            continue
        fi

        # Check for unstaged changes
        local git_changes=$(git status --porcelain 2>/dev/null)
        echo "$(date): [Git] changes=$([ -n "$git_changes" ] && echo 'yes' || echo 'no'), notified=$git_changes_notified"

        if [ -n "$git_changes" ]; then
            if [ "$git_changes_notified" = false ]; then
                echo "$(date): Unstaged changes detected!"

                # Send commit prompt to Claude Code session
                if session_exists "$CLAUDE_SESSION"; then
                    echo "$(date): Sending 'commit changes' to Claude Code session"
                    tmux send-keys -t "$CLAUDE_SESSION" "Please use /git:commit skill to submit changes to github"
                    tmux send-keys -t "$CLAUDE_SESSION" C-m
                    git_changes_notified=true
                    # Wait for Claude to process the commit before next check
                    sleep 15
                    continue
                fi
            fi
        else
            # Reset notification flag when no changes are present
            git_changes_notified=false
        fi

        # Build time filter for subsequent runs (only check comments after last check)
        local time_filter=""
        if [ -n "$last_check_time" ]; then
            time_filter="| map(select(.created_at > \"$last_check_time\"))"
        fi

        # Get unsolved comments with retry logic
        local unsolved_count=""
        for attempt in 1 2 3; do
            unsolved_count=$(gh api repos/:owner/:repo/pulls/"$pr_number"/comments --jq "
                # Filter by time if not first run
                . $time_filter |
                # Group all comments by thread
                group_by(.in_reply_to_id // .id) |
                map(
                    # For each thread, check if it should be excluded
                    if (
                        # Exclude if top-level comment starts with \"Claude Replied:\"
                        (.[0].body | startswith(\"Claude Replied:\")) or
                        # Exclude if last comment in thread starts with \"Claude Replied:\"
                        (.[-1].body | startswith(\"Claude Replied:\"))
                    ) then
                        empty
                    else
                        # Only count threads that start with a top-level comment
                        if .[0].in_reply_to_id == null then
                            .
                        else
                            empty
                        end
                    end
                ) | length
            " 2>/dev/null)

            if [ $? -eq 0 ] && [ -n "$unsolved_count" ]; then
                consecutive_failures=0
                break
            fi

            echo "$(date): API call attempt $attempt failed, retrying..."
            sleep $((attempt * 2))  # Exponential backoff
        done

        # Handle API failure
        if [ -z "$unsolved_count" ]; then
            unsolved_count=0
            consecutive_failures=$((consecutive_failures + 1))
            echo "$(date): [PR] API call failed (consecutive failures: $consecutive_failures)"

            if [ "$consecutive_failures" -ge "$max_failures" ]; then
                echo "$(date): Too many consecutive failures, backing off for 5 minutes"
                update_heartbeat "api-errors"
                sleep 300
                consecutive_failures=0
            fi
            continue
        fi

        echo "$(date): [PR] unsolved_count=$unsolved_count"

        if [ "$unsolved_count" -gt 0 ]; then
            echo "$(date): Unsolved PR comments detected! ($unsolved_count new)"

            # Send "fix comments" command to Claude Code session
            if session_exists "$CLAUDE_SESSION"; then
                echo "$(date): Sending 'fix comments' to Claude Code session"
                tmux send-keys -t "$CLAUDE_SESSION" "Please Use /fix-comments skill to address comments"
                tmux send-keys -t "$CLAUDE_SESSION" C-m
            fi

            # Update last check time to current time
            last_check_time=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
            last_comment_count="$unsolved_count"
        fi
    done
}

# Kill existing Claude session if it exists
if session_exists "$CLAUDE_SESSION"; then
    echo "Killing existing Claude Code session..."
    tmux kill-session -t "$CLAUDE_SESSION"
fi

# Kill existing monitor process if running
if [ -f /tmp/pr-monitor.pid ]; then
    old_pid=$(cat /tmp/pr-monitor.pid)
    if kill -0 "$old_pid" 2>/dev/null; then
        echo "Killing existing PR monitor process (PID: $old_pid)..."
        kill "$old_pid" 2>/dev/null || true
    fi
    rm -f /tmp/pr-monitor.pid
fi

# Start Claude Code in a detached tmux session
printf "${GREEN}Starting Claude Code in tmux session: $CLAUDE_SESSION${RESET}\n"
tmux new-session -d -s "$CLAUDE_SESSION" "claude --dangerously-skip-permissions --append-system-prompt \"\$(cat /usr/local/bin/setup/prompt/system_prompt.txt)\""

# Send initial query if provided
if [ -n "$QUERY" ]; then
    # Wait for Claude to fully initialize before sending query
    printf "${GREEN}Waiting for Claude to initialize...${RESET}\n"
    sleep 5
    printf "${GREEN}Sending initial query to Claude...${RESET}\n"
    tmux send-keys -t "$CLAUDE_SESSION" "$QUERY"
    tmux send-keys -t "$CLAUDE_SESSION" C-m
else
    # Give Claude a moment to start
    sleep 2
fi

# Start PR monitor as a background process (not tmux)
printf "${GREEN}Starting PR comment monitor (logging to: $MONITOR_LOG_FILE)${RESET}\n"
monitor_pr_comments >> "$MONITOR_LOG_FILE" 2>&1 &
MONITOR_PID=$!
echo "$MONITOR_PID" > /tmp/pr-monitor.pid
echo "$(date): PR monitor started with PID $MONITOR_PID" >> "$MONITOR_LOG_FILE"

# Display session information
printf "${YELLOW}=== CodeMate Sessions ===${RESET}\n"
echo "Claude Code session: $CLAUDE_SESSION (tmux)"
echo "PR Monitor: PID $MONITOR_PID (background process)"
echo ""
printf "${YELLOW}=== Log Files ===${RESET}\n"
echo "Monitor log: $MONITOR_LOG_FILE"
echo "Heartbeat: $HEARTBEAT_FILE"
echo ""
printf "${YELLOW}=== Commands ===${RESET}\n"
echo "View monitor log: tail -f $MONITOR_LOG_FILE"
echo "Check heartbeat: cat $HEARTBEAT_FILE"
echo "Stop monitor: kill $MONITOR_PID"
echo "List tmux sessions: tmux ls"
echo "Kill all: tmux kill-server && kill $MONITOR_PID"
echo ""
printf "${GREEN}Attaching to Claude Code session...${RESET}\n"
sleep 1

# Attach to Claude Code session
tmux attach -t "$CLAUDE_SESSION"
