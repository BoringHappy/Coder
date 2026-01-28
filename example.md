# Examples

This document provides practical examples of using CodeMate for common development workflows.

## Table of Contents

- [Basic Workflows](#basic-workflows)
- [PR Management](#pr-management)
- [Issue-Based Development](#issue-based-development)
- [Advanced Scenarios](#advanced-scenarios)
- [Custom Configurations](#custom-configurations)

## Basic Workflows

### Example 1: Starting a New Feature Branch

```bash
# Clone the start.sh script
curl -O https://raw.githubusercontent.com/BoringHappy/CodeMate/main/start.sh
chmod +x start.sh

# First time setup
./start.sh --setup

# Start working on a new feature
./start.sh --branch feature/add-user-authentication

# Inside the container, Claude will:
# 1. Clone your repository
# 2. Create the feature/add-user-authentication branch
# 3. Create a draft PR automatically
# 4. Wait for your instructions
```

**What to tell Claude:**
```
Please implement user authentication with JWT tokens.
Add login and logout endpoints, and middleware to protect routes.
```

### Example 2: Working on an Existing PR

```bash
# Continue work on PR #123
./start.sh --pr 123

# Inside the container, Claude will:
# 1. Clone the repository
# 2. Checkout the PR branch
# 3. Load the PR context
# 4. Ready to make changes
```

**What to tell Claude:**
```
Please review the current changes and add unit tests for the new endpoints.
```

### Example 3: Quick Bug Fix

```bash
# Start a hotfix branch
./start.sh --branch hotfix/fix-login-redirect

# With an initial query
./start.sh --branch hotfix/fix-login-redirect \
  --query "Fix the login redirect issue where users are sent to /home instead of /dashboard"
```

## PR Management

### Example 4: Addressing PR Review Comments

When reviewers leave comments on your PR, CodeMate automatically detects them and notifies Claude.

**Scenario:** Reviewer leaves inline code comments

```bash
# Start CodeMate on your PR
./start.sh --pr 456

# The PR monitor will detect new review comments and automatically prompt Claude:
# "Please Use /fix-comments skill to address comments"
```

**Manual approach:**
```
/pr:fix-comments
```

Claude will:
1. Read all unresolved review comments
2. Make the requested changes
3. Commit and push
4. Reply to each comment with "Claude Replied: [explanation]"

### Example 5: Updating PR Description

```bash
./start.sh --pr 789
```

**Inside the container:**
```
/pr:update

# Or update only the summary
/pr:update --summary-only
```

Claude will analyze all commits and changes, then update the PR title and description to accurately reflect the work done.

### Example 6: Getting PR Details

```bash
./start.sh --pr 101
```

**Inside the container:**
```
/pr:get-details
```

Claude will show:
- PR title and description
- Files changed
- Review comments
- Current status

## Issue-Based Development

### Example 7: Implementing a Feature Request

```bash
# Start work directly from a GitHub issue
./start.sh --issue 234

# CodeMate will:
# 1. Create branch "issue-234"
# 2. Automatically run: /pr:read-issue 234
# 3. Claude reads the issue and starts implementing
```

**Example issue content:**
```
Title: Add dark mode support
Description: Users want a dark mode toggle in the settings page.
Should persist preference in localStorage.
```

Claude will:
1. Read the issue details
2. Analyze requirements
3. Implement the feature
4. Create a PR when ready

### Example 8: Fixing a Bug from Issue Tracker

```bash
./start.sh --issue 567
```

**Example issue:**
```
Title: Login form validation not working
Description: Email validation accepts invalid formats like "user@"
Steps to reproduce:
1. Go to /login
2. Enter "user@" in email field
3. Form submits without error
```

Claude will:
1. Understand the bug from issue description
2. Locate the validation code
3. Fix the issue
4. Add tests to prevent regression

## Advanced Scenarios

### Example 9: Custom Volume Mounts

```bash
# Mount local configuration files
./start.sh --branch feature/api-integration \
  --mount ~/.aws:/home/agent/.aws:ro \
  --mount ~/project-configs:/configs

# Inside container, Claude can access:
# - AWS credentials at /home/agent/.aws (read-only)
# - Project configs at /configs
```

**Use cases:**
- Sharing credentials (read-only recommended)
- Accessing local databases
- Using custom configuration files

### Example 10: Building with Custom Toolchains

Create a custom Dockerfile:

```dockerfile
# Dockerfile.custom
FROM ghcr.io/boringhappy/codemate:latest

# Add Java for Spring Boot projects
RUN apt-get update && apt-get install -y openjdk-17-jdk maven

# Add PHP for Laravel projects
RUN apt-get install -y php php-cli php-mbstring composer

# Clean up
RUN apt-get clean && rm -rf /var/lib/apt/lists/*
```

Run with custom build:

```bash
./start.sh --build -f Dockerfile.custom \
  --tag codemate:java-php \
  --branch feature/backend-refactor
```

### Example 11: Working with Multiple Repositories

```bash
# Work on frontend repo
./start.sh --repo https://github.com/myorg/frontend.git \
  --branch feature/new-ui

# In another terminal, work on backend repo
./start.sh --repo https://github.com/myorg/backend.git \
  --branch feature/new-api
```

### Example 12: Using Chinese Mirror for Faster Downloads

```bash
# For users in China, use DaoCloud mirror
./start.sh --branch feature/optimization \
  --image ghcr.m.daocloud.io/boringhappy/codemate:latest
```

## Custom Configurations

### Example 13: Setting Up Slack Notifications

Edit your `.env` file:

```bash
# .env
SLACK_WEBHOOK=https://hooks.slack.com/services/YOUR/WEBHOOK/URL
```

Now you'll receive Slack notifications when Claude stops or encounters issues.

### Example 14: Using Custom Anthropic API Endpoint

```bash
# .env
ANTHROPIC_BASE_URL=https://your-proxy.example.com
ANTHROPIC_AUTH_TOKEN=your-api-token
```

Useful for:
- Corporate API proxies
- Custom rate limiting
- Regional endpoints

### Example 15: Repository Auto-Detection

```bash
# In a git repository directory
cd ~/projects/my-app

# No need to specify --repo, it auto-detects from git remote
./start.sh --branch feature/quick-fix

# Priority order:
# 1. --repo flag (if provided)
# 2. GIT_REPO_URL in .env
# 3. Current directory's git remote origin
```

## Workflow Tips

### Tip 1: Iterative Development

```bash
# Start with a query
./start.sh --branch feature/search \
  --query "Implement basic search functionality"

# After Claude implements, continue in the same session:
# "Add pagination to the search results"
# "Add filters for date range"
# "Add unit tests"
```

### Tip 2: Code Review Workflow

```bash
# Reviewer leaves comments on PR #999
# Start CodeMate
./start.sh --pr 999

# The monitor detects comments automatically
# Or manually trigger:
# /pr:fix-comments

# After fixes, update PR description:
# /pr:update --summary-only
```

### Tip 3: Commit Strategy

```bash
./start.sh --branch feature/refactor

# Tell Claude:
# "Refactor the authentication module. Make small, logical commits."

# Claude will use /git:commit after each logical change
# Result: Clean git history with meaningful commit messages
```

### Tip 4: Working with PR Templates

Create `.github/PULL_REQUEST_TEMPLATE.md` in your repo:

```markdown
## Summary
<!-- What does this PR do? -->

## Changes
<!-- List of changes -->

## Testing
<!-- How to test -->

## Screenshots
<!-- If applicable -->
```

When Claude creates a PR, it will automatically use this template and fill it out based on the changes made.

## Troubleshooting Examples

### Example 16: Debugging Container Issues

```bash
# Build locally to debug
./start.sh --build --branch debug/container-issue

# Inside container, check logs:
# cat /tmp/setup.log
# cat /tmp/repo-setup.log
```

### Example 17: Testing Plugin Installation

```bash
./start.sh --branch test/plugins

# Inside container, verify plugins:
# claude plugin list

# Should show:
# - git@codemate
# - pr@codemate
# - agent-browser
```

## Real-World Scenarios

### Scenario 1: Full Feature Implementation

```bash
# GitHub Issue #123: "Add user profile page"
./start.sh --issue 123

# Claude will:
# 1. Read issue details
# 2. Create profile page component
# 3. Add routing
# 4. Implement API endpoints
# 5. Add tests
# 6. Commit with /git:commit
# 7. Update PR description with /pr:update
```

### Scenario 2: Emergency Hotfix

```bash
# Production bug reported
./start.sh --branch hotfix/critical-security-fix \
  --query "Fix SQL injection vulnerability in user search endpoint"

# Claude will:
# 1. Locate the vulnerable code
# 2. Implement parameterized queries
# 3. Add input validation
# 4. Create tests
# 5. Commit and push immediately
```

### Scenario 3: Refactoring Legacy Code

```bash
./start.sh --branch refactor/modernize-auth

# Tell Claude:
# "Refactor the authentication system to use modern best practices.
# Make incremental changes with tests at each step."

# Claude will:
# 1. Analyze current code
# 2. Plan refactoring steps
# 3. Make changes incrementally
# 4. Run tests after each change
# 5. Commit logical chunks
```

## Summary

CodeMate streamlines your development workflow by:
- Automating repository and PR setup
- Handling Git operations automatically
- Monitoring and responding to PR feedback
- Providing isolated environment for AI pair programming

For more details, see the [README.md](README.md).

