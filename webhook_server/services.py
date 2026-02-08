"""Business logic: shell helpers, tmux management, workspace setup, event handlers."""

import json
import os
import shlex
import subprocess
import tempfile
import time

from .config import SYSTEM_PROMPT_FILE, WORKSPACES_ROOT, logger
from .github_auth import auth_manager

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
    _write_pr_status(pr_url)

    return pr_url


def _write_pr_status(pr_url: str) -> None:
    """Write PR URL to status file atomically."""
    pr_status_file = "/tmp/.pr_status"
    try:
        with tempfile.NamedTemporaryFile(mode="w", delete=False, dir="/tmp", prefix=".pr_status_") as f:
            f.write(pr_url)
            temp_path = f.name
        os.rename(temp_path, pr_status_file)
    except Exception as e:
        logger.warning(f"Failed to write PR status: {e}")


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
    auth_manager.ensure_gh_auth()
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
    auth_manager.ensure_gh_auth()
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
        _write_pr_status(pr_url)

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
