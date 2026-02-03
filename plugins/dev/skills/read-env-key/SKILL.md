---
name: read-env-key
description: List environment variable keys without exposing their values. Use when the user wants to see what environment variables are available, check if a specific environment variable exists, or list environment variables matching a pattern. IMPORTANT - This skill only reads keys (names), never values.
context: fork
---

# Environment Variable Key Reader

List environment variable keys without exposing their values. This skill provides safe access to environment variable names only.

## Available Environment Variables

Current environment variable keys:
!`env | cut -d= -f1 | sort`

## Instructions

Use shell commands to list environment variable keys:

### List all environment variable keys

```bash
env | cut -d= -f1 | sort
```

### Filter environment variable keys

To filter keys by pattern (case-insensitive):

```bash
env | cut -d= -f1 | grep -i <pattern> | sort
```

Examples:
- `env | cut -d= -f1 | grep -i GIT | sort` - List all keys containing "GIT"
- `env | cut -d= -f1 | grep -i GITHUB | sort` - List all keys containing "GITHUB"
- `env | cut -d= -f1 | grep -i TOKEN | sort` - List all keys containing "TOKEN"

### Check if a specific key exists

To check if a specific environment variable key exists:

```bash
if [ -n "${KEY_NAME+x}" ]; then echo "✓ KEY_NAME exists"; else echo "✗ KEY_NAME does not exist"; fi
```

Or using printenv:

```bash
if printenv KEY_NAME > /dev/null 2>&1; then echo "✓ KEY_NAME exists"; else echo "✗ KEY_NAME does not exist"; fi
```

Examples:
- `if [ -n "${GITHUB_TOKEN+x}" ]; then echo "✓ GITHUB_TOKEN exists"; else echo "✗ GITHUB_TOKEN does not exist"; fi`
- `if printenv API_KEY > /dev/null 2>&1; then echo "✓ API_KEY exists"; else echo "✗ API_KEY does not exist"; fi`

## Security Note

This skill is designed to ONLY read environment variable keys (names), never their values. This prevents accidental exposure of sensitive information like tokens, passwords, or API keys.

## Prerequisites

- Must be run in a shell environment with environment variables set

