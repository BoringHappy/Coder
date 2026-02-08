#!/usr/bin/env python3
"""
GitHub Webhook Server for CodeMate Issue Workflow.

Receives GitHub webhook events and spawns Claude Code tmux sessions
to work on issues automatically. Each issue gets an isolated workspace
under ~/workspaces/{owner}/{repo}/issue-{N}/, supporting multiple repos
and branches concurrently.

Run on host:
  uv run webhook_server.py

Run in Docker (with optional Cloudflare Tunnel):
  docker build -f docker/Dockerfile.webhook -t codemate-webhook .
  docker run -p 8080:8080 --env-file .env codemate-webhook

Data flow:
  GitHub Issue Created -> Webhook -> This server -> new tmux session (claude-{owner}-{repo}-{N})
  GitHub Issue Comment -> Webhook -> This server -> forwards to existing tmux session
"""

import hashlib
import hmac
import json
import logging
import os
import shlex
import subprocess
import sys
import tempfile
import time
from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI, Header, HTTPException, Request

# Configuration
PORT = int(os.getenv("WEBHOOK_PORT", "8080"))
WEBHOOK_SECRET = os.getenv("GITHUB_WEBHOOK_SECRET", "")
WORKSPACES_ROOT = os.getenv("WORKSPACES_ROOT", str(Path.home() / "workspaces"))

# System prompt: check env, then look relative to this script, then Docker path
_SCRIPT_DIR = Path(__file__).resolve().parent
_DEFAULT_PROMPT_PATHS = [
    _SCRIPT_DIR / "docker" / "setup" / "prompt" / "system_prompt_issue.txt",  # repo root
    Path("/usr/local/bin/setup/prompt/system_prompt_issue.txt"),               # Docker
]
SYSTEM_PROMPT_FILE = os.getenv("SYSTEM_PROMPT_FILE", "")
if not SYSTEM_PROMPT_FILE:
    for p in _DEFAULT_PROMPT_PATHS:
        if p.exists():
            SYSTEM_PROMPT_FILE = str(p)
            break

# Logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
)
logger = logging.getLogger("webhook_server")

# In-memory session tracking
# key: "{owner}/{repo}#{issue_number}"
# value: {session_name, branch, workspace, pr_url}
sessions: dict[str, dict] = {}


# --- Shell helpers ---


def run(cmd: str, check: bool = True, cwd: str | None = None) -> subprocess.CompletedProcess:
    """Run a shell command and return the result."""
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True, cwd=cwd)
    if check and result.returncode != 0:
        raise RuntimeError(f"Command failed: {cmd}\n{result.stderr}")
    return result


def parse_repo_owner_name(repo_url: str) -> tuple[str, str]:
    """Extract owner and repo name from a git URL.

    Handles:
      https://github.com/owner/repo.git
      https://github.com/owner/repo
      git@github.com:owner/repo.git
    """
    url = repo_url.rstrip("/")
    if url.endswith(".git"):
        url = url[:-4]

    if ":" in url and url.startswith("git@"):
        # git@github.com:owner/repo
        path = url.split(":")[-1]
    else:
        # https://github.com/owner/repo
        path = "/".join(url.split("/")[-2:])

    parts = path.split("/")
    if len(parts) >= 2:
        return parts[-2], parts[-1]
    return "unknown", parts[-1] if parts else "unknown"


# --- Signature verification ---


def verify_signature(payload_body: bytes, signature_header: str) -> bool:
    """Verify the GitHub webhook HMAC-SHA256 signature."""
    if not WEBHOOK_SECRET:
        logger.warning("GITHUB_WEBHOOK_SECRET not set, skipping signature verification")
        return True

    if not signature_header:
        logger.error("No X-Hub-Signature-256 header present")
        return False

    hash_algorithm, _, signature = signature_header.partition("=")
    if hash_algorithm != "sha256":
        logger.error(f"Unexpected hash algorithm: {hash_algorithm}")
        return False

    expected = hmac.new(
        WEBHOOK_SECRET.encode("utf-8"),
        payload_body,
        hashlib.sha256,
    ).hexdigest()

    return hmac.compare_digest(signature, expected)


# --- Tmux session helpers ---


def session_exists(session_name: str) -> bool:
    """Check if a tmux session exists."""
    result = run(f"tmux has-session -t {shlex.quote(session_name)}", check=False)
    return result.returncode == 0


