---
name: read-env-key
description: List environment variable keys without exposing their values. Use when the user wants to see what environment variables are available, check if a specific environment variable exists, or list environment variables matching a pattern. IMPORTANT - This skill only reads keys (names), never values.
context: fork
---

# Environment Variable Key Reader

List environment variable keys without exposing their values. This skill provides safe access to environment variable names only.

## Available Environment Variables

Current environment variable keys:
!`python3 scripts/list_env_keys.py`

## Instructions

Use the provided script to list environment variable keys:

### List all environment variable keys

```bash
python3 scripts/list_env_keys.py
```

### Filter environment variable keys

To filter keys by pattern (case-insensitive):

```bash
python3 scripts/list_env_keys.py <pattern>
```

Examples:
- `python3 scripts/list_env_keys.py GIT` - List all keys containing "GIT"
- `python3 scripts/list_env_keys.py GITHUB` - List all keys containing "GITHUB"
- `python3 scripts/list_env_keys.py TOKEN` - List all keys containing "TOKEN"

### Check if a specific key exists

To check if a specific environment variable key exists:

```bash
python3 scripts/check_env_key.py <KEY_NAME>
```

Examples:
- `python3 scripts/check_env_key.py GITHUB_TOKEN` - Check if GITHUB_TOKEN exists
- `python3 scripts/check_env_key.py API_KEY` - Check if API_KEY exists

The script exits with code 0 if the key exists, 1 if it doesn't.

## Security Note

This skill is designed to ONLY read environment variable keys (names), never their values. This prevents accidental exposure of sensitive information like tokens, passwords, or API keys.

## Prerequisites

- Python 3 must be available
- Must be run in an environment with environment variables set
