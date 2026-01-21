# Coder

Docker-based Claude Code environment with automated Git/PR setup.

> **⚠️ Security Notice:** This container runs with `--dangerously-skip-permissions` by default, allowing Claude to execute commands without confirmation. Use only in isolated environments with trusted repositories.

## Features

- Automated repository cloning and PR management
- Pre-installed: Go, Node.js, Python, Rust
- zsh with Oh My Zsh
- Persistent Claude configuration

## Quick Start

### Prerequisites

- Docker and Docker Compose
- Git configured (`~/.gitconfig`)
- GitHub CLI authenticated (`~/.config/gh`)
- Claude Code settings (`~/.claude/settings.json`) with API key configured

### Usage

#### Docker Compose
Create `docker-compose.yml`:

```yaml
services:
  claude:
    image: ghcr.io/boringhappy/coder:main
    container_name: claude-dev
    stdin_open: true
    tty: true
    volumes:
      - ~/.claude:/home/agent/.claude   # Better to use another local folder
      - ~/.gitconfig:/home/agent/.gitconfig:ro
      - ~/.config/gh:/home/agent/.config/gh:ro
    environment:
      - GIT_REPO_URL=https://github.com/your-org/your-repo.git
      - PR_TITLE=Work on feature/your-branch
      - BRANCH_NAME=feature/your-branch  # or PR_NUMBER=123
    working_dir: /home/agent/workspace
```

With docker-compose:
```bash
docker compose run --rm claude
```

#### Docker Run
```bash
docker run -it --rm \
  -v ~/.claude:/home/agent/.claude \   # Better to use another local folder
  -v ~/.gitconfig:/home/agent/.gitconfig:ro \
  -v ~/.config/gh:/home/agent/.config/gh:ro \
  -e GIT_REPO_URL=https://github.com/your-org/your-repo.git \
  -e PR_TITLE="Work on feature/your-branch" \
  -e BRANCH_NAME=feature/your-branch \
  -w /home/agent/workspace \
  claude-dev
```

## Environment Variables

- `GIT_REPO_URL` - [Required]Repository URL
- `PR_TITLE` - [Required]Title for new PRs
- `BRANCH_NAME` - Branch to work on
- `PR_NUMBER` - Existing PR number (alternative to BRANCH_NAME)


## How It Works

On startup, the container:
1. Clones/updates repository to `/home/agent/workspace`
2. Checks out specified branch or PR
3. Creates PR if working on new branch
4. Starts Claude Code

## License

MIT
