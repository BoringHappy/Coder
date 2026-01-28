# CodeMate Usage Examples

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

### Example 2: Working on an Existing PR

```bash
# Continue work on PR #42
./start.sh --pr 42

# Claude will:
# 1. Fetch the PR branch
# 2. Check out the code
# 3. Be ready to continue development

# Example conversation:
# You: "Please add unit tests for the authentication module"
# Claude: [Analyzes code, writes tests, commits changes]
```

### Example 3: Quick Bug Fix with Initial Query

```bash
# Start with a specific task
./start.sh --branch fix/login-timeout --query "Fix the login timeout issue in auth.js"

# Claude will immediately start working on the issue
```

## PR Management

### Example 4: Addressing Review Comments

When reviewers leave comments on your PR, CodeMate automatically detects them:

```bash
# Start CodeMate on your PR
./start.sh --pr 123

# When review comments arrive, the monitor will notify Claude
# Claude will automatically use /pr:fix-comments to:
# 1. Read all review comments
# 2. Fix the issues
# 3. Commit and push changes
# 4. Reply to each comment
```

**Manual approach:**

```bash
# Inside the container, you can manually trigger:
/pr:fix-comments
```

### Example 5: Updating PR Description

```bash
./start.sh --pr 123

# Inside the container:
# You: "Please update the PR summary to reflect the recent changes"
# Claude: [Uses /pr:update to regenerate the PR description]

# Or update manually:
/pr:update --summary-only
```

### Example 6: Getting PR Details

```bash
./start.sh --pr 123

# Inside the container:
/pr:get-details

# Claude will show:
# - PR title and description
# - Files changed
# - Review comments
# - Current status
```

## Issue-Based Development

### Example 7: Implementing a Feature from an Issue

```bash
# Start work directly from issue #456
./start.sh --issue 456

# CodeMate will:
# 1. Create branch "issue-456"
# 2. Automatically read the issue using /pr:read-issue
# 3. Claude analyzes the requirements
# 4. Claude implements the feature
# 5. Creates a PR when ready
```

**Example issue workflow:**

```
Issue #456: Add dark mode support
Description: Users want a dark theme option in the settings page

# After running: ./start.sh --issue 456
# Claude will:
# - Read the issue details
# - Analyze the codebase
# - Implement dark mode toggle
# - Add CSS for dark theme
# - Update settings page
# - Commit and create PR
```

### Example 8: Bug Fix from Issue

```bash
./start.sh --issue 789

# Issue #789: Login button not working on mobile
# Claude will:
# 1. Read issue description and comments
# 2. Investigate the mobile-specific code
# 3. Identify the responsive design issue
# 4. Fix the CSS/JavaScript
# 5. Test the fix
# 6. Commit and create PR
```

## Advanced Scenarios

### Example 9: Multi-Repository Setup

```bash
# Work on different repositories from the same machine
cd ~/projects/frontend
./start.sh --branch feature/new-ui

# In another terminal
cd ~/projects/backend
./start.sh --branch feature/api-endpoint

# Each container works independently with its own repository
```

### Example 10: Custom Volume Mounts

```bash
# Mount local data directory for testing
./start.sh --branch feature/data-import \
  --mount ~/test-data:/data \
  --mount ~/.aws:/home/agent/.aws:ro

# Inside container, Claude can access:
# - /data (your test data)
# - /home/agent/.aws (AWS credentials, read-only)
```

### Example 11: Using Custom Docker Image

```bash
# For Chinese users or custom registries
./start.sh --branch feature/xyz \
  --image ghcr.m.daocloud.io/boringhappy/codemate:latest

# Or use a custom-built image
./start.sh --branch feature/xyz \
  --image myregistry.com/codemate:custom
```

### Example 12: Building with Custom Toolchains

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

Build and run:

```bash
./start.sh --build -f Dockerfile.custom --tag codemate:java-php --branch feature/xyz
```

## Custom Configurations

### Example 13: Slack Notifications

Get notified when Claude stops or needs attention:

