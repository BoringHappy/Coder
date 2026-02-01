#!/bin/bash
# PR Monitor Script - Standalone script for monitoring PR comments and git changes
# Designed to be run via cron (no loop, single execution)

# Source common utilities
SCRIPT_DIR="$(dirname "$0")"
source "$SCRIPT_DIR/common.sh"

# Import environment variables from the container's init process (PID 1)
# Cron doesn't inherit Docker runtime env vars, but /proc/1/environ has them
if [ -r /proc/1/environ ]; then
    while IFS= read -r -d '' line; do
        export "$line"
    done < /proc/1/environ
fi

# Set PATH and HOME for cron environment
export PATH="/usr/local/bin:/usr/bin:/bin:/home/agent/.local/bin"
export HOME="${HOME:-/home/agent}"

# Lock file to prevent overlapping runs
LOCK_FILE="/tmp/pr-monitor.lock"
exec 200>"$LOCK_FILE"
flock -n 200 || { echo "$(date): Already running, skipping"; exit 0; }

# Configuration (can be overridden via environment variables)
CLAUDE_SESSION="${CLAUDE_SESSION:-claude-code}"
STATE_FILE="${STATE_FILE:-/tmp/pr-monitor-state}"

# Derive repo directory from GIT_REPO_URL (e.g., https://github.com/org/repo.git -> /home/agent/repo)
if [ -z "$REPO_DIR" ] && [ -n "$GIT_REPO_URL" ]; then
    REPO_NAME=$(basename "$GIT_REPO_URL" .git)
    REPO_DIR="/home/agent/$REPO_NAME"
fi
cd "${REPO_DIR:-/home/agent/repo}" || { echo "$(date): Failed to cd to repo directory"; exit 1; }

# Function to check if a tmux session exists
session_exists() {
    tmux has-session -t "$1" 2>/dev/null
}

# Function to check if Claude session is stopped
is_session_stopped() {
    local status_file="/tmp/.session_status"
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
        LAST_ISSUE_COMMENT_ID=""
    fi
}

# Save state for next run
save_state() {
    cat > "$STATE_FILE" <<EOF
LAST_CHECK_TIME="$LAST_CHECK_TIME"
GIT_CHANGES_NOTIFIED="$GIT_CHANGES_NOTIFIED"
CONSECUTIVE_FAILURES=$CONSECUTIVE_FAILURES
LAST_ISSUE_COMMENT_ID="$LAST_ISSUE_COMMENT_ID"
EOF
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

        sleep $((attempt * 2))
    done

    CONSECUTIVE_FAILURES=$((CONSECUTIVE_FAILURES + 1))
    return 1
}

# Check for new Issue Comments (pure PR comments) and send content to Claude
check_issue_comments() {
    local pr_number="$1"

    # Fetch issue comments with reactions in a single API call
    # Filter out comments that: are already processed, start with "Claude Replied:", or have eyes reaction
    local comments=""
    for attempt in 1 2 3; do
        if [ -n "$LAST_ISSUE_COMMENT_ID" ]; then
            comments=$(gh api repos/:owner/:repo/issues/"$pr_number"/comments --jq "
                map(select(.id > $LAST_ISSUE_COMMENT_ID)) |
                map(select(.body | startswith(\"Claude Replied:\") | not)) |
                map(select(.reactions.eyes == 0)) |
                sort_by(.id)
            " 2>/dev/null)
        else
            comments=$(gh api repos/:owner/:repo/issues/"$pr_number"/comments --jq "
                map(select(.body | startswith(\"Claude Replied:\") | not)) |
                map(select(.reactions.eyes == 0)) |
                sort_by(.id)
            " 2>/dev/null)
        fi

        if [ $? -eq 0 ]; then
            break
        fi
        sleep $((attempt * 2))
    done

    if [ -z "$comments" ] || [ "$comments" = "[]" ]; then
        return 0
    fi

    # Process the first unacknowledged comment
    local comment_count=$(echo "$comments" | jq 'length')
    if [ "$comment_count" -gt 0 ]; then
        local comment_id=$(echo "$comments" | jq -r '.[0].id')
        local comment_body=$(echo "$comments" | jq -r '.[0].body')
        local comment_user=$(echo "$comments" | jq -r '.[0].user.login')

        echo "$(date): Processing issue comment #$comment_id from $comment_user"

        if session_exists "$CLAUDE_SESSION"; then
            # Send the comment content to Claude with instruction to acknowledge
            send_and_verify_command "$CLAUDE_SESSION" "PR Comment from $comment_user: $comment_body (After addressing, use /pr:ack-comments skill to add 👀 reaction)" 3
            LAST_ISSUE_COMMENT_ID="$comment_id"
            return 1  # Signal that we sent a comment
        fi
    fi

    return 0
}

# Main logic (single run)
main() {
    echo "$(date): PR Monitor check started"

    load_state

    # Check if Claude session is stopped (only act when stopped)
    if ! is_session_stopped; then
        echo "$(date): Claude is busy, skipping"
        save_state
        exit 0
    fi

    # Get PR number
    pr_number=$(get_pr_number) || {
        echo "$(date): No PR found"
        save_state
        exit 0
    }

    echo "$(date): Checking PR #$pr_number"

    # Check for unstaged git changes
    git_changes=$(git status --porcelain 2>/dev/null || echo "")

    if [ -n "$git_changes" ]; then
        if [ "$GIT_CHANGES_NOTIFIED" = "false" ]; then
            echo "$(date): Unstaged changes detected"
            if session_exists "$CLAUDE_SESSION"; then
                send_and_verify_command "$CLAUDE_SESSION" "Please use /git:commit skill to submit changes to github" 3
                GIT_CHANGES_NOTIFIED="true"
            fi
        fi
    else
        GIT_CHANGES_NOTIFIED="false"
    fi

    # Skip API call if too many failures
    if [ "$CONSECUTIVE_FAILURES" -ge 5 ]; then
        echo "$(date): Too many failures, skipping API call"
        save_state
        exit 0
    fi

    # Check for new Issue Comments (pure PR comments)
    check_issue_comments "$pr_number"
    issue_comment_sent=$?

    # If we sent an issue comment, skip review comments check this run
    if [ "$issue_comment_sent" -eq 1 ]; then
        echo "$(date): Issue comment sent to Claude, skipping review comments check"
        save_state
        echo "$(date): PR Monitor check completed"
        exit 0
    fi

    unsolved_count=$(check_pr_comments "$pr_number") || {
        echo "$(date): API call failed"
        save_state
        exit 0
    }

    echo "$(date): unsolved_count=$unsolved_count"

    if [ "$unsolved_count" -gt 0 ]; then
        echo "$(date): Unsolved PR comments detected ($unsolved_count)"
        if session_exists "$CLAUDE_SESSION"; then
            send_and_verify_command "$CLAUDE_SESSION" "Please Use /fix-comments skill to address comments" 3
        fi
        LAST_CHECK_TIME=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
    fi

    save_state
    echo "$(date): PR Monitor check completed"
}

main "$@"
