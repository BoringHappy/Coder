---
name: judge
description: Analyzes a GitHub issue and applies priority and category labels based on content, impact, and urgency.
---

# Judge GitHub Issue

Analyzes an issue and applies appropriate priority and category labels.

## Fetch Issue Data

!`gh issue view $ARGUMENTS --json title,body,labels,comments,url -q '"**Title:** \(.title)
**URL:** \(.url)
**Current Labels:** \(if .labels | length > 0 then (.labels | map(.name) | join(", ")) else "None" end)
**Body:**
\(.body)
**Comments:**
\(if .comments | length > 0 then (.comments | map("**\(.author.login)** (\(.createdAt)):\n\(.body)") | join("\n\n")) else "No comments" end)"' | cat`

## Instructions

Analyze the issue content and apply the appropriate labels.

### Priority Label
Determine one of:
- `priority:high` — Blocks users or core functionality, security issue, data loss risk, or affects many users
- `priority:medium` — Degrades experience or has a workaround, moderate scope
- `priority:low` — Minor inconvenience, cosmetic, or edge case

### Category Label
Use an existing category label if already present. Otherwise infer from:
- Title prefix `[Bug]` or content describing broken behavior → `bug`
- Title prefix `[Feature]` or content requesting new functionality → `enhancement`
- Title prefix `[Docs]` or content about documentation → `documentation`
- Content asking a question → `question`

### Apply Labels
Run the following to apply both labels at once:
```bash
gh issue edit $ARGUMENTS --add-label "<priority-label>,<category-label>"
```

Only add the category label if one is not already present on the issue.

### Output Summary
After applying labels, output a summary to the user:
- Issue number and title
- Priority label applied and reasoning
- Category label applied (or existing label kept) and reasoning
- Confirmation that labels were successfully added
