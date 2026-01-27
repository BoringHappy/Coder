#!/bin/bash
# Claude Code Stop hook - sends notification to Slack
# Requires SLACK_WEBHOOK environment variable to be set

# Exit if SLACK_WEBHOOK is not set
[ -z "$SLACK_WEBHOOK" ] && exit 0

# Check if there are new commits since session start
COMMIT_FILE="$HOME/.session_commit"
if [ -f "$COMMIT_FILE" ]; then
    LAST_NOTIFIED_COMMIT=$(cat "$COMMIT_FILE")
    CURRENT_COMMIT=$(git rev-parse HEAD 2>/dev/null)
    if [ "$LAST_NOTIFIED_COMMIT" = "$CURRENT_COMMIT" ]; then
        # No new commits, skip sending notification
        exit 0
    fi
fi

# Get repo name and branch from git
REPO_NAME=$(basename -s .git "$(git config --get remote.origin.url)" 2>/dev/null || echo "unknown")
BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")

# Get PR info using gh CLI
PR_INFO=$(gh pr view --json number,title,url 2>/dev/null)
if [ -n "$PR_INFO" ]; then
    PR_URL=$(echo "$PR_INFO" | jq -r '.url // "N/A"')
    PR_TITLE=$(echo "$PR_INFO" | jq -r '.title // "N/A"')
else
    PR_URL="N/A"
    PR_TITLE="N/A"
fi

# Get last commit message
LAST_COMMIT=$(git log -1 --pretty=format:"%s" 2>/dev/null || echo "No commit found")

# Build Slack message payload with actual newlines
MESSAGE="*Repository:* ${REPO_NAME}
*Branch:* ${BRANCH_NAME}
*PR Link:* ${PR_URL}
*PR Title:* ${PR_TITLE}
*Commit:* ${LAST_COMMIT}"

PAYLOAD=$(jq -n --arg text "$MESSAGE" '{text: $text}')

# Send to Slack webhook
curl -s -X POST -H 'Content-type: application/json' \
    --data "$PAYLOAD" \
    "$SLACK_WEBHOOK" > /dev/null 2>&1

# Update commit file with current commit to avoid duplicate notifications
git rev-parse HEAD 2>/dev/null > "$COMMIT_FILE"

exit 0
