---
name: spec-next
description: Finds the next actionable task in a SPEC.md by checking GitHub Issue status and resolving dependencies. Use when the user wants to know what to work on next.
---

# Spec Next

Reads `.claude/specs/$ARGUMENTS.md`, fetches live issue status from GitHub, and identifies the next task(s) that are ready to work on — open issues whose dependencies are all closed.

## Preflight

!`
SPEC=".claude/specs/$ARGUMENTS.md"

if [ -z "$ARGUMENTS" ]; then
  echo "[ERROR] No feature name provided. Usage: /pm:spec-next <feature-name>"
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

echo "--- Spec content ---"
cat "$SPEC"
echo ""

echo "--- Live issue statuses ---"
grep "issue_url:" "$SPEC" | grep "https" | sed 's/.*issue_url: *"//' | sed 's/"//' | while read url; do
  issue_num=$(echo "$url" | grep -oE '[0-9]+$')
  if [ -n "$issue_num" ]; then
    gh issue view "$issue_num" --json number,title,state,labels \
      -q '"#\(.number) [\(.state | ascii_upcase)] \(.title)"' 2>/dev/null || echo "#$issue_num [ERROR] Could not fetch"
  fi
done
`

## Instructions

Using the spec content and live issue statuses fetched above, find the next task(s) ready to work on.

### Algorithm

1. Parse the `tasks:` list from the spec frontmatter (1-based index order).
2. For each task, determine its status:
   - `CLOSED` — issue state is `CLOSED`
   - `OPEN` — issue state is `OPEN`
   - `unsynced` — task has no `issue_url`
3. Build a dependency map: each task's `depends_on` field lists 1-based indices of tasks it depends on.
4. A task is **ready** if:
   - Its status is `OPEN` or `unsynced`
   - Every task listed in its `depends_on` has status `CLOSED`
5. A task is **blocked** if any dependency is `OPEN` or `unsynced`.

### Output Format

```
## Next Task(s) for: $ARGUMENTS

### ✅ Ready to Work On
- #<issue> <title> — <issue_url>
  Tags: <tags>

### ⏳ Blocked
- #<issue> <title> — waiting on: <dependency titles>

### 💡 Suggestion
<one-line recommendation on what to pick up next>
```

Rules:
- If no tasks are ready and none are blocked, show: "🎉 All tasks complete!"
- If tasks are unsynced (no issue), suggest running `/pm:spec-sync $ARGUMENTS` first.
- If multiple tasks are ready, list all of them — the user picks.
- "Suggestion" should recommend the highest-priority ready task based on tags or position in the list.

## Prerequisites
- Spec must exist at `.claude/specs/$ARGUMENTS.md`
- GitHub CLI authenticated for live issue fetching