def is_session_stopped(session_key: str) -> bool:
    """Check if a Claude session is stopped (waiting for input)."""
    status_file = f"/tmp/.session_status_{_safe_filename(session_key)}"
    if not os.path.exists(status_file):
        return False
    try:
        with open(status_file, "r") as f:
            lines = [line.strip() for line in f.readlines() if line.strip()]
            if lines and lines[-1].endswith("Stop"):
                return True
    except Exception:
        pass
    return False


def send_command_to_session(session_name: str, command: str, session_key: str, max_attempts: int = 3) -> bool:
    """Send a command to a tmux session and verify submission."""
    run(f"tmux send-keys -t {shlex.quote(session_name)} {shlex.quote(command)}")
    run(f"tmux send-keys -t {shlex.quote(session_name)} C-m")

    status_file = f"/tmp/.session_status_{_safe_filename(session_key)}"

    for attempt in range(1, max_attempts + 1):
        time.sleep(3)
        if os.path.exists(status_file):
            try:
                with open(status_file, "r") as f:
                    content = f.read().strip()
                if "UserPromptSubmit" in content.split("\n")[-1]:
                    logger.info(f"Command submitted successfully (attempt {attempt})")
                    return True
            except Exception:
                pass

        logger.warning(f"Command not submitted, attempt {attempt}/{max_attempts}")
        if attempt < max_attempts:
            run(f"tmux send-keys -t {shlex.quote(session_name)} C-m")

    logger.warning("Max retry attempts reached, continuing anyway")
    return True


def _safe_filename(key: str) -> str:
    """Convert a session key like 'owner/repo#123' to a safe filename component."""
    return key.replace("/", "_").replace("#", "_")


def _make_session_name(owner: str, repo: str, issue_number: int) -> str:
    """Build a tmux session name: claude-{owner}-{repo}-{N}."""
    return f"claude-{owner}-{repo}-{issue_number}"


def _make_session_key(owner: str, repo: str, issue_number: int) -> str:
    """Build the in-memory tracking key: {owner}/{repo}#{N}."""
    return f"{owner}/{repo}#{issue_number}"


# --- Workspace management ---


def setup_issue_workspace(owner: str, repo: str, issue_number: int, repo_url: str) -> tuple[str, str]:
    """Clone repo, create branch, push, and return (workspace, branch_name)."""
    branch_name = f"issue-{issue_number}"
    workspace = os.path.join(WORKSPACES_ROOT, owner, repo, f"issue-{issue_number}")

    os.makedirs(os.path.dirname(workspace), exist_ok=True)

    if not os.path.exists(f"{workspace}/.git"):
        logger.info(f"Cloning {owner}/{repo} for issue #{issue_number}")
        run(f"git clone {shlex.quote(repo_url)} {shlex.quote(workspace)}")
    else:
        logger.info(f"Using existing workspace for {owner}/{repo}#{issue_number}")
        run("git fetch origin", cwd=workspace)

    # Create and push branch
    result = run(
        f"git show-ref --verify --quiet refs/heads/{shlex.quote(branch_name)}",
        check=False,
        cwd=workspace,
    )
    if result.returncode == 0:
        run(f"git checkout {shlex.quote(branch_name)}", cwd=workspace)
        run(f"git pull origin {shlex.quote(branch_name)}", check=False, cwd=workspace)
    else:
        result = run(
            f"git show-ref --verify --quiet refs/remotes/origin/{shlex.quote(branch_name)}",
            check=False,
            cwd=workspace,
        )
        if result.returncode == 0:
            run(
                f"git checkout -b {shlex.quote(branch_name)} origin/{shlex.quote(branch_name)}",
                cwd=workspace,
            )
        else:
            run(f"git checkout -b {shlex.quote(branch_name)}", cwd=workspace)
            run(
                f"git commit --allow-empty -m {shlex.quote(f'Initial commit for issue-{issue_number}')}",
                cwd=workspace,
            )
            run(f"git push -u origin {shlex.quote(branch_name)}", cwd=workspace)

    return workspace, branch_name


