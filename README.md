# CodeMate

English | [简体中文](README_CN.md)

Docker-based Claude Code environment with automated Git/PR setup.

> **⚠️ Security Notice:** This container runs with `--dangerously-skip-permissions` by default, allowing Claude to execute commands without confirmation. Use only in isolated environments with trusted repositories.

## Why CodeMate?

Tired of approving every single command when pair programming with AI? Yet hesitant to grant full bypass permissions on your local machine? Every GitHub interaction requiring manual confirmation breaks your flow.

CodeMate solves this by running Claude Code in an isolated Docker container where it can operate freely without compromising your system. True pair programming starts here—let Claude focus on coding while you focus on the bigger picture.

## Features

- Automated repository cloning and PR management
- Pre-installed: Go, Node.js, Python, Rust, uv
- zsh with Oh My Zsh
- Persistent Claude configuration
- Built-in Claude Code skills for PR workflow automation
- Slack notifications when Claude stops (via `SLACK_WEBHOOK`)
- tmux session management with PR comment monitoring

## Quick Start

### Prerequisites

- Docker
- GitHub CLI (`gh`) authenticated
- Anthropic API key

Run `./start.sh --setup` to create the required configuration files (`.env`, `settings.json`, etc.)

#### Mac Users

On macOS, you need a Docker runtime since Docker doesn't run natively. Choose one:

