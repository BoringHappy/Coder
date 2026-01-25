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

### Container Startup Flow

1. `setup/setup.sh` orchestrates initialization
2. `setup/shell/setup-git.sh` configures git user from environment variables
3. `setup/shell/setup-gh.sh` authenticates GitHub CLI with token
4. `setup/setup.sh` configures the CodeMate plugin marketplace in `.claude/settings.json`
5. `setup/python/setup-repo.py` clones repo, checks out branch/PR, creates PR if needed
6. Claude Code starts with system prompt from `setup/prompt/system_prompt.txt`

### Plugin Marketplace

CodeMate uses a local plugin marketplace to distribute plugins. The marketplace is automatically configured at startup via `.claude/settings.json`.

**Marketplace Structure** (`marketplace/`):
- `.claude-plugin/marketplace.json` - Marketplace catalog
- `plugins/pr/` - PR workflow plugin
- `plugins/external/` - External tools plugin

**Available Plugins:**

**PR Plugin** (`pr@codemate`):
- `/pr:get-details` - Fetch PR information including comments
- `/pr:commit` - Stage, commit, and push changes
- `/pr:fix-comments` - Address PR review feedback
- `/pr:update` - Update PR title and summary

**External Plugin** (`external@codemate`):
- `/agent-browser` - Browser automation for web testing and interaction
- `/skill-creator` - Guide for creating new skills

### Key Files

- `Dockerfile` - Container definition, uses `docker/sandbox-templates:claude-code` base
- `start.sh` - Standalone script to run CodeMate with configuration management
- `setup/python/setup-repo.py` - Main repo/PR setup logic, reads PR template from `.github/PULL_REQUEST_TEMPLATE.md`

## Development Notes

- No test suite exists - this is infrastructure/tooling
- GitHub Actions workflow (`docker-build-push.yml`) builds and pushes to GHCR on main branch and tags
- Multi-platform builds: linux/amd64 and linux/arm64
