---
name: git-commit
description: Stages all changes, creates a commit with a meaningful message, and pushes to the remote. Use when the user wants to commit and push their work.
disable-model-invocation: true
context: fork
---

# Git Commit and Push

Stages changes, commits with a descriptive message, and pushes to the remote repository.

## Current State

Git status:
!`git status --short`

Recent commits for style reference:
!`git log --oneline -5`

Current branch:
!`git branch --show-current`

Diff of changes:
!`git diff --stat`

## Instructions

1. Review the changes shown above
2. Stage all changes using `git add -A`
3. Create a commit with a clear, descriptive message that:
   - Uses imperative mood (e.g., "Add feature" not "Added feature")
   - Is concise but descriptive
   - Follows the style of recent commits if a pattern exists
4. Push to the remote using `git push`

If the branch has no upstream, use:
```bash
git push -u origin $(git branch --show-current)
```

## Prerequisites

- Must be run in a git repository
- Must have changes to commit
- Must have push access to the remote
