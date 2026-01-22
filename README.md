# Coder

Docker-based Claude Code environment with automated Git/PR setup.

> **⚠️ Security Notice:** This container runs with `--dangerously-skip-permissions` by default, allowing Claude to execute commands without confirmation. Use only in isolated environments with trusted repositories.

## Why Coder?

Tired of approving every single command when pair programming with AI? Yet hesitant to grant full bypass permissions on your local machine? Every GitHub interaction requiring manual confirmation breaks your flow.

Coder solves this by running Claude Code in an isolated Docker container where it can operate freely without compromising your system. True pair programming starts here—let Claude focus on coding while you focus on the bigger picture.

## Features

- Automated repository cloning and PR management
- Pre-installed: Go, Node.js, Python, Rust
- zsh with Oh My Zsh
- Persistent Claude configuration
- Built-in Claude Code skills for PR workflow automation

## Quick Start

### Prerequisites

- Docker
- GitHub CLI (`gh`) authenticated
- Claude Code settings (`~/.claude_in_docker/settings.json`) with API key configured
- `~/.claude_in_docker.json` - Auto-generated on first run to store configuration and skip setup on subsequent runs

### Usage

#### Using Make (Recommended)

The easiest way to run - automatically uses your local git config and GitHub CLI token:

```bash
# Run with current repo (auto-detects remote origin)
make run BRANCH_NAME=feature/your-branch

# Or specify a different repo
make run GIT_REPO_URL=https://github.com/your-org/your-repo.git BRANCH_NAME=feature/your-branch

# Work on existing PR
make run PR_NUMBER=123

# Custom PR title (optional - defaults to branch name)
make run BRANCH_NAME=add-new-feature PR_TITLE="Add new feature"
```

Available parameters:
- `GIT_REPO_URL` - Repository URL (defaults to current repo's remote origin)
- `BRANCH_NAME` - Branch to work on
- `PR_NUMBER` - Existing PR number (alternative to BRANCH_NAME)
- `PR_TITLE` - PR title (optional, defaults to branch name with title case)

You can also use a `.env` file for additional environment variables.

#### Docker Run
```bash
docker run -it --rm \
  -v ~/.claude_in_docker:/home/agent/.claude \
  -e GIT_REPO_URL=https://github.com/your-org/your-repo.git \
  -e PR_TITLE="Work on feature/your-branch" \
  -e BRANCH_NAME=feature/your-branch \
  -e GITHUB_TOKEN=your_github_token \
  -e GIT_USER_NAME=your_name \
  -e GIT_USER_EMAIL=your_email@example.com \
  -w /home/agent/workspace \
  boringhappy/coder:main
```

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `GIT_REPO_URL` | No | Repository URL (defaults to current repo's remote) |
| `GITHUB_TOKEN` | Yes | GitHub personal access token |
| `GIT_USER_NAME` | Yes | Git commit author name |
| `GIT_USER_EMAIL` | Yes | Git commit author email |
| `BRANCH_NAME` | No | Branch to work on |
| `PR_NUMBER` | No | Existing PR number (alternative to BRANCH_NAME) |
| `PR_TITLE` | No | PR title (defaults to branch name with title case) |
| `CODER_IMAGE` | No | Custom image (default: `boringhappy/coder:main`) |


## How It Works

On startup, the container:
1. Clones/updates repository to `/home/agent/workspace`
2. Checks out specified branch or PR
3. Creates PR if working on new branch
4. Starts Claude Code

## Skills

Built-in Claude Code skills to streamline PR workflows:

| Skill | Command | Description |
|-------|---------|-------------|
| Update PR Summary | `/update-pr-summary` | Analyzes PR changes and generates an improved description |
| Update PR Title | `/update-pr-title` | Creates a concise, descriptive PR title based on changes |
| Fix PR Comments | `/fix-pr-comments` | Addresses PR review feedback, commits fixes, and replies to comments |

## Best Practices

### Add a Pull Request Template

Create `.github/pull_request_template.md` in your target repository to standardize PR descriptions:

```markdown
## Summary
<!-- Brief description of changes -->

## Test Plan
<!-- How to verify the changes -->

## Checklist
- [ ] Tests added/updated
- [ ] Documentation updated
```

### Use a `.env` File

Create a `.env` file in the Coder directory for persistent configuration:

```bash
GIT_REPO_URL=https://github.com/your-org/your-repo.git
GIT_USER_NAME=your_name
GIT_USER_EMAIL=your_email@example.com
```

Then run with: `make run BRANCH_NAME=feature/xyz`

### Add a `CLAUDE.md` File

Include a `CLAUDE.md` in your repository root to provide Claude with project-specific context:

```markdown
# Project Guidelines

## Build Commands
- `make build` - Build the project
- `make test` - Run tests

## Code Style
- Use conventional commits
- Follow existing patterns
```

### Security Recommendations

- Run Coder only on trusted repositories
- Use short-lived GitHub tokens with minimal scopes
- Avoid mounting sensitive host directories
- Review changes before merging PRs created by Claude

## License

MIT
