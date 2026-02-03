# Environment Variable Keys Plugin

A CodeMate plugin for safely reading environment variable keys without exposing their values.

## Skills

### `/env-keys:read-key`

List environment variable keys without exposing their values.

**Usage:**
- List all environment variable keys
- Filter keys by pattern (case-insensitive)
- Check if specific environment variables exist

**Security:**
This skill only reads environment variable names (keys), never their values. This prevents accidental exposure of sensitive information.

## Installation

This plugin is designed to be installed via the CodeMate plugin marketplace.

## Examples

```bash
# List all environment variable keys
/env-keys:read-key

# Filter for specific patterns
/env-keys:read-key GIT
/env-keys:read-key TOKEN
```
