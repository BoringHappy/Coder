# Coder

Docker-based Claude Code environment with automated Git/PR setup.

> **⚠️ Security Notice:** This container runs with `--dangerously-skip-permissions` by default, allowing Claude to execute commands without confirmation. Use only in isolated environments with trusted repositories.

## Features

- Automated repository cloning and PR management
- Pre-installed: Go, Node.js, Python, Rust
- zsh with Oh My Zsh
- Persistent Claude configuration
- Built-in Claude Code skills for PR workflow automation

## Quick Start

### Prerequisites

- Docker and Docker Compose
- GitHub personal access token
- Claude Code settings (`~/.claude/settings.json`) with API key configured

### Usage

#### Using Make (Recommended)

The easiest way to run - automatically uses your local git config and GitHub CLI token:

1. Create `.env` file:
```bash
GIT_REPO_URL=https://github.com/your-org/your-repo.git
BRANCH_NAME=feature/your-branch
PR_TITLE=Work on feature/your-branch
```

2. Run:
```bash
make run
```

This automatically sets `GIT_USER_NAME`, `GIT_USER_EMAIL` from your git config and `GITHUB_TOKEN` from `gh auth token`.

#### Docker Compose

1. Create `.env` file:
```bash
GITHUB_TOKEN=your_github_token
GIT_USER_NAME=your_name
GIT_USER_EMAIL=your_email@example.com
GIT_REPO_URL=https://github.com/your-org/your-repo.git
BRANCH_NAME=feature/your-branch
PR_TITLE=Work on feature/your-branch
```

2. Create `docker-compose.yml`:
```yaml
services:
  claude:
    image: ${CODER_IMAGE:-boringhappy/coder:main}
    container_name: claude-dev
    stdin_open: true
    tty: true
    volumes:
      - ~/.claude_in_docker:/home/agent/.claude
    environment:
      - GIT_REPO_URL=${GIT_REPO_URL}
      - BRANCH_NAME=${BRANCH_NAME}
      - PR_NUMBER=${PR_NUMBER:-}
      - PR_TITLE=${PR_TITLE}
      - GITHUB_TOKEN=${GITHUB_TOKEN}
      - GIT_USER_NAME=${GIT_USER_NAME}
      - GIT_USER_EMAIL=${GIT_USER_EMAIL}
    env_file:
      - .env
    working_dir: /home/agent/workspace
```

3. Run:
```bash
docker compose run --rm claude
```

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
| `GIT_REPO_URL` | Yes | Repository URL to clone |
| `PR_TITLE` | Yes | Title for new PRs |
| `GITHUB_TOKEN` | Yes | GitHub personal access token |
| `GIT_USER_NAME` | Yes | Git commit author name |
| `GIT_USER_EMAIL` | Yes | Git commit author email |
| `BRANCH_NAME` | No | Branch to work on |
| `PR_NUMBER` | No | Existing PR number (alternative to BRANCH_NAME) |
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

## License

MIT
