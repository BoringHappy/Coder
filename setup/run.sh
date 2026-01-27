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

    # Wait at least 1 minute before checking PR number to allow session to initialize
    echo "$(date): Waiting 60 seconds before starting monitoring..."
    sleep 60

    # Get PR number once at the start (it won't change during monitoring)
    local pr_number=$(gh pr view --json number -q .number 2>/dev/null || echo "")

    if [ -z "$pr_number" ]; then
        echo "$(date): No PR found, monitoring disabled"
        return
    fi

    echo "$(date): Monitoring PR #$pr_number for new comments"
    echo "$(date): Monitoring for unstaged git changes"

    while true; do
        sleep "$CHECK_INTERVAL"

        # Check session status - only proceed if last line ends with "Stop"
        if ! is_session_stopped; then
            continue
        fi

        # Check for unstaged changes
        local git_changes=$(git status --porcelain 2>/dev/null)
        echo "$(date): [Git] changes=$([ -n \"$git_changes\" ] && echo 'yes' || echo 'no'), notified=$git_changes_notified"

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

        # Get unsolved comments, excluding:
        # 1. Comments starting with "Claude Replied:"
        # 2. Comment threads where the last reply starts with "Claude Replied:"
        # 3. Comments older than last check time (for subsequent runs)
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
        " 2>/dev/null || echo "0")

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
