"""Tests for webhook_server.github_auth module."""

import time
from unittest.mock import patch

import pytest

from webhook_server.github_auth import AuthMode, GitHubAuthManager, TokenState, _load_private_key


# --- TokenState ---


def test_empty_token_is_expired():
    ts = TokenState()
    assert ts.is_expired()


def test_future_token_not_expired():
    ts = TokenState(token="tok", expires_at=time.time() + 3600)
    assert not ts.is_expired()


def test_token_within_buffer_expired():
    ts = TokenState(token="tok", expires_at=time.time() + 240)
    assert ts.is_expired(buffer_seconds=300)


# --- _load_private_key ---


@patch("webhook_server.github_auth.GITHUB_APP_PRIVATE_KEY", "inline-key-content")
@patch("webhook_server.github_auth.GITHUB_APP_PRIVATE_KEY_FILE", "")
def test_load_private_key_from_env():
    assert _load_private_key() == "inline-key-content"


def test_load_private_key_from_file(tmp_path):
    key_file = tmp_path / "test_key.pem"
    key_file.write_text("file-key-content")
    with patch("webhook_server.github_auth.GITHUB_APP_PRIVATE_KEY", ""), \
         patch("webhook_server.github_auth.GITHUB_APP_PRIVATE_KEY_FILE", str(key_file)):
        assert _load_private_key() == "file-key-content"


@patch("webhook_server.github_auth.GITHUB_APP_PRIVATE_KEY", "")
@patch("webhook_server.github_auth.GITHUB_APP_PRIVATE_KEY_FILE", "")
def test_load_private_key_empty():
    assert _load_private_key() == ""


# --- configure_from_env ---


def test_configure_pat_mode():
    mgr = GitHubAuthManager()
    with patch.dict("os.environ", {"GITHUB_TOKEN": "ghp_test123"}, clear=False):
        mgr.configure_from_env()
    assert mgr.mode == AuthMode.PAT
    assert mgr.pat_token == "ghp_test123"
    assert not mgr.token_state.is_expired()


@patch("webhook_server.github_auth.GITHUB_APP_ID", "12345")
@patch("webhook_server.github_auth._load_private_key", return_value="-----BEGIN RSA PRIVATE KEY-----\nfake\n-----END RSA PRIVATE KEY-----")
def test_configure_app_mode(mock_key):
    mgr = GitHubAuthManager()
    with patch.dict("os.environ", {}, clear=False):
        env = dict(**{k: v for k, v in __import__("os").environ.items() if k != "GITHUB_TOKEN"})
        with patch.dict("os.environ", env, clear=True):
            mgr.configure_from_env()
    assert mgr.mode == AuthMode.GITHUB_APP
    assert mgr.app_id == "12345"


@patch("webhook_server.github_auth.GITHUB_APP_ID", "")
@patch("webhook_server.github_auth._load_private_key", return_value="")
def test_configure_no_creds_raises(mock_key):
    mgr = GitHubAuthManager()
    with patch.dict("os.environ", {}, clear=False):
        env = {k: v for k, v in __import__("os").environ.items() if k != "GITHUB_TOKEN"}
        with patch.dict("os.environ", env, clear=True):
            with pytest.raises(RuntimeError, match="No GitHub credentials configured"):
                mgr.configure_from_env()


# --- set_installation_id_from_webhook ---


def test_set_installation_id_from_webhook():
    mgr = GitHubAuthManager()
    payload = {"installation": {"id": 98765}, "action": "opened"}
    mgr.set_installation_id_from_webhook(payload)
    assert mgr.installation_id == "98765"


# --- ensure_gh_auth ---


def test_ensure_token_pat_returns_static():
    mgr = GitHubAuthManager()
    mgr.mode = AuthMode.PAT
    mgr.pat_token = "ghp_static"
    mgr.token_state = TokenState(token="ghp_static", expires_at=float("inf"))
    assert mgr.ensure_gh_auth() == "ghp_static"


def test_ensure_token_app_refreshes_when_expired():
    mgr = GitHubAuthManager()
    mgr.mode = AuthMode.GITHUB_APP
    mgr.app_id = "123"
    mgr.private_key = "fake-key"
    mgr.installation_id = "456"
    mgr.token_state = TokenState(token="", expires_at=0)

    with patch.object(mgr, "_refresh_app_token") as mock_refresh:
        mock_refresh.side_effect = lambda: setattr(
            mgr, "token_state", TokenState(token="ghs_new", expires_at=time.time() + 3600)
        )
        result = mgr.ensure_gh_auth()
    mock_refresh.assert_called_once()
    assert result == "ghs_new"
