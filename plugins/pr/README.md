# PR Plugin

A Claude Code plugin for managing GitHub Pull Request workflows.

## Overview

This plugin provides skills for creating, updating, and managing pull requests in GitHub repositories. It's designed to work seamlessly with the CodeMate environment.

## Skills

### `/pr:get-details`
Fetches and displays comprehensive PR information including:
- PR title and description
- Source and target branches
- Changed files
- Review comments
- PR-level comments

**Usage:**
```
/pr:get-details
```

### `/pr:fix-comments`
Automatically addresses feedback from PR review comments.

**Usage:**
```
/pr:fix-comments
```

**Workflow:**
1. Fetches all PR comments
2. Analyzes feedback to understand required changes
3. Reads and modifies affected files
4. Commits and pushes changes (uses `/git:commit` from git plugin)
5. Replies to comment threads confirming fixes

### `/pr:update`
Updates the PR title and/or description based on the actual changes.

**Usage:**
```
/pr:update                  # Update both title and summary
/pr:update --summary-only   # Update only the summary
```

**Features:**
- Analyzes PR diff to generate accurate descriptions
- Follows project's PR template format if available
- Uses conventional commit style for titles

## Installation

This plugin is automatically loaded in the CodeMate environment via the `--plugin-dir` flag in the Dockerfile.

For manual installation in other environments:
```bash
claude --plugin-dir /path/to/pr
```

## Requirements

- GitHub CLI (`gh`) installed and authenticated
- Git repository with remote access
- Active pull request (for most skills)

## Hooks

### `send_to_slack.sh`

A Claude Code Stop hook that sends notifications to Slack when Claude stops working. This is useful for getting notified when Claude completes a task or needs attention.

**Setup:**

1. Create a Slack Incoming Webhook:
   - Go to your Slack workspace's App Directory
   - Search for "Incoming WebHooks" and add it
   - Choose a channel and copy the webhook URL

2. Set the `SLACK_WEBHOOK` environment variable in your `.env` file:
   ```bash
   SLACK_WEBHOOK=https://hooks.slack.com/services/YOUR/WEBHOOK/URL
   ```

**Message Content:**

The Slack notification includes:
- Repository name
- Branch name
- PR link
- PR title
- Last commit message

**Example Slack Message:**
```
*Repository:* my-repo
*Branch:* feature/new-feature
*PR Link:* https://github.com/user/my-repo/pull/123
*PR Title:* Add new feature
*Commit:* Fix bug in authentication flow
```

**Note:** If `SLACK_WEBHOOK` is not set, the hook exits silently without sending any notification.

## Plugin Structure

```
pr/
├── .claude-plugin/
│   └── plugin.json          # Plugin manifest
├── hooks/
│   └── send_to_slack.sh     # Slack notification hook
└── skills/
    ├── get-details/
    │   └── SKILL.md
    ├── fix-comments/
    │   └── SKILL.md
    └── update/
        └── SKILL.md
```

## Version

1.0.0
