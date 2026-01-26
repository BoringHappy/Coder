# Docker Integration Guide

This guide explains how to integrate the Claude Code Agent into the CodeMate Docker container.

## Option 1: Replace Claude Code with Agent (Automated Mode)

Modify the `Dockerfile` to run the agent instead of interactive Claude Code:

```dockerfile
# Add Python dependencies installation
COPY pyproject.toml uv.lock ./
RUN uv sync

# Copy agent code
COPY agent /workspace/agent

# Update CMD to run agent
CMD ["sh", "-c", "/workspace/agent/run-agent.sh"]
```

Then update `start.sh` to pass environment variables:

```bash
docker run -it --rm \
  -e ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" \
  -e GITHUB_REPOSITORY="$REPO" \
  -e PR_NUMBER="$PR_NUMBER" \
  -v "$PWD:/workspace" \
  codemate
```

## Option 2: Run Agent Alongside Claude Code

Keep the existing Claude Code setup and run the agent in a separate process:

### Method A: Background Process

Add to `setup/setup.sh`:

```bash
# Start agent in background
if [ "$ENABLE_AGENT" = "true" ]; then
    printf "${CYAN}Starting Claude Code Agent in background...${RESET}\n"
    cd /workspace && uv run agent/claude_agent.py &
    AGENT_PID=$!
    echo $AGENT_PID > /tmp/agent.pid
fi
```

### Method B: Separate Terminal

Run in two terminals:

```bash
# Terminal 1: Start container with Claude Code
./start.sh --branch feature/xyz

# Terminal 2: Exec into container and run agent
docker exec -it <container-id> bash
cd /workspace
uv run agent/claude_agent.py
```

## Option 3: On-Demand Agent Execution

Create a skill that triggers the agent:

### Create `/agent:run` skill

File: `setup/skills/agent-run.sh`

```bash
#!/bin/bash
# Skill: /agent:run
# Description: Run Claude Code Agent once to check for new PR comments

cd /workspace
uv run agent/claude_agent.py --once
```

Then invoke with `/agent:run` in Claude Code.

## Environment Variables

The agent requires these environment variables:

| Variable | Required | Description | Default |
|----------|----------|-------------|---------|
| `ANTHROPIC_API_KEY` | Yes | Anthropic API key | - |
| `GITHUB_REPOSITORY` | No | Repository (owner/repo) | Auto-detect |
| `PR_NUMBER` | No | PR number | Auto-detect |
| `CHECK_INTERVAL` | No | Check interval (seconds) | 60 |
| `SYSTEM_PROMPT_PATH` | No | Custom system prompt | Default |
| `RUN_ONCE` | No | Run once and exit | false |
| `ENABLE_AGENT` | No | Enable agent in container | false |

## Configuration Examples

### Example 1: Automated PR Comment Handler

```bash
# .env file
ANTHROPIC_API_KEY=sk-ant-...
ENABLE_AGENT=true
CHECK_INTERVAL=30
```

```bash
# start.sh
./start.sh --pr 123 --env-file .env
```

### Example 2: Manual Agent Invocation

```bash
# Run agent once to process comments
docker exec -it codemate-container bash -c "cd /workspace && uv run agent/claude_agent.py --once"
```

### Example 3: Custom System Prompt

```bash
# Create custom prompt
cat > custom_prompt.txt << 'EOF'
You are an expert code reviewer assistant.
When addressing PR comments:
1. Read the relevant code carefully
2. Make minimal, focused changes
3. Add tests if needed
4. Commit with descriptive messages
EOF

# Run agent with custom prompt
uv run agent/claude_agent.py --system-prompt custom_prompt.txt
```

## Dockerfile Modifications

### Full Integration Example

