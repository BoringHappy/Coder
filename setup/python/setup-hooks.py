#!/usr/bin/env python3
"""Sync hooks from workspace to ~/.claude/settings.json without duplicates."""
import json
from pathlib import Path

HOOKS_DIR = Path("/home/agent/workspace/hooks")
SETTINGS_FILE = Path("/home/agent/.claude/settings.json")


def get_hooks_config():
    """Define hooks configuration."""
    return {
        "SessionStart": [
            {
                "hooks": [
                    {
                        "type": "prompt",
                        "prompt": "Run /get-pr-details to fetch current PR information and display it to the user.",
                    }
                ]
            }
        ],
        "PostToolUse": [
            {
                "matcher": "Edit|Write",
                "hooks": [
                    {
                        "type": "command",
                        "command": f"python3 {HOOKS_DIR}/format-code.py",
                    }
                ],
            }
        ],
        "Stop": [
            {
                "hooks": [
                    {
                        "type": "prompt",
                        "prompt": "If there are uncommitted changes, run /git-commit to stage, commit, and push them.",
                    }
                ]
            }
        ],
    }


def hooks_equal(h1, h2):
    """Check if two hook entries are equivalent."""
    return json.dumps(h1, sort_keys=True) == json.dumps(h2, sort_keys=True)


def merge_hooks(existing, new_hooks):
    """Merge new hooks into existing without duplicates."""
    for event, hook_list in new_hooks.items():
        if event not in existing:
            existing[event] = hook_list
            continue

        for new_hook in hook_list:
            is_duplicate = any(hooks_equal(new_hook, eh) for eh in existing[event])
            if not is_duplicate:
                existing[event].append(new_hook)

    return existing


def main():
    print("Setting up hooks...")

    settings = {}
    if SETTINGS_FILE.exists():
        settings = json.loads(SETTINGS_FILE.read_text())

    existing_hooks = settings.get("hooks", {})
    new_hooks = get_hooks_config()
    merged = merge_hooks(existing_hooks, new_hooks)

    settings["hooks"] = merged
    SETTINGS_FILE.write_text(json.dumps(settings, indent=2) + "\n")

    print("Hooks synced to settings.json")


if __name__ == "__main__":
    main()
