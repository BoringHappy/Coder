# Coder

A secure Docker-based development environment running Claude Code with elevated execution privileges in an isolated container.

## Features

- **Secure Isolation**: Claude Code runs inside a Docker container, protecting your host system
- **Complete Dev Environment**: Pre-installed with Go, Node.js, Python, Rust, and essential tools
- **Shell**: zsh with Oh My Zsh for enhanced terminal experience
- **Git Integration**: Mounted `.gitconfig` and GitHub CLI configuration
- **Persistent Storage**: Claude configuration and workspace data persist across container restarts

## What's Included

### Programming Languages
- Go
- Node.js + npm
- Python 3 + pip + uv
- Rust + Cargo

### Development Tools
- Git + GitHub CLI (gh)
- vim, tmux
- ripgrep, jq, tree
- make, curl, wget
- htop, ncdu
- SSH client, telnet, ping

### Shell
- zsh with Oh My Zsh
- Non-root user `agent` (UID 1000) with sudo access

## Quick Start

### Using Pre-built Image

```bash
# Pull the image
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

# Or run zsh shell
docker run -it --rm \
  -v $(pwd):/home/agent/workspace \
  -v ~/.claude:/home/agent/.claude \
  -v ~/.gitconfig:/home/agent/.gitconfig:ro \
  -v ~/.config/gh:/home/agent/.config/gh:ro \
  -e ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY \
  ghcr.io/boringhappy/coder:main zsh
```

### Using Docker Compose

Download the configuration:

```bash
curl -O https://raw.githubusercontent.com/boringhappy/coder/main/docker-compose.yml
```

Or create a `docker-compose.yml`:

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
# Start Claude Code
docker compose run --rm claude

# Or start zsh shell
docker compose run --rm claude zsh
```

## Volume Mounts

- `.:/home/agent/workspace` - Current directory as workspace
- `~/.claude:/home/agent/.claude` - Claude configuration and history
- `~/.gitconfig:/home/agent/.gitconfig:ro` - Git configuration (read-only)
- `~/.config/gh:/home/agent/.config/gh:ro` - GitHub CLI authentication (read-only)

## Environment Variables

- `ANTHROPIC_API_KEY` - Required for Claude Code

## Security Notes

- The container runs as non-root user `agent` (UID 1000) with sudo access
- Git and GitHub CLI configs are mounted read-only
- Claude Code runs with `--dangerously-skip-permissions` flag for convenience

## License

MIT
