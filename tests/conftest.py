"""Shared fixtures for webhook server tests."""

import hashlib
import hmac
import json
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient


@pytest.fixture()
def client():
    """TestClient with no webhook secret configured."""
    from webhook_server.app import app
    from webhook_server import config

    original = config.WEBHOOK_SECRET
    config.WEBHOOK_SECRET = ""
    # Also patch the security module's reference
    from webhook_server import security
    security.WEBHOOK_SECRET = ""

    with patch("webhook_server.app.auth_manager") as mock_auth:
        mock_auth.configure_from_env.return_value = None
        mock_auth.initial_auth.return_value = None
        mock_auth.set_installation_id_from_webhook.return_value = None
        with TestClient(app) as c:
            yield c

    config.WEBHOOK_SECRET = original
    security.WEBHOOK_SECRET = original


@pytest.fixture()
def client_with_secret():
    """TestClient with webhook secret set to 'test-secret'."""
    from webhook_server.app import app
    from webhook_server import config, security

    original = config.WEBHOOK_SECRET
    secret = "test-secret"
    config.WEBHOOK_SECRET = secret
    security.WEBHOOK_SECRET = secret

    with patch("webhook_server.app.auth_manager") as mock_auth:
        mock_auth.configure_from_env.return_value = None
        mock_auth.initial_auth.return_value = None
        mock_auth.set_installation_id_from_webhook.return_value = None
        with TestClient(app) as c:
            yield c

    config.WEBHOOK_SECRET = original
    security.WEBHOOK_SECRET = original


def sign_payload(payload: bytes, secret: str = "test-secret") -> str:
    """Compute the X-Hub-Signature-256 header value."""
    sig = hmac.new(secret.encode(), payload, hashlib.sha256).hexdigest()
    return f"sha256={sig}"


def make_issue_payload(
    number: int = 1,
    title: str = "Test issue",
    body: str = "Issue body",
    action: str = "opened",
) -> dict:
    """Build a minimal issues webhook payload."""
    return {
        "action": action,
        "issue": {
            "number": number,
            "title": title,
            "body": body,
        },
        "repository": {
            "clone_url": "https://github.com/test-owner/test-repo.git",
        },
    }


def make_comment_payload(
    issue_number: int = 1,
    comment_body: str = "A comment",
    comment_user: str = "someuser",
    user_type: str = "User",
    has_pull_request: bool = False,
) -> dict:
    """Build a minimal issue_comment webhook payload."""
    issue: dict = {"number": issue_number}
    if has_pull_request:
        issue["pull_request"] = {"url": "https://api.github.com/repos/o/r/pulls/1"}
    return {
        "action": "created",
        "issue": issue,
        "comment": {
            "body": comment_body,
            "user": {
                "login": comment_user,
                "type": user_type,
            },
        },
        "repository": {
            "clone_url": "https://github.com/test-owner/test-repo.git",
        },
    }
