---
name: read-issue
description: Reads details of a GitHub issue including title, description, labels, and comments. Use when the user wants to view issue information or start working on an issue.
---

# Read GitHub Issue

Retrieves and displays GitHub issue information including title, description, labels, assignees, and comments.

## Issue Information

!`gh issue view ${ARGUMENTS:-$ISSUE_NUMBER} --json title,state,labels,assignees,body,comments,url -q '"**Title:** \(.title)
**State:** \(.state)
**Labels:** \(if .labels | length > 0 then (.labels | map(.name) | join(", ")) else "None" end)
**Assignees:** \(if .assignees | length > 0 then (.assignees | map(.login) | join(", ")) else "None" end)
**Issue URL:** \(.url)
**Description:**
\(.body)
**Comments:**
\(if .comments | length > 0 then (.comments | map("**\(.author.login)** - \(.createdAt):\n\(.body)") | join("\n\n")) else "No comments" end)"' | cat`

## Instructions

**IMPORTANT: You MUST output a summary to the user.** After gathering the issue information above, display a formatted summary that includes:

1. **Issue Number** - The issue number (from `$ARGUMENTS` or `$ISSUE_NUMBER`)
2. **Title** - The issue title
3. **State** - Whether the issue is open or closed
4. **Labels** - Any labels attached to the issue
5. **Assignees** - Who is assigned to the issue (if any)
6. **Description** - The issue description/body
7. **Comments** - Summary of comments on the issue (if any)
8. **Issue URL** - Direct link to the issue

Format the output clearly using markdown so the user can see the issue details at a glance. This summary should always be visible in your response to the user.

After displaying the issue information, you should analyze the requirements and start planning how to address the issue.