```bash
# Add to your .env file
SLACK_WEBHOOK=https://hooks.slack.com/services/YOUR/WEBHOOK/URL

./start.sh --branch feature/xyz

# You'll receive Slack notifications when:
# - Claude finishes a task
# - Claude encounters an error
# - Claude needs your input
```

### Example 14: Custom API Endpoint

Use a custom Anthropic API endpoint:

```bash
# Add to your .env file
ANTHROPIC_BASE_URL=https://api.custom-proxy.com
ANTHROPIC_AUTH_TOKEN=your-custom-token

./start.sh --branch feature/xyz
```

### Example 15: Repository Auto-Detection

```bash
# Option 1: Explicit repo URL
./start.sh --repo https://github.com/user/repo.git --branch feature/xyz

# Option 2: Set in .env file
echo "GIT_REPO_URL=https://github.com/user/repo.git" >> .env
./start.sh --branch feature/xyz

# Option 3: Auto-detect from current directory
cd ~/projects/my-repo
./start.sh --branch feature/xyz
# CodeMate automatically uses the git remote origin URL
```

## Real-World Workflow Examples

### Example 16: Complete Feature Development

```bash
# Day 1: Start feature
./start.sh --issue 100
# You: "Implement the user profile page as described in the issue"
# Claude: [Implements feature, creates PR]

# Day 2: Address review feedback
./start.sh --pr 150
# Reviewer leaves comments on GitHub
# Claude automatically fixes issues and replies

# Day 3: Final touches
./start.sh --pr 150
# You: "Add error handling for edge cases"
# Claude: [Adds error handling, commits]

# You: "Update the PR description"
# Claude: [Uses /pr:update]
```

### Example 17: Refactoring Session

```bash
./start.sh --branch refactor/cleanup-auth --query "Please refactor the authentication module to use async/await instead of callbacks"

# Claude will:
# 1. Analyze the current auth code
# 2. Create a refactoring plan
# 3. Convert callbacks to async/await
# 4. Update tests
# 5. Verify everything works
# 6. Commit changes
# 7. Create PR with detailed description
```

### Example 18: Emergency Hotfix

```bash
# Quick fix for production issue
./start.sh --branch hotfix/critical-bug \
  --query "Fix the null pointer exception in payment processing (line 234 of payment.js)"

# Claude immediately:
# 1. Reads the file
# 2. Identifies the issue
# 3. Applies the fix
# 4. Commits with descriptive message
# 5. Creates PR for review
```

## Tips and Best Practices

### Effective Prompts

**Good prompts:**
```
"Add input validation to the login form"
"Refactor the database queries to use prepared statements"
"Write unit tests for the UserService class"
"Fix the memory leak in the WebSocket connection handler"
```

**Less effective prompts:**
```
"Make it better" (too vague)
"Fix everything" (too broad)
"Do something" (no clear goal)
```

### Using Skills Effectively

```bash
# Commit changes
/git:commit

# Get PR information
/pr:get-details

# Fix review comments
/pr:fix-comments

# Update PR description
/pr:update

# Acknowledge issue comments
/pr:ack-comments

# Read issue details
/pr:read-issue 123
```

### Monitoring and Debugging

```bash
# Check container logs
docker logs <container-id>

# Attach to running container
docker exec -it <container-id> /bin/zsh

# View tmux session
docker exec -it <container-id> tmux attach

# Check git status inside container
docker exec -it <container-id> git -C /home/agent/<repo-name> status
```

## Troubleshooting Examples

### Example 19: Permission Issues

```bash
# If you encounter permission errors
./start.sh --setup  # Recreate configuration files

# Verify GitHub token
gh auth status

# Verify git config
git config user.name
git config user.email
```

### Example 20: Network Issues

```bash
# Use mirror for faster downloads (China)
./start.sh --branch feature/xyz \
  --image ghcr.m.daocloud.io/boringhappy/codemate:latest

# Or build locally
./start.sh --build --branch feature/xyz
```

---

For more information, see the [README](README.md) or visit the [GitHub repository](https://github.com/BoringHappy/CodeMate).
