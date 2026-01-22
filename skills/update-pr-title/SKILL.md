---
name: update-pr-title
description: Updates the title of a GitHub pull request by analyzing the changes and current summary. Use when the user wants to improve or regenerate their PR title.
disable-model-invocation: true
context: fork
---

# Update PR Title

Analyzes the pull request changes and summary to generate an improved title.

## What it does

1. **Fetches PR information**: Gets the current PR title, description, and metadata
2. **Analyzes changes**: Reviews the diff to understand what was modified
3. **Generates improved title**: Creates a concise, descriptive title based on the changes and summary
4. **Updates the PR**: Uses `gh pr edit` to update the PR title

## Current PR Information

Current title:
!`gh pr view --json title -q .title`

Current description:
!`gh pr view --json body -q .body`

PR diff summary:
!`gh pr diff --name-only`

## Instructions

Based on the PR information above, create an improved PR title that:
- Is concise (typically 50-72 characters)
- Clearly describes the main change or feature
- Follows conventional commit style if the project uses it
- Is written in imperative mood (e.g., "Add feature" not "Added feature")
- Captures the essence of all changes

After generating the improved title, update the PR using:
```bash
gh pr edit --title "Your improved title here"
```

## Prerequisites

- Must be run in a git repository with an active pull request
- GitHub CLI (`gh`) must be installed and authenticated
- Must have write access to the repository
