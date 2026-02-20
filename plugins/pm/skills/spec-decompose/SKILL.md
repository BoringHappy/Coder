---
name: spec-decompose
description: Breaks the task breakdown in a SPEC.md into structured task entries and writes them back into the spec's frontmatter tasks list. Use after spec-plan to prepare tasks before syncing to GitHub. Accepts an optional --granularity flag (micro | pr | macro) to control task splitting.
argument-hint: <feature-name> [--granularity micro|pr|macro]
---

# Spec Decompose

Reads the Task Breakdown table from `.claude/specs/<feature-name>.md` and writes structured task entries into the spec's `tasks:` frontmatter field.

Usage: `/pm:spec-decompose <feature-name> [--granularity micro|pr|macro]`

## Preflight

!`
FEATURE_NAME=$(echo "$ARGUMENTS" | awk '{print $1}')
GRANULARITY=$(echo "$ARGUMENTS" | sed -n 's/.*--granularity[[:space:]]\+\([^[:space:]]\+\).*/\1/p')
SPEC=".claude/specs/$FEATURE_NAME.md"

if [ -z "$FEATURE_NAME" ]; then
  echo "[ERROR] No feature name provided. Usage: /pm:spec-decompose <feature-name> [--granularity micro|pr|macro]"
  exit 1
fi

if [ ! -f "$SPEC" ]; then
  echo "[ERROR] Spec not found: $SPEC. Run /pm:spec-init $FEATURE_NAME first."
  exit 1
fi

if [ -n "$GRANULARITY" ]; then
  case "$GRANULARITY" in
    micro|pr|macro) ;;
    *)
      echo "[ERROR] Invalid granularity: '$GRANULARITY'. Must be one of: micro, pr, macro"
      exit 1
      ;;
  esac
  echo "[INFO] Granularity override: $GRANULARITY"
else
  # Try to detect granularity from the Task Breakdown comment in the spec
  DETECTED=$(grep -m1 '<!-- granularity:' "$SPEC" 2>/dev/null | sed 's/.*granularity: *\([^ >]*\).*/\1/')
  GRANULARITY="${DETECTED:-pr}"
  echo "[INFO] Granularity: $GRANULARITY (${DETECTED:+detected from spec}${DETECTED:-default})"
fi

if ! grep -q "^## Task Breakdown" "$SPEC" 2>/dev/null; then
  echo "[ERROR] No Task Breakdown section found. Run /pm:spec-plan $FEATURE_NAME first."
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

2. **Determine task splitting rules** from the granularity reported in preflight:
   - `micro` — Split aggressively. Each task: 0.5–1 day. One concern per task (single endpoint, single component, single migration). If a table row covers multiple concerns, split it into multiple tasks.
   - `pr` (default) — Keep tasks as PR-sized units. Each task: 1–3 days. Merge very small table rows if they naturally belong together; split rows that are clearly too large.
   - `macro` — Merge related tasks into milestones. Each task: 3–7 days. Group table rows by area (e.g. all data-layer rows → one task). Aim for 3–5 tasks total.

3. **Parse the Task Breakdown table** from the spec. Apply the splitting rules above to produce the final task list. For each resulting task extract:
   - Title
   - Tags
   - Dependencies (1-based indices into the final task list after splitting/merging)

4. **Rewrite the `tasks:` frontmatter field** with structured entries:

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
   - `title`: task title
   - `tags`: list of labels e.g. [data], [api], [ui], [infra], or multiple like [api, auth]
   - `depends_on`: list of task numbers (1-based, matching final task list order)
   - `issue`: GitHub issue number — empty until synced
   - `issue_url`: GitHub issue URL — empty until synced

5. Update the spec frontmatter `status` to `ready`.

6. Confirm: "✅ Decomposed <n> tasks into `.claude/specs/$FEATURE_NAME.md` (granularity: <value>)"
7. Suggest next step: "Ready to push to GitHub? Run: `/pm:spec-sync $FEATURE_NAME`"

## Prerequisites
- Spec must exist with a `## Task Breakdown` section
- Run `/pm:spec-plan $FEATURE_NAME` first if the section is missing
