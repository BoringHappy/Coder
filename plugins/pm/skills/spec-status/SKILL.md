---
name: spec-status
description: Fetches the spec GitHub Issue and its task sub-issues to produce a full spec progress summary. Use when the user wants to know the current state of a feature spec.
---

# Spec Status

Fetches the spec GitHub Issue for `<feature-name>` and its task sub-issues to show a complete progress summary.

## Preflight

!`if [ -z "$ARGUMENTS" ]; then echo "[ERROR] No feature name provided. Usage: /pm:spec-status <feature-name>"; echo ""; echo "Available specs (open spec issues):"; gh issue list --label "spec" --state open --json number,title --jq '.[] | "  - \(.title) (#\(.number))"' 2>/dev/null || echo "  (none found)"; exit 1; fi`

!`echo "--- Fetching spec issue ---"; gh issue list --label "spec:$ARGUMENTS" --label "spec" --state all --json number,title,url,body,state,labels --jq 'if length == 0 then "[ERROR] No spec issue found for: $ENV.ARGUMENTS" else ".[0]" end' 2>/dev/null || echo "[ERROR] No spec issue found for: $ARGUMENTS"`

!`gh issue list --label "spec:$ARGUMENTS" --label "spec" --state all --json number,title,url,body,state,labels --jq '.[0] | "[OK] Spec issue #\(.number) [\(.state)]: \(.url)\n\(.body)"' 2>/dev/null`

!`echo "--- Task issues ---"; gh issue list --label "spec:$ARGUMENTS" --label "task" --state all --json number,title,state,url --jq '.[] | "#\(.number) [\(.state | ascii_upcase)] \(.title) \(.url)"' 2>/dev/null || echo "(none)"`

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
- If no task issues exist yet, suggest: "Run `/pm:spec-decompose $ARGUMENTS` to create task issues"

## Prerequisites
- A spec issue must exist for the given feature name
- GitHub CLI authenticated
