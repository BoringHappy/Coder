# CodeMate Plugin Marketplace

A local plugin marketplace for CodeMate that provides PR workflow management and development tools.

## Overview

This marketplace is automatically configured when CodeMate starts up. It contains two plugins that extend Claude Code with specialized capabilities for GitHub PR workflows and development utilities.

## Plugins

### PR Plugin (`pr@codemate`)

GitHub Pull Request workflow management plugin.

**Skills:**
- `/pr:get-details` - Fetch comprehensive PR information including title, description, files, and comments
- `/pr:commit` - Stage all changes, create a meaningful commit, and push to remote
- `/pr:fix-comments` - Automatically address PR review feedback
- `/pr:update` - Update PR title and/or description based on changes

**Location:** `marketplace/plugins/pr/`

### External Plugin (`external@codemate`)

External tools and utilities for development workflows.

**Skills:**
- `/agent-browser` - Browser automation for web testing, form filling, and data extraction
- `/skill-creator` - Interactive guide for creating new Claude Code skills

**Location:** `marketplace/plugins/external/`

## Marketplace Structure

```
marketplace/
├── .claude-plugin/
│   └── marketplace.json          # Marketplace catalog
└── plugins/
    ├── pr/                        # PR workflow plugin
    │   ├── .claude-plugin/
    │   │   └── plugin.json
    │   ├── README.md
    │   └── skills/
    │       ├── get-details/
    │       ├── commit/
    │       ├── fix-comments/
    │       └── update/
    └── external/                  # External tools plugin
        ├── .claude-plugin/
        │   └── plugin.json
        └── skills/
            ├── agent-browser/
            └── skill-creator/
```

## Configuration

The marketplace is automatically configured in `.claude/settings.json` during container startup:

```json
{
  "extraKnownMarketplaces": {
    "codemate": {
      "source": "/usr/local/bin/setup/marketplace"
    }
  },
  "enabledPlugins": {
    "pr@codemate": true,
    "external@codemate": true
  }
}
```

## Usage

Once the container starts, all plugins are automatically enabled and their skills are available:

```bash
# PR workflow commands
/pr:get-details
/pr:commit
/pr:fix-comments
/pr:update

# External tools
/agent-browser
/skill-creator
```

## Adding New Plugins

To add a new plugin to this marketplace:

1. Create a plugin directory under `marketplace/plugins/your-plugin/`
2. Add `.claude-plugin/plugin.json` with plugin metadata
3. Add your skills in `skills/` directory
4. Update `marketplace/.claude-plugin/marketplace.json` to include the new plugin

## Version

1.0.0
