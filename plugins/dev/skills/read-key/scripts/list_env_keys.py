#!/usr/bin/env python3
"""
List all environment variable keys without exposing their values.
This script only outputs the names of environment variables.
"""

import os
import sys

def list_env_keys(filter_pattern=None):
    """
    List all environment variable keys.

    Args:
        filter_pattern: Optional string to filter keys (case-insensitive)

    Returns:
        List of environment variable keys
    """
    keys = sorted(os.environ.keys())

    if filter_pattern:
        filter_pattern = filter_pattern.lower()
        keys = [k for k in keys if filter_pattern in k.lower()]

    return keys

def main():
    filter_pattern = sys.argv[1] if len(sys.argv) > 1 else None

    keys = list_env_keys(filter_pattern)

    if not keys:
        if filter_pattern:
            print(f"No environment variables found matching '{filter_pattern}'")
        else:
            print("No environment variables found")
        return

    print(f"Found {len(keys)} environment variable(s):")
    print()
    for key in keys:
        print(f"  {key}")

if __name__ == "__main__":
    main()
