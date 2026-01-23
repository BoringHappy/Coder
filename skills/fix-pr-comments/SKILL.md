---
name: fix-pr-comments
description: Reads comments from a GitHub pull request, fixes the issues mentioned in the comments, commits the changes, and replies to the comments. Use when the user wants to address PR feedback or fix issues mentioned in code reviews.
---

# Fix PR Comments

Automatically address feedback from GitHub pull request comments.

## What it does

1. **Reads PR comments**: Uses `/pr-comments` command to fetch and display all comments (both PR-level and code review comments) from the current pull request
2. **Parses feedback**: Analyzes each comment to understand what needs to be fixed
3. **Reads affected files**: Uses the Read tool to examine files mentioned in comments
4. **Applies fixes**: Makes the necessary code changes using the Edit or Write tools
5. **Commits changes**: Creates a git commit with a descriptive message addressing the feedback
6. **Pushes to remote**: Pushes the commit to the remote branch
7. **Replies to comments**: Uses `gh api -X POST repos/:owner/:repo/pulls/{pr}/comments/{comment_id}/replies` to reply directly to each review comment thread, confirming the fix

## Prerequisites

- Must be run in a git repository
- GitHub CLI (`gh`) must be installed and authenticated
- Must have write access to the repository
- Pull request must exist for the current branch
- Requires `/pr-comments` command to be available

## Technical Details

- Uses `/pr-comments` command to fetch both PR-level and code review comments in a formatted way
- The `/pr-comments` command internally uses `gh pr view` and `gh api` to gather all comment information
- Replies use `gh api -X POST repos/:owner/:repo/pulls/{pr}/comments/{comment_id}/replies` to thread responses
- All commits include the co-authored-by trailer for Claude
- Handles multiple comments in a single run

## Notes

- The command will process all unresolved review comments on the PR
- Each fix is committed separately for better tracking
- Replies are added to the specific comment thread, not as new top-level comments
