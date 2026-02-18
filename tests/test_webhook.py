"""Tests for the /webhook endpoint."""

import json
from unittest.mock import patch

from .conftest import make_comment_payload, make_issue_payload, sign_payload


# --- Event routing ---


def test_ping_ignored(client):
    resp = client.post(
        "/webhook",
        content=b"{}",
        headers={"x-github-event": "ping"},
    )
    assert resp.status_code == 200
    assert resp.json() == {"status": "event ignored"}


def test_unknown_event_ignored(client):
    resp = client.post(
        "/webhook",
        content=b'{"action": "completed"}',
        headers={"x-github-event": "workflow_run"},
    )
    assert resp.status_code == 200
    assert resp.json() == {"status": "event ignored"}


# --- Signature verification ---


def test_invalid_signature_401(client_with_secret):
    payload = json.dumps(make_issue_payload()).encode()
    resp = client_with_secret.post(
        "/webhook",
        content=payload,
        headers={
            "x-github-event": "issues",
            "x-hub-signature-256": "sha256=bad",
        },
    )
    assert resp.status_code == 401


def test_missing_signature_401(client_with_secret):
    payload = json.dumps(make_issue_payload()).encode()
    resp = client_with_secret.post(
        "/webhook",
        content=payload,
        headers={"x-github-event": "issues"},
    )
    assert resp.status_code == 401


@patch("webhook_server.app.handle_new_issue")
def test_valid_signature_200(mock_handler, client_with_secret):
    payload = json.dumps(make_issue_payload()).encode()
    sig = sign_payload(payload)
    resp = client_with_secret.post(
        "/webhook",
        content=payload,
        headers={
            "x-github-event": "issues",
            "x-hub-signature-256": sig,
        },
    )
    assert resp.status_code == 200
    assert resp.json() == {"status": "issue handled"}


# --- Comment filtering ---


def test_bot_comment_skipped(client):
    payload = json.dumps(make_comment_payload(user_type="Bot")).encode()
    resp = client.post(
        "/webhook",
        content=payload,
        headers={"x-github-event": "issue_comment"},
    )
    assert resp.status_code == 200
    assert resp.json() == {"status": "skipped bot comment"}


def test_pr_comment_skipped(client):
    payload = json.dumps(make_comment_payload(has_pull_request=True)).encode()
    resp = client.post(
        "/webhook",
        content=payload,
        headers={"x-github-event": "issue_comment"},
    )
    assert resp.status_code == 200
    assert resp.json() == {"status": "skipped PR comment"}


# --- Handler dispatch ---


@patch("webhook_server.app.handle_new_issue")
def test_issues_opened_calls_handler(mock_handler, client):
    payload_dict = make_issue_payload(number=42, title="Bug", body="Details")
    payload = json.dumps(payload_dict).encode()
    resp = client.post(
        "/webhook",
        content=payload,
        headers={"x-github-event": "issues"},
    )
    assert resp.status_code == 200
    assert resp.json() == {"status": "issue handled"}
    mock_handler.assert_called_once_with(
        issue_number=42,
        issue_title="Bug",
        issue_body="Details",
        repo_url="https://github.com/test-owner/test-repo.git",
    )


@patch("webhook_server.app.handle_issue_comment")
def test_issue_comment_calls_handler(mock_handler, client):
    payload_dict = make_comment_payload(
        issue_number=7,
        comment_body="Please fix",
        comment_user="reviewer",
    )
    payload = json.dumps(payload_dict).encode()
    resp = client.post(
        "/webhook",
        content=payload,
        headers={"x-github-event": "issue_comment"},
    )
    assert resp.status_code == 200
    assert resp.json() == {"status": "comment handled"}
    mock_handler.assert_called_once_with(
        issue_number=7,
        comment_body="Please fix",
        comment_user="reviewer",
        repo_url="https://github.com/test-owner/test-repo.git",
    )
