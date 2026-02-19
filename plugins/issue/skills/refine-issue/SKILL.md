---
name: refine-issue
description: Rewrites an issue body to fully satisfy the matching issue template, incorporating context from comments. Uses a plan-then-execute workflow requiring user approval before making changes.
---

# Refine GitHub Issue

Rewrites an issue body to fully satisfy the matching issue template, incorporating context from comments. Requires user approval before making any changes.

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

**IMPORTANT: This is a plan-then-execute workflow. You MUST get user approval before editing the issue.**

### Step 1 — Detect Issue Type
Analyze the issue labels and title prefix to determine the issue type:
- Labels containing `bug` or title starting with `[Bug]` → use the bug report template
- Labels containing `enhancement`/`feature` or title starting with `[Feature]` → use the feature request template
- Labels containing `documentation`/`docs` or title starting with `[Docs]` → use the docs template
- If no match, use the closest template or the default template

### Step 2 — Analyze Gaps
Compare the current issue body against the matched template fields. Identify:
- Missing required sections
- Incomplete or vague descriptions
- Information available in comments that should be incorporated into the body
- Fields that need to be filled in or expanded

### Step 3 — Plan Phase (REQUIRED)
Present to the user:
1. Which template was matched and why
2. A summary of the gaps found
3. The **full proposed refined body** that would be written to the issue

Then ask: "Does this look good? Should I update the issue with this refined body?"

**Do NOT call `gh issue edit` until the user explicitly approves.**

### Step 4 — Execute (only after approval)
Once the user approves, update the issue body:
```bash
gh issue edit $ARGUMENTS --body "<approved refined body>"
```

Confirm the update was successful and show the issue URL.

### Step 5 — Auto-triage
After successfully updating the issue body, invoke `/issue:triage-issue $ARGUMENTS` to automatically apply priority and category labels.
