#!/usr/bin/env python3
"""
GitHub Webhook Server for CodeMate Issue Workflow.

Receives GitHub webhook events via Cloudflare Tunnel and spawns
Claude Code tmux sessions to work on issues automatically.

Data flow:
  GitHub Issue Created -> Webhook -> This server -> new tmux session (claude-issue-{N})
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
from http.server import HTTPServer, BaseHTTPRequestHandler

# Configuration
PORT = int(os.getenv("WEBHOOK_PORT", "8080"))
WEBHOOK_SECRET = os.getenv("GITHUB_WEBHOOK_SECRET", "")
GIT_REPO_URL = os.getenv("GIT_REPO_URL", "")
SETUP_DIR = "/usr/local/bin/setup"
SYSTEM_PROMPT_FILE = f"{SETUP_DIR}/prompt/system_prompt_issue.txt"

# Logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
)
logger = logging.getLogger("webhook_server")

# In-memory session tracking
# {issue_number: {session_name, branch, workspace, pr_url}}
sessions = {}


def run(cmd, check=True, cwd=None):
    """Run a shell command and return the result."""
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True, cwd=cwd)
    if check and result.returncode != 0:
        raise RuntimeError(f"Command failed: {cmd}\n{result.stderr}")
    return result


def get_repo_name_from_url(git_url):
    """Extract repository name from git URL."""
    if git_url.endswith(".git"):
        git_url = git_url[:-4]
    return git_url.rstrip("/").split("/")[-1]


def verify_signature(payload_body, signature_header):
    """Verify the GitHub webhook signature."""
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

    expected_signature = hmac.new(
        WEBHOOK_SECRET.encode("utf-8"),
        payload_body,
        hashlib.sha256,
    ).hexdigest()

    return hmac.compare_digest(signature, expected_signature)


def session_exists(session_name):
    """Check if a tmux session exists."""
    result = run(f"tmux has-session -t {shlex.quote(session_name)}", check=False)
    return result.returncode == 0


def is_session_stopped(issue_number):
    """Check if a Claude session is stopped (waiting for input)."""
    status_file = f"/tmp/.session_status_issue_{issue_number}"
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


def send_command_to_session(session_name, command, max_attempts=3):
    """Send a command to a tmux session and verify submission."""
    safe_command = command.replace("'", "'\\''")
    run(f"tmux send-keys -t {shlex.quote(session_name)} {shlex.quote(safe_command)}")
    run(f"tmux send-keys -t {shlex.quote(session_name)} C-m")

    # Extract issue number from session name for status file
    issue_num = session_name.replace("claude-issue-", "")
    status_file = f"/tmp/.session_status_issue_{issue_num}"

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


def setup_issue_workspace(issue_number, repo_url):
    """Clone repo, create branch, push, and create a draft PR."""
    repo_name = get_repo_name_from_url(repo_url)
    branch_name = f"issue-{issue_number}"
    workspace = f"/home/agent/issues/{repo_name}-{issue_number}"

    os.makedirs("/home/agent/issues", exist_ok=True)

    if not os.path.exists(f"{workspace}/.git"):
        logger.info(f"Cloning repository for issue #{issue_number}")
        run(f"git clone {shlex.quote(repo_url)} {shlex.quote(workspace)}")
    else:
        logger.info(f"Using existing workspace for issue #{issue_number}")
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


def create_draft_pr(issue_number, issue_title, workspace):
    """Create a draft PR for the issue."""
    branch_name = f"issue-{issue_number}"
    safe_title = shlex.quote(f"Fix #{issue_number}: {issue_title}")

    # Read PR template if available
    template_path = f"{workspace}/.github/PULL_REQUEST_TEMPLATE.md"
    if os.path.exists(template_path):
        with open(template_path, "r") as f:
            pr_body = f.read()
    else:
        pr_body = f"## Summary\n\nResolves #{issue_number}\n\n## Test plan\n- [ ] Review and test changes\n"

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
        # PR might already exist
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

    # Write PR status for skills
    pr_status_file = f"{workspace}/.pr_status"
    try:
        with tempfile.NamedTemporaryFile(
            mode="w", delete=False, dir=workspace, prefix=".pr_status_"
        ) as f:
            f.write(pr_url)
            temp_path = f.name
        os.rename(temp_path, pr_status_file)
    except Exception as e:
        logger.warning(f"Failed to write PR status: {e}")

    return pr_url


def handle_new_issue(issue_number, issue_title, issue_body, repo_url):
    """Handle a new issue: create workspace, branch, PR, and start Claude session."""
    session_name = f"claude-issue-{issue_number}"

    if session_exists(session_name):
        logger.info(f"Session {session_name} already exists, skipping")
        return

    logger.info(f"Handling new issue #{issue_number}: {issue_title}")

    # Setup workspace and branch
    workspace, branch_name = setup_issue_workspace(issue_number, repo_url)

    # Create draft PR
    pr_url = create_draft_pr(issue_number, issue_title, workspace)

    # Write PR status to /tmp for skills (symlink or copy)
    try:
        pr_tmp_status = "/tmp/.pr_status"
        # Each session needs its own status tracking, but skills read from /tmp/.pr_status
        # We'll set it before starting the session
        with open(pr_tmp_status, "w") as f:
            f.write(pr_url)
    except Exception as e:
        logger.warning(f"Failed to write /tmp/.pr_status: {e}")

    # Read system prompt
    system_prompt = ""
    if os.path.exists(SYSTEM_PROMPT_FILE):
        with open(SYSTEM_PROMPT_FILE, "r") as f:
            system_prompt = f.read()

    # Create tmux session with Claude Code
    claude_cmd = (
        f"cd {shlex.quote(workspace)} && "
        f"claude --dangerously-skip-permissions"
    )
    if system_prompt:
        claude_cmd += f' --append-system-prompt "$(cat {shlex.quote(SYSTEM_PROMPT_FILE)})"'

    # Set session-specific status file via environment
    session_env = f"SESSION_STATUS_FILE=/tmp/.session_status_issue_{issue_number}"
    tmux_cmd = f"tmux new-session -d -s {shlex.quote(session_name)} -e {shlex.quote(session_env)} {shlex.quote(claude_cmd)}"
    run(tmux_cmd)

    logger.info(f"Started tmux session: {session_name}")

    # Wait for Claude to initialize
    time.sleep(5)

    # Send the issue as the initial query
    initial_query = (
        f"GitHub Issue #{issue_number}: {issue_title}\n\n{issue_body}\n\n"
        f"Please implement a solution for this issue. "
        f"The repository is already cloned and you are on branch {branch_name}. "
        f"A draft PR has been created{f': {pr_url}' if pr_url else '.'}."
    )
    send_command_to_session(session_name, initial_query)

    # Track session
    sessions[issue_number] = {
        "session_name": session_name,
        "branch": branch_name,
        "workspace": workspace,
        "pr_url": pr_url,
    }

    logger.info(f"Issue #{issue_number} session started and query sent")


def handle_issue_comment(issue_number, comment_body, comment_user):
    """Handle a new comment on an issue: forward to existing session or start new one."""
    session_name = f"claude-issue-{issue_number}"

    logger.info(f"Handling comment on issue #{issue_number} from {comment_user}")

    if session_exists(session_name):
        # Check if session is stopped (waiting for input)
        if is_session_stopped(issue_number):
            message = f"Issue comment from @{comment_user}:\n\n{comment_body}"
            send_command_to_session(session_name, message)
            logger.info(f"Forwarded comment to existing session {session_name}")
        else:
            logger.info(f"Session {session_name} is busy, comment will be queued")
            # Write comment to a queue file for later processing
            queue_file = f"/tmp/.issue_comment_queue_{issue_number}"
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
        # No session exists - could be after container restart
        logger.info(f"No session for issue #{issue_number}, starting new one")

        if not GIT_REPO_URL:
            logger.error("GIT_REPO_URL not set, cannot start new session")
            return

        # Reconstruct workspace
        workspace, branch_name = setup_issue_workspace(issue_number, GIT_REPO_URL)

        # Check for existing PR
        result = run(
            f"gh pr list --head issue-{issue_number} --json url -q '.[0].url'",
            check=False,
            cwd=workspace,
        )
        pr_url = result.stdout.strip() if result.returncode == 0 else ""

        # Write PR status
        try:
            with open("/tmp/.pr_status", "w") as f:
                f.write(pr_url)
        except Exception:
            pass

        # Read system prompt
        system_prompt_file = SYSTEM_PROMPT_FILE
        claude_cmd = (
            f"cd {shlex.quote(workspace)} && "
            f"claude --dangerously-skip-permissions"
        )
        if os.path.exists(system_prompt_file):
            claude_cmd += f' --append-system-prompt "$(cat {shlex.quote(system_prompt_file)})"'

        session_env = f"SESSION_STATUS_FILE=/tmp/.session_status_issue_{issue_number}"
        tmux_cmd = f"tmux new-session -d -s {shlex.quote(session_name)} -e {shlex.quote(session_env)} {shlex.quote(claude_cmd)}"
        run(tmux_cmd)

        time.sleep(5)

        message = f"Issue comment from @{comment_user}:\n\n{comment_body}\n\nPlease address this feedback. You are on branch issue-{issue_number}."
        send_command_to_session(session_name, message)

        sessions[issue_number] = {
            "session_name": session_name,
            "branch": branch_name,
            "workspace": workspace,
            "pr_url": pr_url,
        }

        logger.info(f"Started new session for issue #{issue_number} with comment")


class WebhookHandler(BaseHTTPRequestHandler):
    """HTTP request handler for GitHub webhooks."""

    def log_message(self, format, *args):
        """Override to use our logger."""
        logger.info(f"{self.address_string()} - {format % args}")

    def do_GET(self):
        """Handle GET requests (health check)."""
        if self.path == "/health":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()

            active_sessions = {
                str(k): {
                    "session_name": v["session_name"],
                    "branch": v["branch"],
                    "pr_url": v["pr_url"],
                    "tmux_active": session_exists(v["session_name"]),
                }
                for k, v in sessions.items()
            }

            health = {
                "status": "ok",
                "active_sessions": active_sessions,
                "total_sessions": len(sessions),
            }
            self.wfile.write(json.dumps(health).encode())
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        """Handle POST requests (webhook events)."""
        if self.path != "/webhook":
            self.send_response(404)
            self.end_headers()
            return

        # Read request body
        content_length = int(self.headers.get("Content-Length", 0))
        payload_body = self.rfile.read(content_length)

        # Verify signature
        signature = self.headers.get("X-Hub-Signature-256", "")
        if not verify_signature(payload_body, signature):
            logger.error("Webhook signature verification failed")
            self.send_response(401)
            self.end_headers()
            self.wfile.write(b"Signature verification failed")
            return

        # Parse event
        event_type = self.headers.get("X-GitHub-Event", "")
        try:
            payload = json.loads(payload_body)
        except json.JSONDecodeError:
            self.send_response(400)
            self.end_headers()
            self.wfile.write(b"Invalid JSON")
            return

        logger.info(f"Received event: {event_type}, action: {payload.get('action', 'N/A')}")

        # Route event
        try:
            if event_type == "issues" and payload.get("action") == "opened":
                issue = payload["issue"]
                repo_url = payload["repository"]["clone_url"]
                handle_new_issue(
                    issue_number=issue["number"],
                    issue_title=issue["title"],
                    issue_body=issue.get("body", ""),
                    repo_url=repo_url,
                )
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b"Issue handled")

            elif event_type == "issue_comment" and payload.get("action") == "created":
                issue = payload["issue"]
                comment = payload["comment"]

                # Skip bot comments to avoid loops
                if comment["user"].get("type") == "Bot":
                    self.send_response(200)
                    self.end_headers()
                    self.wfile.write(b"Skipped bot comment")
                    return

                # Only handle comments on issues (not PRs)
                # PR comments have a "pull_request" key in the issue object
                if "pull_request" in issue:
                    logger.info("Skipping PR comment (not an issue comment)")
                    self.send_response(200)
                    self.end_headers()
                    self.wfile.write(b"Skipped PR comment")
                    return

                handle_issue_comment(
                    issue_number=issue["number"],
                    comment_body=comment["body"],
                    comment_user=comment["user"]["login"],
                )
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b"Comment handled")

            else:
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b"Event ignored")

        except Exception as e:
            logger.exception(f"Error handling event: {e}")
            self.send_response(500)
            self.end_headers()
            self.wfile.write(f"Internal error: {e}".encode())


def main():
    """Start the webhook server."""
    if not GIT_REPO_URL:
        logger.warning("GIT_REPO_URL not set - new issues will use repo URL from webhook payload")

    server = HTTPServer(("0.0.0.0", PORT), WebhookHandler)
    logger.info(f"Webhook server listening on port {PORT}")
    logger.info(f"Health check: http://localhost:{PORT}/health")
    logger.info(f"Webhook endpoint: http://localhost:{PORT}/webhook")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        logger.info("Shutting down webhook server")
        server.server_close()


if __name__ == "__main__":
    main()
