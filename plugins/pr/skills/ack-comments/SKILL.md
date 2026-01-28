---
name: ack-comments
description: Acknowledges new PR issue comments by replying with an eye emoji (👀). Use when you need to mark issue comments as seen before processing them.
---

# Acknowledge PR Issue Comments

Replies to new PR issue comments with an eye emoji (👀) to indicate they have been seen.

## What it does

1. **Fetches issue comments**: Gets all issue comments (pure PR comments) from the current pull request
2. **Filters unacknowledged comments**: Skips comments that already have a reply containing 👀
3. **Replies with eye emoji**: Posts a reply with 👀 to each new comment to mark it as acknowledged

## Current PR Issue Comments

PR Number:
!`gh pr view --json number -q .number | cat`

Issue comments (showing comment ID and body):
!`gh api repos/:owner/:repo/issues/$(gh pr view --json number -q .number)/comments --jq '.[] | "ID: \(.id) | User: \(.user.login) | Body: \(.body[0:100])..."' | cat`

## Instructions

For each issue comment shown above that does NOT already have a 👀 reply:

1. **Check if already acknowledged**: Look for existing replies to the comment that contain 👀
2. **Reply with eye emoji**: Use the following command to reply:
   ```bash
   gh api repos/:owner/:repo/issues/comments/{comment_id}/reactions -X POST -f content=eyes
   ```

   Note: This adds an "eyes" reaction (👀) to the comment rather than a text reply, which is cleaner.

3. **Report status**: Tell the user which comments were acknowledged

## Prerequisites

- Must be run in a git repository
- GitHub CLI (`gh`) must be installed and authenticated
- Pull request must exist for the current branch

## Notes

- Uses GitHub reactions API to add 👀 emoji reaction to comments
- The reaction serves as an acknowledgment that the comment has been seen
- The monitor script filters out comments that have the 👀 reaction
