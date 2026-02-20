---
name: spec-plan
description: Converts a spec GitHub Issue into a technical implementation plan by appending architecture decisions, tech approach, and a task breakdown. Use after spec-init to turn requirements into an engineering plan. Accepts an optional --granularity flag (micro | pr | macro) to control task sizing.
argument-hint: <feature-name> [--granularity micro|pr|macro]
---

# Spec Plan

Fetches the spec GitHub Issue for `<feature-name>` and appends a technical implementation plan to it.

Usage: `/pm:spec-plan <feature-name> [--granularity micro|pr|macro]`

## Preflight

!`
FEATURE_NAME=$(echo "$ARGUMENTS" | awk '{print $1}')
GRANULARITY=$(echo "$ARGUMENTS" | sed -n 's/.*--granularity[[:space:]]\+\([^[:space:]]\+\).*/\1/p')
GRANULARITY="${GRANULARITY:-pr}"

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

echo "[INFO] Granularity: $GRANULARITY"

# Fetch the spec issue
echo ""
echo "--- Fetching spec issue ---"
SPEC_ISSUE=$(gh issue list --label "spec:$FEATURE_NAME" --label "spec" --state open --json number,title,url,body --jq '.[0]' 2>/dev/null || echo "")
if [ -z "$SPEC_ISSUE" ] || [ "$SPEC_ISSUE" = "null" ]; then
  echo "[ERROR] No open spec issue found for: $FEATURE_NAME"
  echo "Run /pm:spec-init $FEATURE_NAME first."
  exit 1
fi

SPEC_ISSUE_NUMBER=$(echo "$SPEC_ISSUE" | jq -r '.number')
SPEC_ISSUE_URL=$(echo "$SPEC_ISSUE" | jq -r '.url')
echo "[OK] Found spec issue #$SPEC_ISSUE_NUMBER: $SPEC_ISSUE_URL"

# Check if plan already exists
SPEC_BODY=$(echo "$SPEC_ISSUE" | jq -r '.body')
if echo "$SPEC_BODY" | grep -q "## Architecture Decisions"; then
  echo "[WARN] Plan sections already exist in spec issue"
else
  echo "[OK] Ready to plan"
fi

echo ""
echo "--- Current spec issue body ---"
echo "$SPEC_BODY"
`

## Instructions

1. **If plan sections already exist** (detected above), ask: "Technical plan already exists in this spec issue. Overwrite? (yes/no)". If yes, remove existing plan sections from the body before proceeding.

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

4. **Append** the following sections to the spec issue body via `gh issue edit`:

   ```bash
   gh issue edit <spec_issue_number> --body "<updated_body>"
   ```

   Append these sections to the existing body:

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

5. **Add `planned` label** to the spec issue:
   ```bash
   gh label create "planned" --color "FBCA04" --description "Spec has a technical plan" --force 2>/dev/null || true
   gh issue edit <spec_issue_number> --add-label "planned"
   ```

6. Confirm: "✅ Technical plan added to spec issue #<number> (granularity: <value>)"
7. Suggest next step: "Ready to create tasks? Run: `/pm:spec-decompose $FEATURE_NAME`"

## Prerequisites
- A spec issue must exist (run `/pm:spec-init <feature-name>` first)
- Must be authenticated: `gh auth status`
