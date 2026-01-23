# Claude Code Skills

This directory contains custom skills for Claude Code that extend its capabilities with specialized workflows and integrations.

## Skills Overview

### Custom Skills (Project-Specific)

- **git-commit** - Stages all changes, creates a commit with a meaningful message, and pushes to the remote
- **get-pr-details** - Gets details of a GitHub pull request including title, description, file changes, and review comments
- **fix-pr-comments** - Reads comments from a GitHub pull request, fixes the issues mentioned, commits changes, and replies to comments
- **update-pr** - Updates the summary/description and optionally the title of a GitHub pull request

### External Skills

The following skills were imported from external sources:

#### agent-browser
**Source:** https://github.com/vercel-labs/agent-browser

Automates browser interactions for web testing, form filling, screenshots, and data extraction.

**Installation command:**
```bash
npx skills add https://github.com/vercel-labs/agent-browser --skill agent-browser
```

#### skill-creator
**Source:** https://github.com/anthropics/skills

Guide for creating effective skills. Provides templates, validation tools, and documentation for building new Claude Code skills.

**Installation command:**
```bash
npx skills add https://github.com/anthropics/skills --skill skill-creator
```

## Usage

Skills are invoked using the `/skill-name` syntax in Claude Code. For example:
- `/git-commit` - Commit and push changes
- `/get-pr-details 123` - Get details for PR #123
- `/agent-browser` - Start browser automation
- `/skill-creator` - Get guidance on creating new skills

## Development

Each skill is defined by a `SKILL.md` file that contains the prompt injected when the skill is invoked. See individual skill directories for their specific documentation and implementation details.
