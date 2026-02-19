---
name: classify-issue
description: Identifies unclear or missing information in a GitHub issue and posts clarifying questions as a comment. Adds a needs-more-info label if clarification is needed.
---

# Classify GitHub Issue

Identifies unclear or missing information in an issue and posts targeted clarifying questions as a comment.

## Fetch Issue Data

!`gh issue view $ARGUMENTS --json title,body,labels,comments,url -q '"**Title:** \(.title)
**URL:** \(.url)
**Labels:** \(if .labels | length > 0 then (.labels | map(.name) | join(", ")) else "None" end)
**Body:**
\(.body)
**Comments:**
\(if .comments | length > 0 then (.comments | map("**\(.author.login)** (\(.createdAt)):\n\(.body)") | join("\n\n")) else "No comments" end)"' | cat`

## Fetch Issue Templates

!`ls .github/ISSUE_TEMPLATE/ 2>/dev/null && echo "---" && for f in .github/ISSUE_TEMPLATE/*.md .github/ISSUE_TEMPLATE/*.yml .github/ISSUE_TEMPLATE/*.yaml; do [ -f "$f" ] && echo "=== $f ===" && cat "$f" && echo; done || echo "No issue templates found"`

## Instructions

### Step 1 — Match Template
Identify the relevant issue template based on labels or title prefix (same logic as `issue:refine-issue`).

### Step 2 — Identify Unclear Items
Check for:
- Missing required template fields (e.g., steps to reproduce, expected vs actual behavior, environment info)
- Vague or ambiguous descriptions that don't provide enough detail to act on
- Missing version, OS, or environment information for bug reports
- Feature requests lacking use case or acceptance criteria
- Information already answered in comments (skip those — don't ask again)

### Step 3 — Decide and Act

**If clarification is needed:**

Compose a polite comment with specific, numbered questions. Example format:
```
Thanks for opening this issue! To help us address it effectively, could you clarify a few things?

1. <specific question about missing/unclear field>
2. <specific question about missing/unclear field>
...

This will help us reproduce and prioritize the issue.
```

Post the comment:
```bash
gh issue comment $ARGUMENTS --body "<composed comment>"
```

Add the label:
```bash
gh issue edit $ARGUMENTS --add-label "needs-more-info"
```

**If the issue is sufficiently clear:**

Report to the user that the issue contains all necessary information and no clarification is needed. Do not post any comment or add any label.

### Step 4 — Output Summary
Tell the user:
- Whether clarification was needed
- If yes: what questions were asked and confirm the `needs-more-info` label was added
- If no: confirm the issue is clear and no action was taken
