# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CodeMate is a Docker-based environment for running Claude Code with automated Git/PR setup. It runs Claude with `--dangerously-skip-permissions` in an isolated container, enabling AI pair programming without constant approval prompts.

## Running CodeMate

```bash
# Run with branch name (auto-detects repo from: --repo > .env > current directory's git remote)
./start.sh --branch feature/your-branch

# Run with explicit repo URL
./start.sh --repo https://github.com/your-org/your-repo.git --branch feature/xyz

# Run with existing PR
./start.sh --pr 123

# Run with custom volume mounts
./start.sh --branch feature/xyz --mount /local/path:/container/path
```

Parameters:
- `--repo` - Repository URL (optional, auto-detects from .env or git remote)
- `--branch` - Branch to work on
- `--pr` - Existing PR number (alternative to --branch)
- `--mount` - Additional volume mounts (can be specified multiple times)

## Architecture

### Python Agent (New Feature)

CodeMate now includes a Python-controlled agent loop that implements `--dangerously-skip-permissions` functionality with automated PR comment monitoring:

**Location**: `agent/claude_agent.py`

**Features**:
- Automated PR comment monitoring using GitHub CLI
- Claude Agent SDK integration with full tool access (`*`)
- Automatic plugin and skill loading
- Configurable check intervals
- Can run standalone or integrated into Docker container

**Usage**:
```bash
# Run agent directly
uv run agent/claude_agent.py

# Run with specific PR
uv run agent/claude_agent.py --repo owner/repo --pr 123

# Run once and exit
uv run agent/claude_agent.py --once
```

See `agent/README.md` for detailed documentation and `agent/DOCKER_INTEGRATION.md` for Docker integration options.

### Container Startup Flow

1. `setup/setup.sh` orchestrates initialization
2. `setup/shell/setup-git.sh` configures git user from environment variables
3. `setup/shell/setup-gh.sh` authenticates GitHub CLI with token
4. `setup/python/setup-repo.py` clones repo, checks out branch/PR, creates PR if needed
5. Claude Code starts with system prompt from `setup/prompt/system_prompt.txt`

### Plugin Marketplace

CodeMate uses the CodeMatePlugin marketplace to distribute plugins. Plugins are installed at runtime during container startup via `setup/shell/setup-plugins.sh` using the `claude plugin` CLI commands.

The marketplace is fetched from the external repository: `BoringHappy/CodeMatePlugin`

**Available Plugins:**

**Git Plugin** (`git@codemate`):
- `/git:commit` - Stage, commit, and push changes

**PR Plugin** (`pr@codemate`):
- `/pr:get-details` - Fetch PR information including comments
- `/pr:fix-comments` - Address PR review feedback
- `/pr:update` - Update PR title and summary

### Key Files

- `Dockerfile` - Container definition, uses `docker/sandbox-templates:claude-code` base
- `start.sh` - Standalone script to run CodeMate with configuration management
- `setup/python/setup-repo.py` - Main repo/PR setup logic, reads PR template from `.github/PULL_REQUEST_TEMPLATE.md`
- `agent/claude_agent.py` - Python agent for automated PR comment handling
- `agent/README.md` - Agent documentation
- `agent/DOCKER_INTEGRATION.md` - Docker integration guide
- `pyproject.toml` - Python project configuration with uv


## Development Notes

- No test suite exists - this is infrastructure/tooling
- GitHub Actions workflow (`docker-build-push.yml`) builds and pushes to GHCR on main branch and tags
- Multi-platform builds: linux/amd64 and linux/arm64
