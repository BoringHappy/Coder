---
name: spec-sync
description: Creates GitHub Issues for each task in a SPEC.md and records the issue numbers and URLs back into the spec frontmatter. Use after spec-decompose to push tasks to GitHub.
---

# Spec Sync

Creates GitHub Issues from the tasks in `.claude/specs/$ARGUMENTS.md` and writes issue numbers and URLs back into the spec.

## Preflight

!`
SPEC=".claude/specs/$ARGUMENTS.md"

if [ -z "$ARGUMENTS" ]; then
  echo "[ERROR] No feature name provided. Usage: /pm:spec-sync <feature-name>"
  exit 1
fi

if [ ! -f "$SPEC" ]; then
  echo "[ERROR] Spec not found: $SPEC. Run /pm:spec-init $ARGUMENTS first."
  exit 1
fi

# Check tasks exist
TASK_COUNT=$(grep -c "^  - title:" "$SPEC" 2>/dev/null || echo 0)
if [ "$TASK_COUNT" -eq 0 ]; then
  echo "[ERROR] No tasks found in spec frontmatter. Run /pm:spec-decompose $ARGUMENTS first."
  exit 1
fi

# Check for already-synced tasks
SYNCED=$(grep -c 'issue_url: "https' "$SPEC" 2>/dev/null || echo 0)
echo "[OK] $TASK_COUNT tasks found, $SYNCED already synced"

# Show current repo
gh repo view --json nameWithOwner -q '"Repo: \(.nameWithOwner)"' | cat

echo "--- Tasks to sync ---"
grep -E "^  - title:|^    issue_url:" "$SPEC" | cat
`

## Instructions

1. **Read the spec** at `.claude/specs/$ARGUMENTS.md` and parse all tasks from the `tasks:` frontmatter.

2. **For tasks that already have an `issue_url`**, skip them (already synced). Report which ones are skipped.

3. **For each unsynced task**, create a GitHub Issue:

```bash
gh issue create \
  --title "<task title>" \
  --body "$(cat <<EOF
## Task

Part of spec: **$ARGUMENTS**

**Layer:** <layer>
**Parallel:** <yes/no>
**Depends on:** <task titles or "none">

## Description

<1-2 sentence description derived from the spec context for this task>

## Acceptance Criteria

- [ ] <derived from spec success criteria, scoped to this task>

## References

Spec: \`.claude/specs/$ARGUMENTS.md\`
EOF
)" \
  --label "task"
```

4. **After creating each issue**, immediately update that task's entry in the spec frontmatter:
   - Set `issue` to the issue number (integer)
   - Set `issue_url` to the full issue URL

5. **After all issues are created**, update the spec frontmatter:
   - Set `status` to `in-progress`

6. **If a PR exists** (check `/tmp/.pr_status`), update the spec frontmatter `pr` field:

```bash
if [ -s /tmp/.pr_status ]; then
  PR_URL=$(cat /tmp/.pr_status)
  echo "PR found: $PR_URL"
fi
```

7. **Output a summary:**

```
✅ Synced <n> tasks to GitHub

Created issues:
  #<num> - <title> → <url>
  #<num> - <title> → <url>

Spec updated: .claude/specs/$ARGUMENTS.md

Next steps:
  - Start working: pick an issue from above
  - Update PR description: /pr:update
```

## Notes

- Tasks are created with a `task` label. Create the label first if it doesn't exist:
  ```bash
  gh label create "task" --color "1D76DB" --description "Task from spec" --force 2>/dev/null || true
  ```
- If issue creation fails for a task, report the error and continue with remaining tasks
- Never create duplicate issues — always check `issue_url` before creating

## Prerequisites
- Must be authenticated: `gh auth status`
- Spec must have decomposed tasks (run `/pm:spec-decompose $ARGUMENTS` first)
- Must be inside a GitHub repository
