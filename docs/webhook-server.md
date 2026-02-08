# Webhook-Driven Issue Automation

Automatically handle GitHub issues with Claude Code. When a new issue is created in your repository, the webhook server spawns an isolated session that implements a solution, creates a draft PR, and responds to follow-up comments.

## How It Works

```
GitHub Issue Created
        │
        ▼
  Webhook Server (POST /webhook)
        │
        ├── Verify HMAC signature
        ├── Clone repo & create branch (issue-N)
        ├── Create draft PR
        ├── Start Claude Code in tmux session
        └── Send issue details to Claude
                │
                ▼
        Claude implements solution
                │
                ▼
        Commits, pushes, updates PR
```

When a follow-up comment is posted on the issue, the server forwards it to the running Claude session. If the session is busy, comments are queued and delivered when it becomes available.

## Quick Start

### 1. Configure environment

Copy `.env.example` and fill in the required values:

```bash
cp .env.example .env
```

Required variables:

```bash
ANTHROPIC_API_KEY=sk-ant-...
# Choose one authentication method:
GITHUB_TOKEN=ghp_...                    # Option A: Personal access token
# OR
GITHUB_APP_ID=123456                    # Option B: GitHub App (see below)
GITHUB_APP_PRIVATE_KEY_FILE=/path/to/key.pem
```

Optional but recommended:

```bash
GITHUB_WEBHOOK_SECRET=your-random-secret
```

### 2. Start the server

```bash
# Webhook server only (port 8080)
docker compose up

# With Cloudflare Tunnel for public access
docker compose --profile tunnel up
```

### 3. Configure GitHub webhook

In your repository: **Settings > Webhooks > Add webhook**

| Field | Value |
|-------|-------|
| Payload URL | `https://your-domain/webhook` or `http://your-server:8080/webhook` |
| Content type | `application/json` |
| Secret | Same value as `GITHUB_WEBHOOK_SECRET` |
| Events | Select "Issues" and "Issue comments" |

### 4. Create an issue

Create a new issue in your repository. The webhook server will automatically:

1. Clone the repo and create an `issue-N` branch
2. Create a draft PR linked to the issue
3. Start Claude Code to implement a solution
4. Push commits and update the PR

## Architecture

```
docker-compose.yml
├── webhook       — FastAPI server + Claude Code sessions
└── cloudflared   — Cloudflare Tunnel (optional, --profile tunnel)
```

### Key Components

| File | Purpose |
|------|---------|
| `webhook_server/app.py` | FastAPI routes (`POST /webhook`, `GET /health`) and lifespan |
| `webhook_server/services.py` | Issue handling, workspace setup, tmux session management |
| `webhook_server/github_auth.py` | PAT and GitHub App authentication with token refresh |
| `webhook_server/security.py` | HMAC-SHA256 webhook signature verification |
| `webhook_server/config.py` | Environment variable configuration |
| `docker/Dockerfile.webhook` | Container image definition |
| `docker-compose.yml` | Service orchestration (webhook + optional cloudflared) |

### Webhook Events

| Event | Action | Behavior |
|-------|--------|----------|
| `issues` | `opened` | Clone repo, create branch, create draft PR, start Claude session |
| `issue_comment` | `created` | Forward comment to existing session, or start a new one |
| `issue_comment` | `created` (Bot) | Skipped to prevent feedback loops |
| `issue_comment` | `created` (on PR) | Skipped — only issue comments are handled |
| Any other | Any | Ignored with 200 response |

### Workspace Isolation

Each issue gets its own workspace at `~/workspaces/{owner}/{repo}/issue-{N}/`. This allows multiple issues across multiple repositories to be handled concurrently without interference.

## Authentication

The server supports two authentication methods for GitHub API access.

### Personal Access Token (PAT)

Set `GITHUB_TOKEN` in your environment. The token is used directly for all `gh` and `git` operations.

```bash
GITHUB_TOKEN=ghp_xxxxxxxxxxxx
```

### GitHub App

More secure for production use. Uses short-lived installation tokens instead of a long-lived PAT.

**Setup:**

1. [Create a GitHub App](https://docs.github.com/en/apps/creating-github-apps) with these permissions:
   - Repository: Contents (Read & Write), Issues (Read & Write), Pull requests (Read & Write)
2. Generate a private key and download the `.pem` file
3. Install the App on your repository/organization
4. Configure the environment:

```bash
GITHUB_APP_ID=123456

# Provide the private key via file (recommended):
GITHUB_APP_PRIVATE_KEY_FILE=/home/agent/.github-app-key.pem

# Or inline (useful for CI/secrets managers):
GITHUB_APP_PRIVATE_KEY="-----BEGIN RSA PRIVATE KEY-----\n..."

# Optional — auto-detected from webhook payloads if omitted:
GITHUB_APP_INSTALLATION_ID=78901234
```

When using docker-compose, mount the key file:

```yaml
volumes:
  - ./your-app.private-key.pem:/home/agent/.github-app-key.pem:ro
```

**How token refresh works:**

- On startup, if an installation ID is available, the server acquires a token immediately
- Before each `gh`/`git` operation, the server checks if the token expires within 5 minutes
- If expired, it generates a new JWT, exchanges it for a fresh installation token, and re-authenticates the `gh` CLI
- A lock prevents concurrent refresh races from multiple webhook handlers

## Cloudflare Tunnel

The `cloudflared` service runs as a separate container and is gated behind a docker-compose profile. It is only started when explicitly requested.

```bash
# Without tunnel — webhook listens on port 8080
docker compose up

# With tunnel — exposes webhook via Cloudflare
docker compose --profile tunnel up
```

Set `CLOUDFLARE_TUNNEL_TOKEN` in your `.env` file. Configure the tunnel in the Cloudflare dashboard to route traffic to `http://webhook:8080`.

## Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `ANTHROPIC_API_KEY` | Yes | — | Anthropic API key for Claude Code |
| `GITHUB_TOKEN` | No\* | — | Personal access token for GitHub operations |
| `GITHUB_APP_ID` | No\* | — | GitHub App ID (alternative to `GITHUB_TOKEN`) |
| `GITHUB_APP_PRIVATE_KEY` | No | — | Inline PEM private key content |
| `GITHUB_APP_PRIVATE_KEY_FILE` | No | — | Path to PEM private key file |
| `GITHUB_APP_INSTALLATION_ID` | No | — | Installation ID (auto-detected from webhooks) |
| `GITHUB_WEBHOOK_SECRET` | No | — | HMAC secret for verifying webhook signatures |
| `CLOUDFLARE_TUNNEL_TOKEN` | No | — | Enables the cloudflared service |
| `WEBHOOK_PORT` | No | `8080` | Host port mapping for the webhook server |
| `WORKSPACES_ROOT` | No | `~/workspaces` | Root directory for issue workspaces |
| `SYSTEM_PROMPT_FILE` | No | auto-detected | Path to Claude system prompt file |

\* Either `GITHUB_TOKEN` or `GITHUB_APP_ID` + private key must be set.

## Health Check

```bash
curl http://localhost:8080/health
```

Returns active session info:

```json
{
  "status": "ok",
  "active_sessions": {
    "owner/repo#42": {
      "session_name": "claude-owner-repo-42",
      "branch": "issue-42",
      "pr_url": "https://github.com/owner/repo/pull/99",
      "tmux_active": true
    }
  },
  "total_sessions": 1
}
```

## Running Without Docker

The webhook server can also run directly on the host:

```bash
# Install dependencies
uv sync

# Start the server
uv run codemate-webhook
```

Requires `gh` CLI authenticated and Claude Code installed.
