---
name: spec-status
description: Fetches the spec GitHub Issue and its task sub-issues to produce a full spec progress summary. Use when the user wants to know the current state of a feature spec.
argument-hint: <issue-number>
---

# Spec Status

Fetches the spec GitHub Issue and its task sub-issues to show a complete progress summary.

Usage: `/pm:spec-status <issue-number>`

## Preflight

!`if [ -z "$ARGUMENTS" ]; then echo "[ERROR] No issue number provided. Usage: /pm:spec-status <issue-number>"; echo ""; echo "Available specs:"; gh issue list --label "spec" --state open --json number,title --jq '.[] | "  #\(.number) \(.title)"' 2>/dev/null || echo "  (none found)"; exit 1; fi`

!`echo "--- Fetching spec issue ---"; gh issue view "$ARGUMENTS" --json number,title,url,body,state,labels --jq '"[OK] Spec issue #\(.number) [\(.state)]: \(.url)\n\(.body)"' 2>/dev/null || echo "[ERROR] Issue #$ARGUMENTS not found"`

!`echo "--- Task issues ---"; REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner'); gh api /repos/$REPO/issues/$ARGUMENTS/sub_issues --jq '.[] | "#\(.number) [\(.state | ascii_upcase)] \(.title) \(.html_url)"' 2>/dev/null || echo "(none)"`

## Instructions

Using the spec issue and task issues fetched above, produce a formatted status summary:

### Output Format

```
## Spec: $ARGUMENTS
Issue: #<spec_issue_number> → <spec_issue_url>
State: <OPEN|CLOSED>

### Tasks (<closed>/<total> complete)

| # | Title | Issue | Status |
|---|-------|-------|--------|
| 1 | <title> | #<num> | ✅ CLOSED / 🔄 OPEN |
| 2 | <title> | #<num> | ✅ CLOSED / 🔄 OPEN |

### Progress
████████░░░░░░░░░░░░ 40% (2/5 tasks closed)

### Next Up
- #<num> <title> — <issue_url>
```

Rules:
- ✅ = issue state is `CLOSED`
- 🔄 = issue state is `OPEN`
- Progress bar: each `█` = 5%, fill based on closed/total ratio
- "Next Up": open task issues ready to work on
- If all tasks are closed, show: "🎉 Spec complete!"
- If no task issues exist yet, suggest: "Run `/pm:spec-decompose <issue_number>` to create task issues"

## Prerequisites
- A spec issue must exist
- GitHub CLI authenticated
