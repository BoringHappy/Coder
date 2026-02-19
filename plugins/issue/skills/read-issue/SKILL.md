---
name: read-issue
description: Reads details of a GitHub issue including title, description, labels, and comments. Use when the user wants to view issue information or start working on an issue.
---

# Read GitHub Issue

Retrieves and displays GitHub issue information including title, description, labels, assignees, and comments.

## Issue Information

!`gh issue view $ARGUMENTS --json title,state,labels,assignees,body,url,comments --template '{{.title}}{{"\n"}}{{.state}}{{"\n"}}{{.url}}{{"\n"}}Labels: {{range .labels}}{{.name}} {{end}}{{"\n"}}Assignees: {{range .assignees}}{{.login}} {{end}}{{"\n"}}{{.body}}{{"\n"}}{{range .comments}}{{.author.login}} - {{.createdAt}}:{{"\n"}}{{.body}}{{"\n\n"}}{{end}}' | cat`

## Instructions

**IMPORTANT: You MUST output a summary to the user.** After gathering the issue information above, display a formatted summary that includes:

1. **Issue Number** - The issue number (from `$ARGUMENTS`)
2. **Title** - The issue title
3. **State** - Whether the issue is open or closed
4. **Labels** - Any labels attached to the issue (or "None" if empty)
5. **Assignees** - Who is assigned to the issue (or "None" if empty)
6. **Description** - The issue description/body
7. **Comments** - Summary of comments on the issue (if any)
8. **Issue URL** - Direct link to the issue

Format the output clearly using markdown so the user can see the issue details at a glance. This summary should always be visible in your response to the user.