- **[Docker Desktop](https://www.docker.com/products/docker-desktop/)** - Official Docker GUI application
- **[Colima](https://github.com/abiosoft/colima)** - Lightweight Docker runtime (recommended for CLI users)

### Usage

#### Using start.sh (Recommended)

The easiest way to run CodeMate from any directory:

```bash
# Download the start.sh script
curl -O https://raw.githubusercontent.com/BoringHappy/CodeMate/main/start.sh
chmod +x start.sh

# First time setup - creates configuration files in current directory
./start.sh --setup

# Run with explicit repo URL
./start.sh --repo https://github.com/your-org/your-repo.git --branch feature/xyz

# Run with branch name (auto-detects repo from: --repo > .env > current directory's git remote)
./start.sh --branch feature/your-branch

# Run with existing PR
./start.sh --pr 123

# Run with custom volume mounts (optional)
./start.sh --branch feature/xyz --mount ~/data:/data

# Run with initial query to Claude
./start.sh --branch feature/xyz --query "Please review the code and fix any issues"

# Build and run from local Dockerfile
./start.sh --build --branch feature/xyz

# Build with custom Dockerfile path and tag
./start.sh --build -f ./custom/Dockerfile --tag my-codemate:v1 --branch feature/xyz

# For Chinese users: Use DaoCloud mirror for faster image pulls
./start.sh --branch feature/xyz --image ghcr.m.daocloud.io/boringhappy/codemate:latest
```

The script will:
1. Prompt you to create configuration files if they don't exist
2. Create `.claude_in_docker/`, `.claude_in_docker.json`, `settings.json`, and `.env` in your current directory
3. Run the CodeMate container with your configuration

**Repository URL Resolution**: The script determines the repository URL in this priority order:
1. `--repo` command-line argument (highest priority)
2. `GIT_REPO_URL` environment variable or `.env` file
3. Current directory's git remote origin URL (auto-detected)
4. If none are available, an error is raised

##### Custom Volume Mounts

Use `--mount <host-path>:<container-path>` to mount additional directories or files. Useful for sharing data, configurations, or credentials with the container. Multiple `--mount` options can be specified.

##### Building from Local Dockerfile

For development or customization, you can build CodeMate from a local Dockerfile:

```bash
# Build from default Dockerfile in current directory
./start.sh --build --branch feature/xyz

# Build from custom Dockerfile path
./start.sh --build -f ./path/to/Dockerfile --branch feature/xyz

# Build with custom image tag
./start.sh --build --tag my-codemate:dev --branch feature/xyz

# Combine all options
./start.sh --build -f ./custom/Dockerfile --tag my-codemate:v1 --branch feature/xyz
```

**Options:**
- `--build` - Build Docker image from local Dockerfile before running
- `-f, --dockerfile PATH` - Path to Dockerfile (default: `Dockerfile`)
- `--tag TAG` - Image tag for local build (default: `codemate:local`)
  - **Note:** Only works with `--build`. To use a pre-built image, use `--image` instead

When `--build` is used:
1. The script builds the Docker image from the specified Dockerfile
2. The default image tag is `codemate:local` (unless `--tag` is specified)
3. The locally built image is used instead of pulling from the registry
4. The `--image` option is ignored when `--build` is used

**Adding Custom Toolchains:**

To add additional toolchains or tools to the container, create a custom Dockerfile that extends the base image:

```dockerfile
# Custom Dockerfile with additional toolchains
FROM ghcr.io/boringhappy/codemate:latest

# Add Java
RUN apt-get update && apt-get install -y openjdk-17-jdk maven

# Add PHP
RUN apt-get install -y php php-cli php-mbstring composer

# Add Ruby
RUN apt-get install -y ruby-full
RUN gem install bundler

# Add any other tools you need
RUN apt-get install -y postgresql-client redis-tools

# Clean up
RUN apt-get clean && rm -rf /var/lib/apt/lists/*
```

Then build and run with your custom Dockerfile:

```bash
./start.sh --build -f ./Dockerfile.custom --tag codemate:custom --branch feature/xyz
```

## Environment Variables

> **Note:** When using `start.sh`, these variables are handled automatically through the setup process. This reference is primarily for advanced Docker usage or troubleshooting.

| Variable | Required | Description |
|----------|----------|-------------|
| `GIT_REPO_URL` | No | Repository URL (defaults to current repo's remote) |
| `GITHUB_TOKEN` | Auto | GitHub personal access token (defaults to `gh auth token` if not provided) |
| `GIT_USER_NAME` | Auto | Git commit author name (defaults to `git config user.name` if not provided) |
| `GIT_USER_EMAIL` | Auto | Git commit author email (defaults to `git config user.email` if not provided) |
| `CODEMATE_IMAGE` | No | Custom image (default: `ghcr.io/boringhappy/codemate:latest`) |
| `SLACK_WEBHOOK` | No | Slack Incoming Webhook URL for notifications when Claude stops |
| `ANTHROPIC_AUTH_TOKEN` | No | Anthropic API token (for custom API endpoints) |
| `ANTHROPIC_BASE_URL` | No | Anthropic API base URL (for custom API endpoints) |
| `QUERY` | No | Initial query to send to Claude after startup |


## How It Works

CodeMate uses a separate [base image (`codemate-base`)](https://github.com/BoringHappy/CodeMate/pkgs/container/codemate-base) that is rebuilt weekly to keep system packages and development tools up-to-date.

On startup, the container:
1. Clones/updates repository to `/home/agent/<repo-name>`
2. Checks out specified branch or PR
3. Creates PR if working on new branch
4. Starts Claude Code in a tmux session with `--dangerously-skip-permissions` flag
5. Sends initial query to Claude if `--query` is provided
6. Runs a cron job to monitor PR comments (every minute)

## Skills

[CodeMate](https://github.com/BoringHappy/CodeMate) comes with pre-installed skills from the [agent-browser](https://github.com/vercel-labs/agent-browser). These skills are automatically available when you start the container and provide workflow automation for Git, PR management, and browser interactions.

### Available Plugins

**Git Plugin** (`git@codemate`):
| Command | Description |
|---------|-------------|
| `/git:commit` | Stage all changes, create a commit with a meaningful message, and push to remote |

**PR Plugin** (`pr@codemate`):
| Command | Description |
|---------|-------------|
| `/pr:get-details` | Fetch PR information including title, description, file changes, and review comments |
| `/pr:fix-comments` | Read PR review comments, fix the issues, commit changes, and reply to comments |
| `/pr:update` | Update PR title and/or summary. Use `--summary-only` to update only the summary |
| `/pr:ack-comments` | Acknowledge PR issue comments by adding 👀 reaction |

**Browser Plugin** (`agent-browser`):
| Command | Description |
|---------|-------------|
| `/agent-browser` | Automate browser interactions for web testing, form filling, screenshots, and data extraction |

## PR Comment Monitoring

CodeMate automatically monitors PR comments and notifies Claude when new feedback arrives. A cron job runs every minute to check for new comments.

### Comment Types

GitHub PRs have two types of comments that CodeMate monitors:

| Type | Location | API Endpoint | Use Case |
|------|----------|--------------|----------|
| **Review Comments** | Files changed tab (inline) | `/pulls/{pr}/comments` | Code-specific feedback on particular lines |
| **Issue Comments** | Conversation tab | `/issues/{pr}/comments` | General discussion, questions, requests |

### Review Comments Workflow

When someone leaves a **review comment** (inline code comment):

1. Monitor detects unresolved review comments
2. Sends message to Claude: `"Please Use /fix-comments skill to address comments"`
3. Claude uses `/pr:fix-comments` skill to:
   - Read the feedback
   - Make code changes
   - Commit and push
   - Reply with "Claude Replied: ..." to mark as resolved

### Issue Comments Workflow

When someone leaves an **issue comment** (general PR comment):

1. Monitor detects new issue comments without 👀 reaction
2. Sends the actual comment content to Claude
3. Claude processes the request
4. Claude uses `/pr:ack-comments` skill to add 👀 reaction
5. Future runs skip comments with 👀 reaction

### Filtering Logic

Comments are filtered out if they:
- Start with "Claude Replied:" (already handled)
- Have 👀 reaction (already acknowledged)
- Were created by Claude itself

## Best Practices

### Add a Pull Request Template

Create `.github/PULL_REQUEST_TEMPLATE.md` in your target repository to standardize PR descriptions:

```markdown
## Summary
<!-- Brief description of changes -->

## Test Plan
<!-- How to verify the changes -->

## Checklist
- [ ] Tests added/updated
- [ ] Documentation updated
```

### Security Recommendations

- Run CodeMate only on trusted repositories
- Use short-lived GitHub tokens with minimal scopes
- Avoid mounting sensitive host directories
- Review changes before merging PRs created by Claude

## License

MIT