def create_draft_pr(owner: str, repo: str, issue_number: int, issue_title: str, workspace: str) -> str:
    """Create a draft PR for the issue. Returns the PR URL."""
    branch_name = f"issue-{issue_number}"
    safe_title = shlex.quote(f"Fix #{issue_number}: {issue_title}")

    template_path = f"{workspace}/.github/PULL_REQUEST_TEMPLATE.md"
    if os.path.exists(template_path):
        with open(template_path, "r") as f:
            pr_body = f.read()
    else:
        pr_body = (
            f"## Summary\n\nResolves #{issue_number}\n\n"
            f"## Test plan\n- [ ] Review and test changes\n"
        )

    safe_body = shlex.quote(pr_body)
    result = run(
        f"gh pr create --draft --title {safe_title} --body {safe_body}",
        check=False,
        cwd=workspace,
    )

    pr_url = ""
    if result.returncode == 0:
        pr_url = result.stdout.strip()
        logger.info(f"Created draft PR: {pr_url}")
    else:
        result = run(
            f"gh pr list --head {shlex.quote(branch_name)} --json url -q '.[0].url'",
            check=False,
            cwd=workspace,
        )
        if result.returncode == 0 and result.stdout.strip():
            pr_url = result.stdout.strip()
            logger.info(f"PR already exists: {pr_url}")
        else:
            logger.error(f"Failed to create PR: {result.stderr}")

    # Write PR status for skills (atomic write)
    pr_status_file = "/tmp/.pr_status"
    try:
        with tempfile.NamedTemporaryFile(mode="w", delete=False, dir="/tmp", prefix=".pr_status_") as f:
            f.write(pr_url)
            temp_path = f.name
        os.rename(temp_path, pr_status_file)
    except Exception as e:
        logger.warning(f"Failed to write PR status: {e}")

    return pr_url


# --- Event handlers ---


def _start_claude_session(session_name: str, session_key: str, workspace: str) -> None:
    """Start a Claude Code tmux session in the given workspace."""
    claude_cmd = f"cd {shlex.quote(workspace)} && claude --dangerously-skip-permissions"
    if SYSTEM_PROMPT_FILE and os.path.exists(SYSTEM_PROMPT_FILE):
        claude_cmd += f' --append-system-prompt "$(cat {shlex.quote(SYSTEM_PROMPT_FILE)})"'

    safe_status = _safe_filename(session_key)
    session_env = f"SESSION_STATUS_FILE=/tmp/.session_status_{safe_status}"
    tmux_cmd = (
        f"tmux new-session -d -s {shlex.quote(session_name)} "
        f"-e {shlex.quote(session_env)} {shlex.quote(claude_cmd)}"
    )
    run(tmux_cmd)
    logger.info(f"Started tmux session: {session_name}")


def handle_new_issue(issue_number: int, issue_title: str, issue_body: str, repo_url: str) -> None:
    """Handle a new issue: create workspace, branch, PR, and start Claude session."""
    owner, repo = parse_repo_owner_name(repo_url)
    session_name = _make_session_name(owner, repo, issue_number)
    session_key = _make_session_key(owner, repo, issue_number)

    if session_exists(session_name):
        logger.info(f"Session {session_name} already exists, skipping")
        return

    logger.info(f"Handling new issue {owner}/{repo}#{issue_number}: {issue_title}")

    workspace, branch_name = setup_issue_workspace(owner, repo, issue_number, repo_url)
    pr_url = create_draft_pr(owner, repo, issue_number, issue_title, workspace)

    _start_claude_session(session_name, session_key, workspace)

    # Wait for Claude to initialize
    time.sleep(5)

    initial_query = (
        f"GitHub Issue #{issue_number}: {issue_title}\n\n{issue_body}\n\n"
        f"Please implement a solution for this issue. "
        f"The repository is already cloned and you are on branch {branch_name}. "
        f"A draft PR has been created{f': {pr_url}' if pr_url else '.'}."
    )
    send_command_to_session(session_name, initial_query, session_key)

    sessions[session_key] = {
        "session_name": session_name,
        "branch": branch_name,
        "workspace": workspace,
        "pr_url": pr_url,
    }
    logger.info(f"Issue {session_key} session started and query sent")


