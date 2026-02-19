---
name: spec-decompose
description: Breaks the task breakdown in a SPEC.md into structured task entries and writes them back into the spec's frontmatter tasks list. Use after spec-plan to prepare tasks before syncing to GitHub.
---

# Spec Decompose

Reads the Task Breakdown table from `.claude/specs/$ARGUMENTS.md` and writes structured task entries into the spec's `tasks:` frontmatter field.

## Preflight

!`
SPEC=".claude/specs/$ARGUMENTS.md"

if [ -z "$ARGUMENTS" ]; then
  echo "[ERROR] No feature name provided. Usage: /pm:spec-decompose <feature-name>"
  exit 1
fi

if [ ! -f "$SPEC" ]; then
  echo "[ERROR] Spec not found: $SPEC. Run /pm:spec-init $ARGUMENTS first."
  exit 1
fi

if ! grep -q "^## Task Breakdown" "$SPEC" 2>/dev/null; then
  echo "[ERROR] No Task Breakdown section found. Run /pm:spec-plan $ARGUMENTS first."
  exit 1
fi

# Check if tasks already decomposed
TASK_COUNT=$(grep -c "^  - title:" "$SPEC" 2>/dev/null || echo 0)
if [ "$TASK_COUNT" -gt 0 ]; then
  echo "[WARN] $TASK_COUNT tasks already in frontmatter"
else
  echo "[OK] Ready to decompose"
fi

echo "--- Current spec ---"
cat "$SPEC"
`

## Instructions

1. **If tasks already exist in frontmatter** (detected above), ask: "Tasks already decomposed. Re-decompose? (yes/no)". If yes, clear the existing `tasks:` list before proceeding.

2. **Parse the Task Breakdown table** from the spec. For each row extract:
   - Task number
   - Title
   - Tags
   - Dependencies (task numbers it depends on)

3. **Rewrite the `tasks:` frontmatter field** with structured entries. Each task gets:

```yaml
tasks:
  - title: "Setup database schema"
    tags: [data]
    depends_on: []
    issue: ""
    issue_url: ""
  - title: "Build REST endpoints"
    tags: [api]
    depends_on: [1]
    issue: ""
    issue_url: ""
```

   Fields:
   - `title`: task title from the breakdown table
   - `tags`: list of labels e.g. [data], [api], [ui], [infra], or multiple like [api, auth]
   - `depends_on`: list of task numbers (1-based, matching table order)
   - `issue`: GitHub issue number — empty until synced
   - `issue_url`: GitHub issue URL — empty until synced

4. Update the spec frontmatter `status` to `ready`.

5. Confirm: "✅ Decomposed <n> tasks into `.claude/specs/$ARGUMENTS.md`"
6. Suggest next step: "Ready to push to GitHub? Run: `/pm:spec-sync $ARGUMENTS`"

## Prerequisites
- Spec must exist with a `## Task Breakdown` section
- Run `/pm:spec-plan $ARGUMENTS` first if the section is missing
