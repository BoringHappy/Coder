#!/bin/bash
# common.sh - Shared state management for workspace hooks

STATE_FILE="${STATE_FILE:-/tmp/pr-monitor-state}"
SESSION_STATUS_FILE="/tmp/.session_status"

load_state() {
    if [ -f "$STATE_FILE" ]; then
        source "$STATE_FILE"
    else
        LAST_CHECK_TIME=""
        CONSECUTIVE_FAILURES=0
        LAST_ISSUE_COMMENT_ID=""
        READY_FOR_REVIEW_NOTIFIED="false"
    fi
}

save_state() {
    cat > "$STATE_FILE" <<EOF
LAST_CHECK_TIME="$LAST_CHECK_TIME"
CONSECUTIVE_FAILURES=$CONSECUTIVE_FAILURES
LAST_ISSUE_COMMENT_ID="$LAST_ISSUE_COMMENT_ID"
READY_FOR_REVIEW_NOTIFIED="$READY_FOR_REVIEW_NOTIFIED"
EOF
}
