#!/usr/bin/env python3
import json
import os
import sys

YELLOW = '\033[1;33m'
GREEN = '\033[1;32m'
BLUE = '\033[1;34m'
RESET = '\033[0m'

SETTINGS_FILE = os.path.expanduser("~/.claude/settings.json")

STATUS_LINE_CONFIG = {
    "type": "command",
    "command": "ccline",
    "padding": 0,
}


def main():
    print(f"{YELLOW}Setting up CCometixLine status line...{RESET}")

    os.makedirs(os.path.dirname(SETTINGS_FILE), exist_ok=True)

    if os.path.exists(SETTINGS_FILE):
        with open(SETTINGS_FILE, "r") as f:
            data = json.load(f)
    else:
        data = {}

    if "statusLine" in data:
        print(f"  {GREEN}✓ statusLine already configured, skipping{RESET}")
    else:
        print(f"  Adding statusLine to {BLUE}{SETTINGS_FILE}{RESET}...")
        data["statusLine"] = STATUS_LINE_CONFIG
        with open(SETTINGS_FILE, "w") as f:
            json.dump(data, f, indent=2)
            f.write("\n")
        print(f"  {GREEN}✓ statusLine configured{RESET}")

    print(f"{GREEN}✓ CCometixLine setup completed successfully{RESET}")


if __name__ == "__main__":
    main()
