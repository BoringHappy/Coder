#!/usr/bin/env python3
"""
Check if a specific environment variable key exists.
This script only checks for the existence of a key, never reads its value.
"""

import os
import sys

def check_env_key(key_name):
    """
    Check if an environment variable key exists.

    Args:
        key_name: The environment variable key to check

    Returns:
        True if the key exists, False otherwise
    """
    return key_name in os.environ

def main():
    if len(sys.argv) < 2:
        print("Usage: check_env_key.py <KEY_NAME>")
        print("Example: check_env_key.py GITHUB_TOKEN")
        sys.exit(1)

    key_name = sys.argv[1]
    exists = check_env_key(key_name)

    if exists:
        print(f"✓ Environment variable '{key_name}' exists")
        sys.exit(0)
    else:
        print(f"✗ Environment variable '{key_name}' does not exist")
        sys.exit(1)

if __name__ == "__main__":
    main()