def handle_issue_comment(issue_number: int, comment_body: str, comment_user: str, repo_url: str) -> None:
    """Handle a new comment on an issue: forward to existing session or start new one."""
    owner, repo = parse_repo_owner_name(repo_url)
    session_name = _make_session_name(owner, repo, issue_number)
    session_key = _make_session_key(owner, repo, issue_number)

    logger.info(f"Handling comment on {session_key} from {comment_user}")

    if session_exists(session_name):
        if is_session_stopped(session_key):
            message = f"Issue comment from @{comment_user}:\n\n{comment_body}"
            send_command_to_session(session_name, message, session_key)
            logger.info(f"Forwarded comment to existing session {session_name}")
        else:
            logger.info(f"Session {session_name} is busy, comment will be queued")
            queue_file = f"/tmp/.issue_comment_queue_{_safe_filename(session_key)}"
            try:
                with open(queue_file, "a") as f:
                    f.write(json.dumps({
                        "user": comment_user,
                        "body": comment_body,
                        "timestamp": time.time(),
                    }) + "\n")
                logger.info(f"Comment queued to {queue_file}")
            except Exception as e:
                logger.error(f"Failed to queue comment: {e}")
    else:
        logger.info(f"No session for {session_key}, starting new one")

        workspace, branch_name = setup_issue_workspace(owner, repo, issue_number, repo_url)

        result = run(
            f"gh pr list --head issue-{issue_number} --json url -q '.[0].url'",
            check=False,
            cwd=workspace,
        )
        pr_url = result.stdout.strip() if result.returncode == 0 else ""

        # Write PR status for skills
        try:
            with tempfile.NamedTemporaryFile(mode="w", delete=False, dir="/tmp", prefix=".pr_status_") as f:
                f.write(pr_url)
                temp_path = f.name
            os.rename(temp_path, "/tmp/.pr_status")
        except Exception:
            pass

        _start_claude_session(session_name, session_key, workspace)
        time.sleep(5)

        message = (
            f"Issue comment from @{comment_user}:\n\n{comment_body}\n\n"
            f"Please address this feedback. You are on branch issue-{issue_number}."
        )
        send_command_to_session(session_name, message, session_key)

        sessions[session_key] = {
            "session_name": session_name,
            "branch": branch_name,
            "workspace": workspace,
            "pr_url": pr_url,
        }
        logger.info(f"Started new session for {session_key} with comment")


# --- FastAPI app ---


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info(f"Webhook server starting on port {PORT}")
    logger.info(f"Health check: http://localhost:{PORT}/health")
    logger.info(f"Webhook endpoint: http://localhost:{PORT}/webhook")
    logger.info(f"Workspaces root: {WORKSPACES_ROOT}")
    if SYSTEM_PROMPT_FILE:
        logger.info(f"System prompt: {SYSTEM_PROMPT_FILE}")
    else:
        logger.warning("No system prompt file found")
    yield
    logger.info("Webhook server shutting down")


app = FastAPI(title="CodeMate Webhook Server", lifespan=lifespan)


@app.get("/health")
async def health():
    """Health check endpoint with active session info."""
    active_sessions = {
        k: {
            "session_name": v["session_name"],
            "branch": v["branch"],
            "pr_url": v["pr_url"],
            "tmux_active": session_exists(v["session_name"]),
        }
        for k, v in sessions.items()
    }
    return {
        "status": "ok",
        "active_sessions": active_sessions,
        "total_sessions": len(sessions),
    }


@app.post("/webhook")
async def webhook(
    request: Request,
    x_hub_signature_256: str = Header(default=""),
    x_github_event: str = Header(default=""),
):
    """GitHub webhook endpoint."""
    payload_body = await request.body()

    # Verify signature
    if not verify_signature(payload_body, x_hub_signature_256):
        raise HTTPException(status_code=401, detail="Signature verification failed")

    # Parse payload
    try:
        payload = json.loads(payload_body)
    except json.JSONDecodeError:
        raise HTTPException(status_code=400, detail="Invalid JSON")

    action = payload.get("action", "N/A")
    logger.info(f"Received event: {x_github_event}, action: {action}")

    # Route event
    if x_github_event == "issues" and action == "opened":
        issue = payload["issue"]
        repo_url = payload["repository"]["clone_url"]
        handle_new_issue(
            issue_number=issue["number"],
            issue_title=issue["title"],
            issue_body=issue.get("body", ""),
            repo_url=repo_url,
        )
        return {"status": "issue handled"}

    elif x_github_event == "issue_comment" and action == "created":
        issue = payload["issue"]
        comment = payload["comment"]

        # Skip bot comments to avoid loops
        if comment["user"].get("type") == "Bot":
            return {"status": "skipped bot comment"}

        # Only handle comments on issues (not PRs)
        if "pull_request" in issue:
            return {"status": "skipped PR comment"}

        repo_url = payload["repository"]["clone_url"]
        handle_issue_comment(
            issue_number=issue["number"],
            comment_body=comment["body"],
            comment_user=comment["user"]["login"],
            repo_url=repo_url,
        )
        return {"status": "comment handled"}

    return {"status": "event ignored"}


def main():
    """Entry point — run with uvicorn."""
    import uvicorn

    uvicorn.run(
        "webhook_server:app",
        host="0.0.0.0",
        port=PORT,
        log_level="info",
    )


if __name__ == "__main__":
    main()