```dockerfile
# ... existing Dockerfile content ...

# Switch to agent user for user-specific installations
USER agent

# ... existing installations ...

# Install uv and Python dependencies
RUN curl -LsSf https://astral.sh/uv/install.sh | sh \
    && echo 'eval "$(uv generate-shell-completion zsh)"' >> /home/agent/.zshrc

# Copy project files
COPY --chown=agent:agent pyproject.toml uv.lock ./
COPY --chown=agent:agent agent ./agent

# Install Python dependencies
RUN uv sync

# Copy setup scripts
COPY --chmod=755 setup /usr/local/bin/setup

ENTRYPOINT ["/usr/local/bin/setup/setup.sh"]

# Choose one of these CMD options:

# Option A: Interactive Claude Code (default)
CMD ["sh", "-c", "claude --dangerously-skip-permissions --append-system-prompt \"$(cat /usr/local/bin/setup/prompt/system_prompt.txt)\""]

# Option B: Automated Agent
# CMD ["sh", "-c", "cd /workspace && uv run agent/claude_agent.py"]

# Option C: Agent with fallback to Claude Code
# CMD ["sh", "-c", "if [ \"$ENABLE_AGENT\" = \"true\" ]; then cd /workspace && uv run agent/claude_agent.py; else claude --dangerously-skip-permissions --append-system-prompt \"$(cat /usr/local/bin/setup/prompt/system_prompt.txt)\"; fi"]
```

## Testing the Integration

### Test 1: Verify Agent Installation

```bash
docker exec -it codemate-container bash
cd /workspace
uv run agent/claude_agent.py --help
```

### Test 2: Run Agent Once

```bash
docker exec -it codemate-container bash
cd /workspace
uv run agent/claude_agent.py --once
```

### Test 3: Check Agent Logs

```bash
docker logs -f codemate-container
```

## Monitoring and Debugging

### View Agent Status

```bash
# Check if agent is running
docker exec codemate-container ps aux | grep claude_agent

# View agent logs
docker exec codemate-container tail -f /tmp/agent.log
```

### Debug Mode

Add logging configuration:

```python
# In claude_agent.py
logging.basicConfig(
    level=logging.DEBUG,  # Change to DEBUG
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/tmp/agent.log'),
        logging.StreamHandler()
    ]
)
```

## Best Practices

1. **API Key Security**: Never commit API keys. Use environment variables or secrets management.

2. **Rate Limiting**: Set appropriate `CHECK_INTERVAL` to avoid API rate limits (recommended: 60-300 seconds).

3. **Error Handling**: Monitor agent logs for errors and set up alerts.

4. **Testing**: Test agent behavior with `--once` flag before enabling continuous mode.

5. **Resource Usage**: Monitor container resource usage when running agent continuously.

6. **Graceful Shutdown**: Ensure agent handles SIGTERM/SIGINT properly for clean container shutdown.

## Troubleshooting

### Agent Not Starting

```bash
# Check Python environment
docker exec codemate-container which python3
docker exec codemate-container uv --version

# Check dependencies
docker exec codemate-container uv pip list
```

### API Connection Issues

```bash
# Test API key
docker exec codemate-container bash -c 'echo $ANTHROPIC_API_KEY'

# Test network connectivity
docker exec codemate-container curl -I https://api.anthropic.com
```

### GitHub CLI Issues

```bash
# Check gh authentication
docker exec codemate-container gh auth status

# Test PR access
docker exec codemate-container gh pr view 123
```

## Advanced Configuration

### Custom Plugin Loading

The agent automatically loads plugins from Claude Code. To add custom plugins:

1. Install plugin: `claude plugin install <plugin>`
2. Agent will discover it on next run
3. Skills become available automatically

### Multi-PR Monitoring

Run multiple agent instances for different PRs:

```bash
# PR 123
docker run -d --name agent-pr-123 \
  -e PR_NUMBER=123 \
  -e ANTHROPIC_API_KEY="$API_KEY" \
  codemate

# PR 124
docker run -d --name agent-pr-124 \
  -e PR_NUMBER=124 \
  -e ANTHROPIC_API_KEY="$API_KEY" \
  codemate
```

### Webhook Integration

For real-time comment handling, integrate with GitHub webhooks:

```python
# webhook_server.py
from flask import Flask, request
import subprocess

app = Flask(__name__)

@app.route('/webhook', methods=['POST'])
def handle_webhook():
    data = request.json
    if data['action'] in ['created', 'edited']:
        # Trigger agent
        subprocess.run(['uv', 'run', 'agent/claude_agent.py', '--once'])
    return '', 200
```
