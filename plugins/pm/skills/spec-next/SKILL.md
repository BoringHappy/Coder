---
name: spec-next
description: Finds the next actionable task for a spec by checking GitHub Issue status. Use when the user wants to know what to work on next.
---

# Spec Next

Fetches open task issues for `<feature-name>` from GitHub and identifies the next task(s) ready to work on.

## Preflight

!`
if [ -z "$ARGUMENTS" ]; then
  echo "[ERROR] No feature name provided. Usage: /pm:spec-next <feature-name>"
  echo ""
  echo "Available specs (open spec issues):"
  gh issue list --label "spec" --state open --json number,title --jq '.[] | "  • \(.title) (#\(.number))"' 2>/dev/null || echo "  (none found)"
  exit 1
fi

# Fetch the spec issue
echo "--- Fetching spec issue ---"
SPEC_ISSUE=$(gh issue list --label "spec:$ARGUMENTS" --label "spec" --state open --json number,title,url --jq '.[0]' 2>/dev/null || echo "")
if [ -z "$SPEC_ISSUE" ] || [ "$SPEC_ISSUE" = "null" ]; then
  echo "[ERROR] No open spec issue found for: $ARGUMENTS"
  exit 1
fi

SPEC_ISSUE_NUMBER=$(echo "$SPEC_ISSUE" | jq -r '.number')
echo "[OK] Spec issue #$SPEC_ISSUE_NUMBER"

# Fetch all task issues (open and closed) for dependency resolution
echo ""
echo "--- All task issues (with bodies for dependency resolution) ---"
gh issue list --label "spec:$ARGUMENTS" --label "task" --state all \
  --json number,title,state,url,body \
  --jq '.' 2>/dev/null || echo "[]"
`

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
