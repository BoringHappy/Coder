---
name: spec-plan
description: Converts a SPEC.md into a technical implementation plan by appending architecture decisions, tech approach, and a task breakdown. Use after spec-init to turn requirements into an engineering plan. Accepts an optional --granularity flag (micro | pr | macro) to control task sizing.
---

# Spec Plan

Reads `.claude/specs/<feature-name>.md` and appends a technical implementation plan to it.

Usage: `/pm:spec-plan <feature-name> [--granularity micro|pr|macro]`

## Preflight

!`
FEATURE_NAME=$(echo "$ARGUMENTS" | awk '{print $1}')
GRANULARITY=$(echo "$ARGUMENTS" | grep -oP '(?<=--granularity )\S+')
GRANULARITY="${GRANULARITY:-pr}"
SPEC=".claude/specs/$FEATURE_NAME.md"

if [ -z "$FEATURE_NAME" ]; then
  echo "[ERROR] No feature name provided. Usage: /pm:spec-plan <feature-name> [--granularity micro|pr|macro]"
  exit 1
fi

case "$GRANULARITY" in
  micro|pr|macro) ;;
  *)
    echo "[ERROR] Invalid granularity: '$GRANULARITY'. Must be one of: micro, pr, macro"
    exit 1
    ;;
esac

if [ ! -f "$SPEC" ]; then
  echo "[ERROR] Spec not found: $SPEC. Create it first with: /pm:spec-init $FEATURE_NAME"
  exit 1
fi

# Check if plan already exists
if grep -q "^## Architecture" "$SPEC" 2>/dev/null; then
  echo "[WARN] Plan sections already exist in spec"
else
  echo "[OK] Spec found, ready to plan"
fi

echo "[INFO] Granularity: $GRANULARITY"
echo "--- Current spec ---"
cat "$SPEC"
`

## Instructions

1. **If plan sections already exist**, ask: "Technical plan already exists in this spec. Overwrite? (yes/no)". If yes, remove existing plan sections before proceeding.

2. **Determine task sizing rules** from the granularity reported in preflight:
   - `micro` — Tasks are small and focused. Each task: 0.5–1 day. Aim for 10–20 tasks. Split by thin vertical slice (one endpoint, one component, one migration). Each task should be committable in isolation.
   - `pr` (default) — Tasks are PR-sized shippable units. Each task: 1–3 days. Aim for 5–10 tasks. Each task should be independently reviewable and mergeable, delivering a coherent piece of functionality.
   - `macro` — Tasks are large milestones. Each task: 3–7 days. Aim for 3–5 tasks. Each task represents a major deliverable (e.g. "complete data layer", "end-to-end API", "full UI flow").

3. **Analyze the spec** above and produce a technical plan covering:
   - Architecture decisions (patterns, data models, key choices and their rationale)
   - Tech approach broken down by area (e.g. DB, API, UI, infra)
   - Task breakdown sized according to the granularity rules above. Each task needs:
     - A short title
     - Tags (e.g. data, api, ui, infra — can be multiple)
     - An effort estimate in days consistent with the chosen granularity
     - What it depends on (if anything)

4. **Append** the following sections to the spec file (do not overwrite existing content):

```markdown

## Architecture Decisions
- <decision>: <rationale>

## Technical Approach

### Data Layer
<schema, models, migrations>

### Service / API Layer
<endpoints, business logic, integrations>

### UI Layer
<components, pages, interactions — omit if not applicable>

### Infrastructure
<deployment, config, observability — omit if not applicable>

## Task Breakdown
<!-- granularity: <micro|pr|macro> -->
| # | Title | Tags | Estimate | Depends On |
|---|-------|------|----------|------------|
| 1 | <title> | <tags> | <Xd> | — |
| 2 | <title> | <tags> | <Xd> | 1 |

## Effort Estimate
- Granularity: <micro|pr|macro>
- Total tasks: <n>
- Estimated days: <sum of task estimates>
- Critical path: <longest dependency chain>
```

5. Update the spec frontmatter `status` from `draft` to `planned`.

6. Confirm: "✅ Technical plan added to `.claude/specs/$FEATURE_NAME.md` (granularity: <value>)"
7. Suggest next step: "Ready to create tasks? Run: `/pm:spec-decompose $FEATURE_NAME`"

## Prerequisites
- Spec must exist at `.claude/specs/$FEATURE_NAME.md`
- Run `/pm:spec-init $FEATURE_NAME` first if it doesn't
