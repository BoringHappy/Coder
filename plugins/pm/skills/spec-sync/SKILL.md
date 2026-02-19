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

3. **Check for an issue template** to use as the issue body format:

```bash
# Look for a task/feature template, fall back to feature_request if present
if [ -f ".github/ISSUE_TEMPLATE/feature_request.yml" ]; then
  echo "Using feature_request.yml template"
elif [ -f ".github/ISSUE_TEMPLATE/feature_request.md" ]; then
  echo "Using feature_request.md template"
fi
```

If a `.github/ISSUE_TEMPLATE/` directory exists, read the most relevant template (prefer `feature_request.yml` or `feature_request.md`) and use its **section structure** as the body format for each issue. Fill in each section with content derived from the task and spec.

If no template exists, use this default body format:

```
## What would you like to see?

<1-2 sentence description of the task derived from the spec>

Part of spec: **$ARGUMENTS**
Layer: <layer> | Parallel: <yes/no> | Depends on: <task titles or "none">

## How should it work?

<acceptance criteria derived from the spec success criteria, scoped to this task>
- [ ] <criterion 1>
- [ ] <criterion 2>

## Additional Context (optional)

Spec: `.claude/specs/$ARGUMENTS.md`
Depends on tasks: <list or "none">
```

For each unsynced task, create the issue:

```bash
gh issue create \
  --title "<task title>" \
  --body "<body using template structure above>" \
  --label "task"
```

4. **After creating each issue**, immediately update that task's entry in the spec frontmatter:
   - Set `issue` to the issue number (integer)
   - Set `issue_url` to the full issue URL

5. **After all issues are created**, update the spec frontmatter:
   - Set `status` to `in-progress`

6. **Output a summary:**

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
