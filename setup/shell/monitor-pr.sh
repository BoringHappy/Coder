#!/bin/bash
# PR Monitor Script - Standalone script for monitoring PR comments and git changes
# Can be run via cron or as a one-shot check

set -e

# Configuration (can be overridden via environment variables)
CLAUDE_SESSION="${CLAUDE_SESSION:-claude-code}"
HEARTBEAT_FILE="${HEARTBEAT_FILE:-/tmp/codemate-heartbeat}"
IDLE_TIMEOUT="${IDLE_TIMEOUT:-3600}"
STATE_FILE="${STATE_FILE:-/tmp/pr-monitor-state}"
LOG_FILE="${LOG_FILE:-/tmp/pr-monitor.log}"

# Ensure we're in the repo directory
cd "${REPO_DIR:-/home/user/repo}" 2>/dev/null || cd /home/user/repo

# Logging function
log() {
    echo "$(date): $*" >> "$LOG_FILE"
}

# Function to update heartbeat file
update_heartbeat() {
    local status="${1:-alive}"
    echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ') $status" > "$HEARTBEAT_FILE"
}

# Function to check if a tmux session exists
session_exists() {
    tmux has-session -t "$1" 2>/dev/null
}

# Function to check if Claude session is stopped
is_session_stopped() {
    local status_file="$HOME/.session_status"
    if [ -f "$status_file" ]; then
        local last_line=$(tail -n 10 "$status_file" | grep -v '^$' | tail -n 1)
        if [[ "$last_line" =~ Stop$ ]]; then
            return 0
        fi
    fi
    return 1
}

# Load state from previous run
load_state() {
    if [ -f "$STATE_FILE" ]; then
        source "$STATE_FILE"
    else
        LAST_CHECK_TIME=""
        GIT_CHANGES_NOTIFIED="false"
        CONSECUTIVE_FAILURES=0
        LAST_ACTIVITY_TIME=$(date +%s)
    fi
}

# Save state for next run
save_state() {
    cat > "$STATE_FILE" <<EOF
LAST_CHECK_TIME="$LAST_CHECK_TIME"
GIT_CHANGES_NOTIFIED="$GIT_CHANGES_NOTIFIED"
CONSECUTIVE_FAILURES=$CONSECUTIVE_FAILURES
LAST_ACTIVITY_TIME=$LAST_ACTIVITY_TIME
EOF
}

# Check keep-alive status
check_keep_alive() {
    local current_time=$(date +%s)
    local has_activity=false

    # Check if Claude session is busy
    if ! is_session_stopped 2>/dev/null; then
        has_activity=true
    fi

    # Check for unstaged git changes
    if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
        has_activity=true
    fi

    if [ "$has_activity" = true ]; then
        LAST_ACTIVITY_TIME=$current_time
        return 0
    fi

    local idle_time=$((current_time - LAST_ACTIVITY_TIME))
    if [ "$idle_time" -gt "$IDLE_TIMEOUT" ]; then
        log "Idle timeout reached ($idle_time seconds)"
        return 1
    fi

    return 0
}

# Get PR number with retry
get_pr_number() {
    local pr_number=""
    for attempt in 1 2 3; do
        pr_number=$(gh pr view --json number -q .number 2>/dev/null || echo "")
        if [ -n "$pr_number" ]; then
            echo "$pr_number"
            return 0
        fi
        log "Attempt $attempt to get PR number failed, retrying..."
        sleep 2
    done
    return 1
}

# Check for unsolved PR comments
check_pr_comments() {
    local pr_number="$1"
    local time_filter=""

    if [ -n "$LAST_CHECK_TIME" ]; then
        time_filter="| map(select(.created_at > \"$LAST_CHECK_TIME\"))"
    fi

    local unsolved_count=""
    for attempt in 1 2 3; do
        unsolved_count=$(gh api repos/:owner/:repo/pulls/"$pr_number"/comments --jq "
            . $time_filter |
            group_by(.in_reply_to_id // .id) |
            map(
                if (
                    (.[0].body | startswith(\"Claude Replied:\")) or
                    (.[-1].body | startswith(\"Claude Replied:\"))
                ) then
                    empty
                else
                    if .[0].in_reply_to_id == null then
                        .
                    else
                        empty
                    end
                end
            ) | length
        " 2>/dev/null)

        if [ $? -eq 0 ] && [ -n "$unsolved_count" ]; then
            CONSECUTIVE_FAILURES=0
            echo "$unsolved_count"
            return 0
        fi

        log "API call attempt $attempt failed, retrying..."
        sleep $((attempt * 2))
    done

    CONSECUTIVE_FAILURES=$((CONSECUTIVE_FAILURES + 1))
    log "[PR] API call failed (consecutive failures: $CONSECUTIVE_FAILURES)"
    return 1
}

# Main monitoring logic (single run)
main() {
    log "=== PR Monitor check started ==="

    # Load previous state
    load_state

    # Update heartbeat
    update_heartbeat "alive"

    # Check keep-alive
    if ! check_keep_alive; then
        update_heartbeat "idle-timeout"
    fi

    # Check if Claude session is stopped (only act when stopped)
    if ! is_session_stopped; then
        log "[Session] Claude is busy, skipping check"
        save_state
        exit 0
    fi

    # Get PR number
    pr_number=$(get_pr_number) || {
        log "No PR found, skipping PR comment check"
        update_heartbeat "no-pr"
        save_state
        exit 0
    }

    log "Checking PR #$pr_number"

    # Check for unstaged git changes
    git_changes=$(git status --porcelain 2>/dev/null || echo "")
    log "[Git] changes=$([ -n "$git_changes" ] && echo 'yes' || echo 'no'), notified=$GIT_CHANGES_NOTIFIED"

    if [ -n "$git_changes" ]; then
        if [ "$GIT_CHANGES_NOTIFIED" = "false" ]; then
            log "Unstaged changes detected!"
            if session_exists "$CLAUDE_SESSION"; then
                log "Sending 'commit changes' to Claude Code session"
                tmux send-keys -t "$CLAUDE_SESSION" "Please use /git:commit skill to submit changes to github"
                tmux send-keys -t "$CLAUDE_SESSION" C-m
                GIT_CHANGES_NOTIFIED="true"
            fi
        fi
    else
        GIT_CHANGES_NOTIFIED="false"
    fi

    # Check for unsolved PR comments (skip if too many failures)
    if [ "$CONSECUTIVE_FAILURES" -ge 5 ]; then
        log "Too many consecutive failures, skipping API call"
        update_heartbeat "api-errors"
        save_state
        exit 0
    fi

    unsolved_count=$(check_pr_comments "$pr_number") || {
        save_state
        exit 0
    }

    log "[PR] unsolved_count=$unsolved_count"

    if [ "$unsolved_count" -gt 0 ]; then
        log "Unsolved PR comments detected! ($unsolved_count)"
        if session_exists "$CLAUDE_SESSION"; then
            log "Sending 'fix comments' to Claude Code session"
            tmux send-keys -t "$CLAUDE_SESSION" "Please Use /fix-comments skill to address comments"
            tmux send-keys -t "$CLAUDE_SESSION" C-m
        fi
        LAST_CHECK_TIME=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    fi

    save_state
    log "=== PR Monitor check completed ==="
}

# Run main function
main "$@"
