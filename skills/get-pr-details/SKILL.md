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

Description:
!`gh pr view --json body -q .body`

Changed files:
!`gh pr view --json files -q '.files[].path'`

## Instructions

Display the PR information shown above to the user in a clear format.
