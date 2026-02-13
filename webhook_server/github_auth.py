"""GitHub authentication: PAT and GitHub App token management."""

import json
import os
import subprocess
import threading
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from datetime import datetime
from enum import Enum

import jwt

from .config import (
    GITHUB_APP_ID,
    GITHUB_APP_INSTALLATION_ID,
    GITHUB_APP_PRIVATE_KEY,
    GITHUB_APP_PRIVATE_KEY_FILE,
    logger,
)


class AuthMode(Enum):
    PAT = "pat"
    GITHUB_APP = "github_app"


@dataclass
class TokenState:
    token: str = ""
    expires_at: float = 0.0

    def is_expired(self, buffer_seconds: int = 300) -> bool:
        if not self.token:
            return True
        return time.time() >= (self.expires_at - buffer_seconds)


def _load_private_key() -> str:
    """Load the GitHub App private key from env var or file."""
    if GITHUB_APP_PRIVATE_KEY:
        return GITHUB_APP_PRIVATE_KEY
    if GITHUB_APP_PRIVATE_KEY_FILE:
        with open(GITHUB_APP_PRIVATE_KEY_FILE, "r") as f:
            return f.read()
    return ""


def _generate_jwt(app_id: str, private_key: str) -> str:
    """Generate a short-lived JWT for GitHub App authentication."""
    now = int(time.time())
    payload = {
        "iat": now - 60,
        "exp": now + (10 * 60),
        "iss": app_id,
    }
    return jwt.encode(payload, private_key, algorithm="RS256")


def _exchange_jwt_for_token(jwt_token: str, installation_id: str) -> tuple[str, float]:
    """Exchange a JWT for an installation access token. Returns (token, expires_at_epoch)."""
    url = f"https://api.github.com/app/installations/{installation_id}/access_tokens"
    req = urllib.request.Request(
        url,
        method="POST",
        headers={
            "Authorization": f"Bearer {jwt_token}",
            "Accept": "application/vnd.github+json",
            "X-GitHub-Api-Version": "2022-11-28",
        },
    )
    try:
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        raise RuntimeError(
            f"GitHub API error {e.code} exchanging JWT for token: {body}"
        ) from e
    token = data["token"]
    # Parse ISO 8601 expiry — GitHub returns e.g. "2024-01-01T00:00:00Z"
    expires_str = data.get("expires_at", "")
    if expires_str:
        dt = datetime.fromisoformat(expires_str.replace("Z", "+00:00"))
        expires_at = dt.timestamp()
    else:
        expires_at = time.time() + 3600
    return token, expires_at


def _gh_auth_login(token: str) -> None:
    """Authenticate the gh CLI with the given token."""
    env = os.environ.copy()
    env.pop("GITHUB_TOKEN", None)
    proc = subprocess.run(
        ["gh", "auth", "login", "--with-token"],
        input=token,
        capture_output=True,
        text=True,
        env=env,
    )
    if proc.returncode != 0:
        raise RuntimeError(f"gh auth login failed: {proc.stderr}")


def _gh_setup_git() -> None:
    """Configure git credential helper via gh."""
    proc = subprocess.run(["gh", "auth", "setup-git"], capture_output=True, text=True)
    if proc.returncode != 0:
        raise RuntimeError(f"gh auth setup-git failed: {proc.stderr}")


class GitHubAuthManager:
    """Manages GitHub authentication for the webhook server."""

    def __init__(self) -> None:
        self.mode: AuthMode | None = None
        self.pat_token: str = ""
        self.app_id: str = ""
        self.private_key: str = ""
        self.installation_id: str = ""
        self.token_state: TokenState = TokenState()
        self._refresh_lock = threading.Lock()

    def configure_from_env(self) -> None:
        """Determine auth mode from environment variables."""
        github_token = os.environ.get("GITHUB_TOKEN", "")
        if github_token:
            self.mode = AuthMode.PAT
            self.pat_token = github_token
            self.token_state = TokenState(token=github_token, expires_at=float("inf"))
            logger.info("GitHub auth: PAT mode")
            return

        app_id = GITHUB_APP_ID
        private_key = _load_private_key()
        if app_id and private_key:
            self.mode = AuthMode.GITHUB_APP
            self.app_id = app_id
            self.private_key = private_key
            self.installation_id = GITHUB_APP_INSTALLATION_ID
            logger.info(f"GitHub auth: App mode (app_id={app_id})")
            return

        raise RuntimeError(
            "No GitHub credentials configured. "
            "Set GITHUB_TOKEN for PAT mode, or GITHUB_APP_ID + private key for App mode."
        )

    def initial_auth(self) -> None:
        """Perform initial gh CLI authentication during startup."""
        if self.mode == AuthMode.PAT:
            _gh_auth_login(self.pat_token)
            _gh_setup_git()
            logger.info("GitHub auth: PAT login complete")
        elif self.mode == AuthMode.GITHUB_APP:
            if self.installation_id:
                self._refresh_app_token()
                logger.info("GitHub auth: App token acquired at startup")
            else:
                logger.info(
                    "GitHub auth: App mode, waiting for webhook to provide installation ID"
                )

    def set_installation_id_from_webhook(self, payload: dict) -> None:
        """Extract installation.id from a webhook payload if present."""
        installation = payload.get("installation", {})
        inst_id = installation.get("id")
        if inst_id and not self.installation_id:
            self.installation_id = str(inst_id)
            logger.info(f"GitHub auth: installation ID set from webhook: {self.installation_id}")

    def ensure_gh_auth(self) -> str:
        """Ensure gh CLI has a valid token. Returns the current token."""
        if self.mode == AuthMode.PAT:
            return self.pat_token
        if self.mode == AuthMode.GITHUB_APP:
            if self.token_state.is_expired():
                with self._refresh_lock:
                    # Double-check after acquiring lock
                    if self.token_state.is_expired():
                        self._refresh_app_token()
            return self.token_state.token
        raise RuntimeError("Auth not configured — call configure_from_env() first")

    def _refresh_app_token(self) -> None:
        """Generate a new JWT, exchange for installation token, and re-auth gh CLI."""
        if not self.installation_id:
            raise RuntimeError(
                "Cannot refresh App token: no installation ID. "
                "Set GITHUB_APP_INSTALLATION_ID or wait for a webhook event."
            )
        jwt_token = _generate_jwt(self.app_id, self.private_key)
        token, expires_at = _exchange_jwt_for_token(jwt_token, self.installation_id)
        self.token_state = TokenState(token=token, expires_at=expires_at)
        _gh_auth_login(token)
        _gh_setup_git()
        logger.info("GitHub auth: App token refreshed")


auth_manager = GitHubAuthManager()
