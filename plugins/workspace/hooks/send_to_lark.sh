#!/bin/bash
# Claude Code Stop hook - sends notification to Lark
# Requires LARK_WEBHOOK environment variable to be set

# Exit if LARK_WEBHOOK is not set
[ -z "$LARK_WEBHOOK" ] && exit 0

# Check if there are new commits since session start
COMMIT_FILE="/tmp/.session_commit"
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

# Build Lark message payload using interactive card format
PAYLOAD=$(jq -n \
  --arg pr_url "$PR_URL" \
  --arg pr_title "$PR_TITLE" \
  --arg commit "$LAST_COMMIT" \
  '{
    msg_type: "interactive",
    card: {
      header: {
        title: { tag: "plain_text", content: "Code Changes Pushed" },
        template: "green"
      },
      elements: [
        {
          tag: "div",
          text: {
            tag: "lark_md",
            content: ("**PR:** " + $pr_title + "\n**Commit:** " + $commit)
          }
        },
        {
          tag: "action",
          actions: [
            {
              tag: "button",
              text: { tag: "plain_text", content: "View PR" },
              url: $pr_url,
              type: "primary"
            }
          ]
        }
      ]
    }
  }')

# Send to Lark webhook
curl -s -X POST -H 'Content-type: application/json' \
    --data "$PAYLOAD" \
    "$LARK_WEBHOOK" > /dev/null 2>&1

# Update commit file with current commit to avoid duplicate notifications
git rev-parse HEAD 2>/dev/null > "$COMMIT_FILE"

exit 0
