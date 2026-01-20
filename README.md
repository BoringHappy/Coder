# Coder

A secure Docker-based development environment supporting multiple AI coding agents (Claude Code, GitHub Copilot) with elevated execution privileges in isolated containers.

## Features

- **Multiple AI Agents**: Choose between Claude Code, GitHub Copilot CLI
- **Secure Isolation**: Each agent runs inside a Docker container, protecting your host system
- **Flexible Tech Stacks**: Configurable base image with optional Go, Node.js, Python, and Rust
- **Complete Dev Environment**: Pre-installed with essential development tools
- **Shell**: zsh with Oh My Zsh for enhanced terminal experience
- **Git Integration**: Mounted `.gitconfig` and GitHub CLI configuration
- **Persistent Storage**: Agent configurations and workspace data persist across container restarts

## Available Variants

### Claude Code (Full Stack)
- **Languages**: Go, Node.js, Python, Rust
- **Tools**: All development tools + Claude Code CLI
- **Use Case**: Full-featured AI-assisted development

### GitHub Copilot (Node.js)
- **Languages**: Node.js
- **Tools**: Core tools + GitHub Copilot CLI
- **Use Case**: JavaScript/TypeScript development with Copilot

### Base (Customizable)
- **Languages**: Configurable (Go, Node.js, Python, Rust)
- **Tools**: Core development tools only
- **Use Case**: Custom builds with specific tech stacks

## What's Included

### Core Development Tools (All Variants)
- Git + GitHub CLI (gh)
- vim, tmux
- ripgrep, jq, tree
- make, curl, wget
- htop, ncdu
- SSH client, telnet, ping
- zsh with Oh My Zsh

### Programming Languages (Variant-Specific)
See "Available Variants" section above for language support per variant.

## Quick Start

### Using Pre-built Images

**Claude Code (Full Stack - Recommended):**
```bash
# Pull the full-featured Claude Code image (default/latest)
docker pull ghcr.io/boringhappy/coder:main
# or
docker pull ghcr.io/boringhappy/coder:latest

# Run Claude Code
docker run -it --rm \
  -v $(pwd):/home/agent/workspace \
  -v ~/.claude:/home/agent/.claude \
  -v ~/.gitconfig:/home/agent/.gitconfig:ro \
  -v ~/.config/gh:/home/agent/.config/gh:ro \
  -e ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY \
  ghcr.io/boringhappy/coder:main
```

**Other Available Tags:**
- `ghcr.io/boringhappy/coder:main` or `:latest` - Claude Code (default)
- `ghcr.io/boringhappy/coder:main-claude` - Claude Code (explicit)
- `ghcr.io/boringhappy/coder:main-codex` - GitHub Copilot CLI (Node.js)
- `ghcr.io/boringhappy/coder:main-base` - Base image (customizable)
- `ghcr.io/boringhappy/coder:v1.0.0` - Claude Code release (default)
- `ghcr.io/boringhappy/coder:v1.0.0-<variant>` - Specific variant release
- `ghcr.io/boringhappy/coder:sha-<commit>-<variant>` - Specific commit builds

**Quick Examples for Other Variants:**

```bash
# GitHub Copilot
docker run -it --rm \
  -v $(pwd):/home/agent/workspace \
  -e GITHUB_TOKEN=$GITHUB_TOKEN \
  ghcr.io/boringhappy/coder:main-codex
```

### Using Docker Compose

Download the complete configuration:

```bash
curl -O https://raw.githubusercontent.com/boringhappy/coder/main/docker-compose.yml
```

Or create a minimal `docker-compose.yml`:

```yaml
services:
  claude:
    image: ghcr.io/boringhappy/coder:main
    stdin_open: true
    tty: true
    volumes:
      - .:/home/agent/workspace
      - ~/.claude:/home/agent/.claude
      - ~/.gitconfig:/home/agent/.gitconfig:ro
      - ~/.config/gh:/home/agent/.config/gh:ro
    environment:
      - ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
    working_dir: /home/agent/workspace
```

Run:

```bash
# Claude Code
docker compose run --rm claude

# GitHub Copilot
docker compose run --rm codex

# Or run zsh shell
docker compose run --rm claude zsh
```

## Building Custom Variants

Use the base image with build arguments:

```bash
# Build with only Python and Node.js
docker build -f Dockerfile.base \
  --build-arg BASE_IMAGE=ubuntu:25.10 \
  --build-arg INSTALL_GO=false \
  --build-arg INSTALL_NODE=true \
  --build-arg INSTALL_PYTHON=true \
  --build-arg INSTALL_RUST=false \
  -t my-custom-coder .

# Or use Alpine Linux
docker build -f Dockerfile.base \
  --build-arg BASE_IMAGE=alpine:latest \
  -t my-alpine-coder .
```

## Volume Mounts

- `.:/home/agent/workspace` - Current directory as workspace
- `~/.claude:/home/agent/.claude` - Claude configuration (Claude variant only)
- `~/.gitconfig:/home/agent/.gitconfig:ro` - Git configuration (read-only)
- `~/.config/gh:/home/agent/.config/gh:ro` - GitHub CLI authentication (read-only)

## Environment Variables

- `ANTHROPIC_API_KEY` - Required for Claude Code variant
- `GITHUB_TOKEN` - Required for GitHub Copilot variant

## Security Notes

- All containers run as non-root user `agent` (UID 1000) with sudo access
- Git and GitHub CLI configs are mounted read-only
- Claude Code runs with `--dangerously-skip-permissions` flag for convenience
- Each variant is isolated in its own container

## License

MIT
