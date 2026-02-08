"""Configuration constants and logger for the webhook server."""

import logging
import os
import sys
from pathlib import Path

# Server settings
PORT = int(os.getenv("WEBHOOK_PORT", "8080"))
WEBHOOK_SECRET = os.getenv("GITHUB_WEBHOOK_SECRET", "")
WORKSPACES_ROOT = os.getenv("WORKSPACES_ROOT", str(Path.home() / "workspaces"))

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

# Logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[logging.StreamHandler(sys.stdout)],
)
logger = logging.getLogger("webhook_server")
