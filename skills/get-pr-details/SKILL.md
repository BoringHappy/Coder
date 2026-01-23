---
name: get-pr-details
description: Gets details of a GitHub pull request including title, description, and file changes. Use when the user wants to view PR information.
context: fork
---

# Get PR Details

Retrieves and displays pull request information including title, description, and changed files.

## PR Information

Title:
!`gh pr view --json title -q .title`

Branch:
!`gh pr view --json headRefName,baseRefName -q '"\(.headRefName) → \(.baseRefName)"'`

Description:
!`gh pr view --json body -q .body`

Changed files:
!`gh pr view --json files -q '.files[].path'`

## Instructions

**IMPORTANT: You MUST output a summary to the user.** After gathering the PR information above, display a formatted summary that includes:

1. **PR Title** - The pull request title
2. **Branch** - Source branch → target branch
3. **Description** - The PR description/body (summarized if lengthy)
4. **Changed Files** - List of files modified in this PR

Format the output clearly using markdown so the user can see the PR details at a glance. This summary should always be visible in your response to the user.
