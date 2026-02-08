#!/bin/bash
# Claude Code Stop hook - sends notification to Slack
# Requires SLACK_WEBHOOK environment variable to be set

# Exit if SLACK_WEBHOOK is not set
[ -z "$SLACK_WEBHOOK" ] && exit 0

# Check if there are new commits since session start
COMMIT_FILE="${SESSION_COMMIT_FILE:-/tmp/.session_commit}"
if [ -f "$COMMIT_FILE" ]; then
    LAST_NOTIFIED_COMMIT=$(cat "$COMMIT_FILE")
    CURRENT_COMMIT=$(git rev-parse HEAD 2>/dev/null)
    if [ "$LAST_NOTIFIED_COMMIT" = "$CURRENT_COMMIT" ]; then
        # No new commits, skip sending notification
        exit 0
    fi
fi

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

# Build Slack message payload using Block Kit for rich formatting
PAYLOAD=$(jq -n \
  --arg pr_url "$PR_URL" \
  --arg pr_title "$PR_TITLE" \
  --arg commit "$LAST_COMMIT" \
  '{
    attachments: [
      {
        color: "#36a64f",
        blocks: [
          {
            type: "header",
            text: { type: "plain_text", text: "Code Changes Pushed", emoji: true }
          },
          {
            type: "section",
            text: { type: "mrkdwn", text: ("*PR:* " + $pr_title + "\n*Commit:* " + $commit) }
          },
          {
            type: "actions",
            elements: [
              {
                type: "button",
                text: { type: "plain_text", text: "View PR", emoji: true },
                url: $pr_url,
                style: "primary"
              }
            ]
          }
        ]
      }
    ]
  }')

# Send to Slack webhook
curl -s -X POST -H 'Content-type: application/json' \
    --data "$PAYLOAD" \
    "$SLACK_WEBHOOK" > /dev/null 2>&1

# Update commit file with current commit to avoid duplicate notifications
git rev-parse HEAD 2>/dev/null > "$COMMIT_FILE"

exit 0
