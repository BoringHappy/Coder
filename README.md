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

When `--build` is used:
1. The script builds the Docker image from the specified Dockerfile
2. The default image tag is `codemate:local` (unless `--tag` is specified)
3. The locally built image is used instead of pulling from the registry
4. The `--image` option is ignored when `--build` is used

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

## Skills

Built-in Claude Code skills to streamline PR workflows:

| Skill | Command | Description |
|-------|---------|-------------|
| Update PR | `/update-pr` | Updates PR title and summary based on changes. Use `--summary-only` to skip title update |
| Fix PR Comments | `/fix-pr-comments` | Addresses PR review feedback, commits fixes, and replies to comments |
| Git Commit | `/git-commit` | Stages all changes, commits with a meaningful message, and pushes to remote |
| Get PR Details | `/get-pr-details` | Gets details of a GitHub pull request including title, description, file changes, and review comments |
| Agent Browser | `/agent-browser` | Automates browser interactions for web testing, form filling, screenshots, and data extraction |
| Skill Creator | `/skill-creator` | Guide for creating effective skills with templates, validation tools, and documentation |

### Custom Skills

You can override the default skills by mounting your own skills directory:

```bash
# Create a custom skills directory in your project
mkdir -p skills/my-custom-skill

# Mount it when running CodeMate
./start.sh --branch feature/xyz --mount ./skills:/home/agent/.claude/skills
```

When a custom skills directory is mounted, the default skills will not be copied, allowing you to use your own skill set. You can also copy the default skills from the repository and modify them as needed.

### External Skills

The following skills are **pre-installed** in CodeMate and ready to use. The commands below show their original sources for reference:

- **agent-browser**: Imported from [vercel-labs/agent-browser](https://github.com/vercel-labs/agent-browser)
- **skill-creator**: Imported from [anthropics/skills](https://github.com/anthropics/skills)

To update or customize these skills, use the Custom Skills approach described above by mounting your own skills directory.

## CI/CD

### Automated Submodule Updates

CodeMate includes a GitHub Actions workflow that automatically monitors and updates the marketplace submodule:

**Workflow: `.github/workflows/submodule-update.yml`**

- **Scheduled checks**: Runs daily at 00:00 UTC to check for marketplace updates
- **Push triggers**: Automatically triggers when marketplace submodule changes are pushed to main
- **Auto-update**: When updates are detected via scheduled check, automatically commits the new submodule reference
- **Docker rebuild**: Triggers the Docker image build workflow when submodule updates are detected

This ensures the Docker image always includes the latest plugins from the marketplace without manual intervention.

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
