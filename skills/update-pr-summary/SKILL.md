---
name: update-pr-summary
description: Updates the summary/description of a GitHub pull request by analyzing the changes and creating an improved version. Use when the user wants to improve or regenerate their PR description.
disable-model-invocation: true
context: fork
---

# Update PR Summary

Analyzes the current pull request changes and generates an improved summary/description.

## What it does

1. **Fetches PR information**: Gets the current PR description and metadata
2. **Analyzes changes**: Reviews the diff to understand what was modified
3. **Checks for template**: Looks for pull_request_template.md to follow the project's format
4. **Generates improved summary**: Creates a better description based on the actual changes
5. **Updates the PR**: Uses `gh api` GraphQL mutation to update the PR description

## Current PR Information

Current description:
!`gh pr view --json body -q .body`

PR diff:
!`gh pr diff`

## Template Format

!`if [ -f .github/pull_request_template.md ]; then cat .github/pull_request_template.md; elif [ -f pull_request_template.md ]; then cat pull_request_template.md; else echo "No template found"; fi`

## Instructions

Based on the PR diff and current description above, create an improved PR summary that:
- Accurately describes what changes were made and why
- Follows the template format if one exists
- Is clear, concise, and informative
- Highlights the key changes and their impact
- Includes relevant technical details

After generating the improved summary, update the PR using:
```bash
gh api repos/:owner/:repo/pulls/$(gh pr view --json number -q .number) -X PATCH -f body='[your improved summary here]'
```

## Prerequisites

- Must be run in a git repository with an active pull request
- GitHub CLI (`gh`) must be installed and authenticated
- Must have write access to the repository
