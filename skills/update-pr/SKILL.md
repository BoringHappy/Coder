---
name: update-pr
description: Updates the summary/description and optionally the title of a GitHub pull request. Use `/update-pr` to update both title and summary, or `/update-pr --summary-only` to update only the summary.
disable-model-invocation: true
context: fork
---

# Update PR Summary and Title

Analyzes the current pull request changes and generates an improved summary/description and optionally title.

## Arguments

$ARGUMENTS

**Supported arguments:**
- `--summary-only`: Only update the PR summary/description, skip title update
- (no arguments): Update both title and summary (default behavior)

## What it does

1. **Fetches PR information**: Gets the current PR title, description, and metadata
2. **Analyzes changes**: Reviews the diff to understand what was modified
3. **Checks for template**: Looks for pull_request_template.md to follow the project's format
4. **Generates improved summary**: Creates a better description based on the actual changes
5. **Generates improved title**: Creates a concise, descriptive title based on the changes (unless `--summary-only` is specified)
6. **Updates the PR**: Uses `gh api` REST API to update the PR

## Current PR Information

Current title:
!`gh pr view --json title -q .title`

Current description:
!`gh pr view --json body -q .body`

PR diff:
!`gh pr diff`

Files changed:
!`gh pr diff --name-only`

## Template Format

!`if [ -f .github/PULL_REQUEST_TEMPLATE.md ]; then cat .github/PULL_REQUEST_TEMPLATE.md; elif [ -f .github/pull_request_template.md ]; then cat .github/pull_request_template.md; elif [ -f pull_request_template.md ]; then cat pull_request_template.md; else echo "No template found"; fi`

## Instructions

Based on the PR diff and current information above:

### For the Summary
Create an improved PR summary that:
- Accurately describes what changes were made and why
- Follows the template format if one exists
- Is clear, concise, and informative
- Highlights the key changes and their impact
- Includes relevant technical details

### For the Title (skip if `--summary-only` argument is provided)
Create an improved PR title that:
- Is concise (typically 50-72 characters)
- Clearly describes the main change or feature
- Follows conventional commit style if the project uses it
- Is written in imperative mood (e.g., "Add feature" not "Added feature")
- Captures the essence of all changes

### Updating the PR

**If `--summary-only` argument is provided**, only update the summary:
```bash
gh api repos/:owner/:repo/pulls/$(gh pr view --json number -q .number) -X PATCH -f body='Your improved summary here'
```

**If no arguments or updating both**, update both title and summary using a single API call:
```bash
gh api repos/:owner/:repo/pulls/$(gh pr view --json number -q .number) -X PATCH -f title="Your improved title here" -f body='Your improved summary here'
```

## Prerequisites

- Must be run in a git repository with an active pull request
- GitHub CLI (`gh`) must be installed and authenticated
- Must have write access to the repository
