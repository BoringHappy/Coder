---
name: spec-status
description: Reads a SPEC.md and fetches live GitHub Issue status for each task to produce a full spec progress summary. Use when the user wants to know the current state of a feature spec.
---

# Spec Status

Reads `.claude/specs/$ARGUMENTS.md` and fetches live issue status from GitHub to show a complete progress summary.

## Preflight

!`
SPEC=".claude/specs/$ARGUMENTS.md"

if [ -z "$ARGUMENTS" ]; then
  echo "[ERROR] No feature name provided. Usage: /pm:spec-status <feature-name>"
  # List available specs
  if [ -d ".claude/specs" ]; then
    echo ""
    echo "Available specs:"
    for f in .claude/specs/*.md; do
      [ -f "$f" ] && echo "  • $(basename "$f" .md)"
    done
  fi
  exit 1
fi

if [ ! -f "$SPEC" ]; then
  echo "[ERROR] Spec not found: $SPEC"
  if [ -d ".claude/specs" ]; then
    echo ""
    echo "Available specs:"
    for f in .claude/specs/*.md; do
      [ -f "$f" ] && echo "  • $(basename "$f" .md)"
    done
  fi
  exit 1
fi

echo "--- Spec frontmatter ---"
cat "$SPEC"
echo ""

# Fetch live issue statuses for all synced tasks
echo "--- Live issue statuses ---"
grep "issue_url:" "$SPEC" | grep "https" | sed 's/.*issue_url: *"//' | sed 's/"//' | while read url; do
  issue_num=$(echo "$url" | grep -oE '[0-9]+$')
  if [ -n "$issue_num" ]; then
    gh issue view "$issue_num" --json number,title,state,labels \
      -q '"#\(.number) [\(.state | ascii_upcase)] \(.title) \(if (.labels | length) > 0 then "[\(.labels | map(.name) | join(", "))]" else "" end)"' 2>/dev/null || echo "#$issue_num [ERROR] Could not fetch"
  fi
done
`

## Instructions

Using the spec content and live issue statuses fetched above, produce a formatted status summary:

### Output Format

```
## Spec: $ARGUMENTS
Status: <spec frontmatter status>
Created: <created date>

### Tasks (<closed>/<total> complete)

| # | Title | Tags | Issue | Status |
|---|-------|------|-------|--------|
| 1 | <title> | <tags> | #<num> | ✅ CLOSED / 🔄 OPEN / ⚠️ not synced |
| 2 | <title> | <tags> | #<num> | ✅ CLOSED / 🔄 OPEN / ⚠️ not synced |

### Progress
████████░░░░░░░░░░░░ 40% (2/5 tasks closed)

### Blocked Tasks
- #<num> <title> — waiting on: <dependency titles>

### Next Up
- #<num> <title> — <issue url>
```

Rules:
- ✅ = issue state is `CLOSED`
- 🔄 = issue state is `OPEN`
- ⚠️ = task has no issue yet (not synced)
- Progress bar: each `█` = 5%, fill based on closed/total ratio
- "Blocked Tasks": for each task with `depends_on` entries, check if those dependency task indices are CLOSED in the fetched issue statuses. If any dependency is still OPEN or unsynced, the task is blocked. Cross-reference by matching `depends_on` index (1-based) to the task list order.
- "Next Up": open tasks with no unresolved dependencies (ready to work on)
- If all tasks are closed, show: "🎉 Spec complete!"
- If no tasks are synced yet, suggest: "Run `/pm:spec-sync $ARGUMENTS` to create GitHub Issues"

## Prerequisites
- Spec must exist at `.claude/specs/$ARGUMENTS.md`
- GitHub CLI authenticated for live issue fetching (unsynced tasks show ⚠️ gracefully)
