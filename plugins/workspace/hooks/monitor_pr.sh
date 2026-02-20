#!/bin/bash
# PR Monitor Hook - Stop hook that checks for PR activity and injects prompts
# Fires when Claude finishes a turn; waits 60s for user activity before acting

# shellcheck source=common.sh
source "$(dirname "$0")/common.sh"

# Wait up to 60s for user activity; exit 0 (no injection) if user becomes active
wait_for_idle() {
    local last_status
    last_status=$(tail -1 "$SESSION_STATUS_FILE" 2>/dev/null)
    for i in $(seq 1 60); do
        sleep 1
        local current_status
        current_status=$(tail -1 "$SESSION_STATUS_FILE" 2>/dev/null)
        if [ "$current_status" != "$last_status" ]; then
            # User became active — stand down
            exit 0
        fi
    done
}

# Inject a prompt via hook stdout protocol and exit
inject_prompt() {
    local prompt="$1"
    save_state
    printf '{"continue":true,"prompt":"%s"}' \
        "$(echo "$prompt" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/g' | tr -d '\n' | sed 's/\\n$//')"
    exit 0
}

# Get PR number (no retry needed — gh is reliable in hook context)
get_pr_number() {
    gh pr view --json number -q .number 2>/dev/null
}

# Check for unsolved inline PR review comments
check_pr_comments() {
    local pr_number="$1"
    local time_filter=""
    if [ -n "$LAST_CHECK_TIME" ]; then
        time_filter="| map(select(.created_at > \"$LAST_CHECK_TIME\"))"
    fi

    local comments_data
    comments_data=$(gh api repos/:owner/:repo/pulls/"$pr_number"/comments --jq "
        . $time_filter |
        group_by(.in_reply_to_id // .id) |
        map(
            if (.[-1].body | startswith(\"Claude Replied:\")) then
                empty
            else
                .[-1]
            end
        )
    " 2>/dev/null) || { CONSECUTIVE_FAILURES=$((CONSECUTIVE_FAILURES + 1)); return 1; }

    CONSECUTIVE_FAILURES=0
    echo "$comments_data"
}

# Check for new issue (PR thread) comments
check_issue_comments() {
    local pr_number="$1"
    local comments

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

    [ -z "$comments" ] || [ "$comments" = "[]" ] && return 0

    local comment_id comment_body comment_user
    comment_id=$(echo "$comments" | jq -r '.[0].id')
    comment_body=$(echo "$comments" | jq -r '.[0].body')
    comment_user=$(echo "$comments" | jq -r '.[0].user.login')

    LAST_ISSUE_COMMENT_ID="$comment_id"
    inject_prompt "PR Comment from $comment_user: $comment_body (After addressing, use /pr:ack-comments skill to add 👀 reaction)"
}

# Check if PR is ready for review and needs description update
check_pr_ready_for_review() {
    local pr_number="$1"

    [ "$READY_FOR_REVIEW_NOTIFIED" = "true" ] && return 0

    local pr_data
    pr_data=$(gh pr view "$pr_number" --json isDraft,labels 2>/dev/null) || return 0

    local is_draft
    is_draft=$(echo "$pr_data" | jq -r '.isDraft')
    [ "$is_draft" = "true" ] && return 0

    local has_label
    has_label=$(echo "$pr_data" | jq -r '.labels[] | select(.name == "pr-updated") | .name')
    if [ -n "$has_label" ]; then
        READY_FOR_REVIEW_NOTIFIED="true"
        return 0
    fi

    READY_FOR_REVIEW_NOTIFIED="true"
    inject_prompt "The PR is now ready for review. Please use /pr:update skill to update the PR title and description based on all changes made. After updating, add the 'pr-updated' label to the GitHub PR using: gh api repos/:owner/:repo/issues/$pr_number/labels --input - <<< '[\"pr-updated\"]'"
}

main() {
    # Wait 60s for user activity before doing anything
    wait_for_idle

    load_state

    # Priority: review comments → issue comments → PR readiness

    local pr_number
    pr_number=$(get_pr_number)
    [ -z "$pr_number" ] && save_state && exit 0

    # Circuit breaker
    if [ "$CONSECUTIVE_FAILURES" -ge 5 ]; then
        save_state
        exit 0
    fi

    # 2. Inline review comments
    local comments_data
    comments_data=$(check_pr_comments "$pr_number")
    if [ $? -eq 0 ] && [ -n "$comments_data" ] && [ "$comments_data" != "[]" ]; then
        local unsolved_count
        unsolved_count=$(echo "$comments_data" | jq 'length')
        if [ "$unsolved_count" -gt 0 ]; then
            local comment_summary
            comment_summary=$(echo "$comments_data" | jq -r '
                map(
                    "- \(.path):\(.line // .original_line) by @\(.user.login):\n  \(.body | split("\n") | join("\n  "))"
                ) | join("\n\n")
            ')
            LAST_CHECK_TIME=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
            inject_prompt "Please use /pr:fix-comments skill to address the following PR review comments:\n\n$comment_summary"
        fi
    fi

    # 2. Issue (thread) comments
    check_issue_comments "$pr_number"

    # 3. PR readiness
    check_pr_ready_for_review "$pr_number"

    save_state
    exit 0
}

main "$@"
