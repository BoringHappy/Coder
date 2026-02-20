---
name: spec-plan
description: Converts a spec GitHub Issue into a technical implementation plan by appending architecture decisions, tech approach, and a task breakdown. Use after spec-init to turn requirements into an engineering plan. Accepts an optional --granularity flag (micro | pr | macro) to control task sizing.
argument-hint: <issue-number-or-feature-name> [--granularity micro|pr|macro]
---

# Spec Plan

Fetches the spec GitHub Issue and appends a technical implementation plan to it.

Usage: `/pm:spec-plan <issue-number-or-feature-name> [--granularity micro|pr|macro]`

## Preflight

!`if [ -z "$ARGUMENTS" ]; then echo "[ERROR] No argument provided. Usage: /pm:spec-plan <issue-number-or-feature-name> [--granularity micro|pr|macro]"; exit 1; fi`

!`ARG=$(echo "$ARGUMENTS" | awk '{print $1}'); GRANULARITY=$(echo "$ARGUMENTS" | sed -n 's/.*--granularity[[:space:]]\+\([^[:space:]]\+\).*/\1/p'); GRANULARITY="${GRANULARITY:-pr}"; case "$GRANULARITY" in micro|pr|macro) echo "[INFO] Granularity: $GRANULARITY";; *) echo "[ERROR] Invalid granularity: '$GRANULARITY'. Must be one of: micro, pr, macro"; exit 1;; esac`

!`ARG=$(echo "$ARGUMENTS" | awk '{print $1}'); echo "--- Fetching spec issue ---"; if echo "$ARG" | grep -qE '^[0-9]+$'; then SPEC=$(gh issue view "$ARG" --json number,title,url,body,state 2>/dev/null); else SPEC=$(gh issue list --label "spec:$ARG" --label "spec" --state open --json number,title,url,body --jq '.[0]' 2>/dev/null); fi; if [ -z "$SPEC" ] || [ "$SPEC" = "null" ]; then echo "[ERROR] No open spec issue found for: $ARG"; exit 1; fi; echo "$SPEC" | jq -r '"[OK] Found spec issue #\(.number): \(.url)"'; if echo "$SPEC" | jq -r '.body' | grep -q "## Architecture Decisions"; then echo "[WARN] Plan sections already exist in spec issue"; else echo "[OK] Ready to plan"; fi; echo ""; echo "--- Current spec issue body ---"; echo "$SPEC" | jq -r '.body'`

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

4. **Write the updated body to a temp file and update the spec issue** to avoid shell escaping issues:

   ```bash
   source "$BASE_DIR/scripts/helpers.sh"
   write_issue_body "<full updated body with plan sections appended>" /tmp/spec-plan-body.md
   gh issue edit <spec_issue_number> --body-file /tmp/spec-plan-body.md
   rm -f /tmp/spec-plan-body.md
   ```

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
   source "$BASE_DIR/scripts/helpers.sh"
   ensure_planned_label
   gh issue edit <spec_issue_number> --add-label "planned"
   ```

6. Confirm: "✅ Technical plan added to spec issue #<number> (granularity: <value>)"
7. Suggest next step: "Ready to create tasks? Run: `/pm:spec-decompose $FEATURE_NAME`"

## Prerequisites
- A spec issue must exist (run `/pm:spec-init <feature-name>` first)
- Must be authenticated: `gh auth status`
