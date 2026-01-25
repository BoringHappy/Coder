# CodeMate Plugin Marketplace

A local plugin marketplace for CodeMate that provides Git and PR workflow management.

## Overview

This marketplace is automatically configured when CodeMate starts up. It contains plugins that extend Claude Code with specialized capabilities for Git and GitHub PR workflows.

## Plugins

### Git Plugin (`git@codemate`)

Git workflow management tools.

**Skills:**
- `/git:commit` - Stage all changes, create a meaningful commit, and push to remote

**Location:** `marketplace/plugins/git/`

### PR Plugin (`pr@codemate`)

GitHub Pull Request workflow management plugin.

**Skills:**
- `/pr:get-details` - Fetch comprehensive PR information including title, description, files, and comments
- `/pr:fix-comments` - Automatically address PR review feedback
- `/pr:update` - Update PR title and/or description based on changes

**Location:** `marketplace/plugins/pr/`

## Marketplace Structure

```
marketplace/
├── .claude-plugin/
│   └── marketplace.json          # Marketplace catalog
└── plugins/
    ├── git/                       # Git workflow plugin
    │   ├── .claude-plugin/
    │   │   └── plugin.json
    │   └── skills/
    │       └── commit/
    └── pr/                        # PR workflow plugin
        ├── .claude-plugin/
        │   └── plugin.json
        ├── README.md
        └── skills/
            ├── get-details/
            ├── fix-comments/
            └── update/
```

## Configuration

Plugins are installed at Docker build time using the `claude plugin` CLI commands in the Dockerfile.

## Usage

Once the container starts, all plugins are automatically enabled and their skills are available:

```bash
# Git workflow commands
/git:commit

# PR workflow commands
/pr:get-details
/pr:fix-comments
/pr:update
```

## Adding New Plugins

To add a new plugin to this marketplace:

1. Create a plugin directory under `marketplace/plugins/your-plugin/`
2. Add `.claude-plugin/plugin.json` with plugin metadata
3. Add your skills in `skills/` directory
4. Update `marketplace/.claude-plugin/marketplace.json` to include the new plugin
5. Update `Dockerfile` to install the new plugin

## Version

1.0.0
