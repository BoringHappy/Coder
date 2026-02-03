# Dev Plugin

A CodeMate plugin providing development utilities.

## Skills

### `/dev:read-env-key`

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
/dev:read-env-key

# Filter for specific patterns
/dev:read-env-key GIT
/dev:read-env-key TOKEN
```
