---
name: spec-next
description: Finds the next actionable task for a spec by checking GitHub Issue status. Use when the user wants to know what to work on next.
argument-hint: <issue-number-or-feature-name>
---

# Spec Next

Fetches open task issues for a spec from GitHub and identifies the next task(s) ready to work on.

Usage: `/pm:spec-next <issue-number-or-feature-name>`

## Preflight

!`if [ -z "$ARGUMENTS" ]; then echo "[ERROR] No argument provided. Usage: /pm:spec-next <issue-number-or-feature-name>"; echo ""; echo "Available specs:"; gh issue list --label "spec" --state open --json number,title --jq '.[] | "  #\(.number) \(.title)"' 2>/dev/null || echo "  (none found)"; exit 1; fi`

!`echo "--- Fetching spec issue ---"; if echo "$ARGUMENTS" | grep -qE '^[0-9]+$'; then gh issue view "$ARGUMENTS" --json number,title,url,state --jq '"[OK] Spec issue #\(.number)"' 2>/dev/null || echo "[ERROR] Issue #$ARGUMENTS not found"; else gh issue list --label "spec:$ARGUMENTS" --label "spec" --state open --json number,title,url --jq 'if length > 0 then .[0] | "[OK] Spec issue #\(.number)" else "[ERROR] No open spec issue found for: $ENV.ARGUMENTS" end' 2>/dev/null; fi`

!`echo "--- All task issues (with bodies for dependency resolution) ---"; if echo "$ARGUMENTS" | grep -qE '^[0-9]+$'; then SPEC_LABEL=$(gh issue view "$ARGUMENTS" --json labels --jq '[.labels[].name | select(startswith("spec:"))] | .[0]' 2>/dev/null); gh issue list --label "$SPEC_LABEL" --label "task" --state all --json number,title,state,url,body --jq '.' 2>/dev/null || echo "[]"; else gh issue list --label "spec:$ARGUMENTS" --label "task" --state all --json number,title,state,url,body --jq '.' 2>/dev/null || echo "[]"; fi`

## Instructions

Using the task issues fetched above, find the next task(s) ready to work on.

### Algorithm

1. Parse the JSON array of task issues from the `--- All task issues ---` section of preflight (both OPEN and CLOSED).
2. A task is **ready** if its state is `OPEN` and it has no open dependencies.
   - Dependencies are inferred from the issue body: look for "Depends on:" lines referencing other task issue numbers (e.g. `#42`) or task titles. Use semantic understanding to match referenced titles to actual issues — a reference like "depends on the database setup task" should match an issue titled "Set up database schema".
   - A dependency is resolved if the referenced issue is `CLOSED`.
3. A task is **blocked** if any of its dependencies are still `OPEN`.

### Output Format

```
## Next Task(s) for: $ARGUMENTS

### ✅ Ready to Work On
- #<issue> <title> — <issue_url>

### ⏳ Blocked
- #<issue> <title> — waiting on: #<dep_issue> <dep_title>

### 💡 Suggestion
<one-line recommendation on what to pick up next>
```

Rules:
- If no tasks exist yet, suggest: "Run `/pm:spec-decompose $ARGUMENTS` to create task issues."
- If all tasks are closed, show: "🎉 All tasks complete!"
- If multiple tasks are ready, list all — the user picks.
- "Suggestion" should recommend the first ready task by issue number.

## Prerequisites
- A spec issue must exist for the given feature name
- GitHub CLI authenticated
