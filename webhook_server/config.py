"""Configuration constants and logger for the webhook server."""

import os
import sys
from pathlib import Path

from loguru import logger

# Configure loguru: remove default handler, add stdout with matching format
logger.remove()
logger.add(sys.stdout, format="{time:YYYY-MM-DD HH:mm:ss.SSS} [{level}] {message}", level="INFO")

# Server settings
PORT = int(os.getenv("WEBHOOK_PORT", "8080"))
WEBHOOK_SECRET = os.getenv("GITHUB_WEBHOOK_SECRET", "")
WORKSPACES_ROOT = os.getenv("WORKSPACES_ROOT", str(Path.home() / "workspaces"))
SESSION_DATA_DIR = os.getenv("SESSION_DATA_DIR", str(Path.home() / ".session-data"))

# System prompt: check env, then look relative to package, then Docker path
_PACKAGE_DIR = Path(__file__).resolve().parent
_DEFAULT_PROMPT_PATHS = [
    _PACKAGE_DIR.parent / "docker" / "setup" / "prompt" / "system_prompt_issue.txt",  # repo root
    Path("/usr/local/bin/setup/prompt/system_prompt_issue.txt"),                       # Docker
]
SYSTEM_PROMPT_FILE = os.getenv("SYSTEM_PROMPT_FILE", "")
if not SYSTEM_PROMPT_FILE:
    for _p in _DEFAULT_PROMPT_PATHS:
        if _p.exists():
            SYSTEM_PROMPT_FILE = str(_p)
            break

# GitHub App authentication (alternative to GITHUB_TOKEN)
GITHUB_APP_ID = os.getenv("GITHUB_APP_ID", "")
GITHUB_APP_PRIVATE_KEY = os.getenv("GITHUB_APP_PRIVATE_KEY", "")
GITHUB_APP_PRIVATE_KEY_FILE = os.getenv("GITHUB_APP_PRIVATE_KEY_FILE", "")
GITHUB_APP_INSTALLATION_ID = os.getenv("GITHUB_APP_INSTALLATION_ID", "")
