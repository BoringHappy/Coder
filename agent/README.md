# Claude Code Agent

Python-controlled loop for automated PR comment handling using Claude Agent SDK.

## Features

- **Automated PR Monitoring**: Continuously monitors GitHub PR for new review comments
- **Claude Agent SDK Integration**: Uses Claude Agent SDK with full tool access (`*`)
- **Plugin Support**: Automatically loads all installed Claude Code plugins and skills
- **Dangerously Skip Permissions**: Implements `--dangerously-skip-permissions` behavior
- **Automated Comment Resolution**: Sends PR comments to Claude for automated fixes
- **Configurable**: Supports custom system prompts and check intervals

## Installation

The project uses `uv` for dependency management:

```bash
# Dependencies are already installed via uv
uv sync
```

## Usage

### Basic Usage

```bash
# Auto-detect repo and PR from current branch
./agent/claude_agent.py

# Specify repo and PR explicitly
./agent/claude_agent.py --repo owner/repo --pr 123

# Run once and exit (don't loop)
./agent/claude_agent.py --once
```

### Configuration Options

```bash
./agent/claude_agent.py \
  --api-key YOUR_API_KEY \
  --repo owner/repo \
  --pr 123 \
  --interval 60 \
  --system-prompt /path/to/prompt.txt \
  --once
```

**Arguments:**
- `--api-key`: Anthropic API key (default: `ANTHROPIC_API_KEY` env var)
- `--repo`: GitHub repository in `owner/repo` format (default: auto-detect)
- `--pr`: PR number (default: auto-detect from current branch)
- `--interval`: Check interval in seconds (default: 60)
- `--system-prompt`: Path to custom system prompt file
- `--once`: Run once and exit instead of continuous loop

### Environment Variables

```bash
export ANTHROPIC_API_KEY="your-api-key"
export GITHUB_REPOSITORY="owner/repo"  # Optional
export PR_NUMBER="123"  # Optional
```

## How It Works

1. **Initialization**:
   - Loads system prompt from file or default location
   - Discovers all available Claude Code tools (uses `*` for all tools)
   - Scans installed plugins to load available skills

2. **Monitoring Loop**:
   - Fetches PR comments using GitHub CLI (`gh`)
   - Identifies new comments since last check
   - Formats comments into queries for Claude

3. **Comment Handling**:
   - Sends formatted query to Claude Agent SDK
   - Claude has access to all tools and can make code changes
   - Optionally replies to comments when changes are made

4. **Plugin Support**:
   - Automatically detects installed plugins via `claude plugin list`
   - Loads skills from plugins (e.g., `/git:commit`, `/pr:fix-comments`)
   - Supports user-defined plugins and skills

## Architecture

### Components

- **GitHubPRMonitor**: Monitors PR for new comments using `gh` CLI
- **ClaudeCodeAgent**: Main agent that orchestrates the workflow
- **Claude Agent SDK**: Provides API access with tool support

### Tool Access

The agent uses `'*'` to enable all available Claude Code tools:
- File operations (Read, Write, Edit)
- Code search (Grep, Glob)
- Shell commands (Bash)
- Task management
- Web operations (WebFetch, WebSearch)
- All other Claude Code tools

### Plugin Loading

Plugins are loaded from Claude Code's plugin system:
```python
# Discovers plugins via CLI
claude plugin list

# Extracts skills from plugin output
# Example: git@codemate - /git:commit
```

## Integration with CodeMate

This agent can be integrated into the CodeMate Docker container:

1. Add to `Dockerfile`:
```dockerfile
# Install Python dependencies
COPY pyproject.toml uv.lock ./
RUN uv sync
```

2. Update `CMD` in Dockerfile:
```dockerfile
CMD ["uv", "run", "agent/claude_agent.py"]
```

3. Or run alongside existing Claude Code:
```bash
# Terminal 1: Run agent
uv run agent/claude_agent.py

# Terminal 2: Use Claude Code normally
claude --dangerously-skip-permissions
```

## Example Workflow

1. Developer creates PR with code changes
2. Reviewer adds comments on specific lines
3. Agent detects new comments
4. Agent formats comment into query:
   ```
   PR Review Comment from reviewer:

   File: src/main.py
   Line: 42

   Comment:
   This function should handle the edge case when input is None

   Please address this review comment by making the necessary code changes.
   ```
5. Claude receives query with full tool access
6. Claude reads the file, makes changes, commits
7. Agent replies to comment confirming changes

## Development

### Project Structure

```
agent/
├── claude_agent.py    # Main agent implementation
└── README.md          # This file

pyproject.toml         # uv project configuration
uv.lock               # Dependency lock file
```

### Testing

```bash
# Test with --once flag
uv run agent/claude_agent.py --once

# Test with specific PR
uv run agent/claude_agent.py --repo owner/repo --pr 123 --once
```

## Security Considerations

- **API Key**: Store `ANTHROPIC_API_KEY` securely
- **Permissions**: Agent has full tool access (`--dangerously-skip-permissions`)
- **GitHub Token**: Requires `gh` CLI authentication
- **Automated Changes**: Review agent changes before merging

## Troubleshooting

### "Could not determine PR number"
- Ensure you're in a git repository with a PR
- Or set `PR_NUMBER` environment variable
- Or use `--pr` flag

### "ANTHROPIC_API_KEY not set"
- Set environment variable: `export ANTHROPIC_API_KEY="..."`
- Or use `--api-key` flag

### "Failed to fetch PR comments"
- Ensure `gh` CLI is authenticated: `gh auth status`
- Check repository access permissions

### Plugin/Skill Loading Issues
- Verify plugins are installed: `claude plugin list`
- Check plugin installation: `claude plugin install <plugin>`
