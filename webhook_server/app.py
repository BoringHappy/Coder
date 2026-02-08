"""FastAPI application: routes and lifespan."""

import json
from contextlib import asynccontextmanager

from fastapi import FastAPI, Header, HTTPException, Request

from .config import PORT, SYSTEM_PROMPT_FILE, WORKSPACES_ROOT, logger
from .github_auth import auth_manager
from .security import verify_signature
from .services import (
    handle_issue_comment,
    handle_new_issue,
    session_exists,
    sessions,
)


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
    auth_manager.configure_from_env()
    auth_manager.initial_auth()
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

    auth_manager.set_installation_id_from_webhook(payload)

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
