# CodeMate

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


## How It Works

On startup, the container:
1. Clones/updates repository to `/home/agent/<repo-name>`
2. Checks out specified branch or PR
3. Creates PR if working on new branch
4. Starts Claude Code with `--dangerously-skip-permissions` flag

## Tmux Integration

CodeMate uses tmux to provide session management and intelligent PR comment monitoring. Two tmux sessions are automatically created on startup:

### Sessions

**`claude-code` (main session)**
- Runs Claude Code interactively
- Automatically attached when container starts
- Detach with `Ctrl+b d` to leave Claude running in background
- Reattach with `tmux attach -t claude-code`

**`pr-monitor` (background session)**
- Monitors PR comments every 30 seconds
- Automatically detects new unsolved review comments
- Sends notification to Claude when comments are found (only when Claude is idle)
- Excludes comments already addressed by Claude (those starting with "Claude Replied:")

### How PR Comment Monitoring Works

1. Waits 60 seconds after startup for session initialization
2. Checks for new PR comments every 30 seconds
3. Only triggers when Claude is idle (session status shows "Stop")
4. Filters out:
   - Comments starting with "Claude Replied:"
   - Comment threads where the last reply is from Claude
   - Comments already checked in previous runs
5. Sends "Please Use /fix-comments skill to address comments" to Claude Code session

### Useful Commands

```bash
# List all tmux sessions
tmux ls

# Switch to PR monitor session (view monitoring logs)
tmux attach -t pr-monitor

# Switch back to Claude Code session
tmux attach -t claude-code

# Detach from current session (keeps it running)
# Press: Ctrl+b, then d

# Kill all tmux sessions
tmux kill-server
```

### Benefits

- **Persistent sessions**: Detach and reattach without interrupting Claude
- **Automated PR workflow**: Claude automatically addresses new review comments
- **Background monitoring**: PR comment checking runs independently
- **Session isolation**: Separate sessions keep monitor logs out of Claude's output

## Skills

CodeMate comes with pre-installed skills from the [CodeMatePlugin](https://github.com/BoringHappy/CodeMatePlugin) repository and [agent-browser](https://github.com/vercel-labs/agent-browser). These skills are automatically available when you start the container and provide workflow automation for Git, PR management, and browser interactions.

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
