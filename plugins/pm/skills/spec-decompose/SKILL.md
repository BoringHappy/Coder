---
name: spec-decompose
description: Fetches the spec GitHub Issue, parses the task breakdown table, creates task issues as sub-issues, and links them to the spec. Use after spec-plan to prepare tasks. Accepts an optional --granularity flag (micro | pr | macro) to control task splitting.
argument-hint: <feature-name> [--granularity micro|pr|macro]
---

# Spec Decompose

Reads the Task Breakdown table from the spec GitHub Issue for `<feature-name>`, creates individual task issues, and registers them as sub-issues of the spec issue.

Usage: `/pm:spec-decompose <feature-name> [--granularity micro|pr|macro]`

## Preflight

!`
FEATURE_NAME=$(echo "$ARGUMENTS" | awk '{print $1}')
GRANULARITY=$(echo "$ARGUMENTS" | sed -n 's/.*--granularity[[:space:]]\+\([^[:space:]]\+\).*/\1/p')

if [ -z "$FEATURE_NAME" ]; then
  echo "[ERROR] No feature name provided. Usage: /pm:spec-decompose <feature-name> [--granularity micro|pr|macro]"
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
fi

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

SPEC_BODY=$(echo "$SPEC_ISSUE" | jq -r '.body')

# Detect granularity from spec body if not overridden
if [ -z "$GRANULARITY" ]; then
  DETECTED=$(echo "$SPEC_BODY" | grep -m1 '<!-- granularity:' | sed 's/.*granularity: *\([^ >]*\).*/\1/')
  GRANULARITY="${DETECTED:-pr}"
  echo "[INFO] Granularity: $GRANULARITY (${DETECTED:+detected from spec}${DETECTED:-default})"
fi

# Check if Task Breakdown exists
if ! echo "$SPEC_BODY" | grep -q "## Task Breakdown"; then
  echo "[ERROR] No Task Breakdown section found in spec issue."
  echo "Run /pm:spec-plan $FEATURE_NAME first."
  exit 1
fi

# Check for existing task sub-issues
echo ""
echo "--- Existing task issues ---"
EXISTING_TASKS=$(gh issue list --label "spec:$FEATURE_NAME" --label "task" --state all --json number,title,url --jq '.[] | "#\(.number) \(.title)"' 2>/dev/null || echo "")
if [ -n "$EXISTING_TASKS" ]; then
  echo "[WARN] Existing task issues found:"
  echo "$EXISTING_TASKS"
else
  echo "None found"
fi

# Show repo info for sub-issue API calls
REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner')
echo ""
echo "[INFO] Repo: $REPO"
echo "[INFO] Spec issue number: $SPEC_ISSUE_NUMBER"
echo ""
echo "--- Spec issue body ---"
echo "$SPEC_BODY"
`

## Instructions

1. **If task issues already exist** (detected above), ask: "Task issues already exist for this spec. Re-decompose? This will create new task issues (existing ones will not be deleted). (yes/no)". Stop if they say no.

2. **Determine task splitting rules** from the granularity reported in preflight:
   - `micro` — Split aggressively. Each task: 0.5–1 day. One concern per task (single endpoint, single component, single migration). If a table row covers multiple concerns, split it into multiple tasks.
   - `pr` (default) — Keep tasks as PR-sized units. Each task: 1–3 days. Merge very small table rows if they naturally belong together; split rows that are clearly too large.
   - `macro` — Merge related tasks into milestones. Each task: 3–7 days. Group table rows by area (e.g. all data-layer rows → one task). Aim for 3–5 tasks total.

3. **Parse the Task Breakdown table** from the spec issue body. Apply the splitting rules above to produce the final task list.

4. **Ensure labels exist**:
   ```bash
   gh label create "task" --color "1D76DB" --description "Task from spec" --force 2>/dev/null || true
   gh label create "spec:$FEATURE_NAME" --color "0E8A16" --description "Part of spec: $FEATURE_NAME" --force 2>/dev/null || true
   ```

5. **For each task**, create a GitHub issue and register it as a sub-issue of the spec issue:

   a. Create the task issue:
   ```bash
   TASK_URL=$(gh issue create \
     --title "<task title>" \
     --label "task" \
     --label "spec:$FEATURE_NAME" \
     --body "Part of spec: **$FEATURE_NAME** (#<spec_issue_number>)

   <1-2 sentence description of the task>

   **Tags:** <tags>
   **Depends on:** <dependency task titles or 'none'>

   ## Acceptance Criteria
   - [ ] <criterion 1>
   - [ ] <criterion 2>")
   ```

   b. Get the task issue's numeric ID (not number):
   ```bash
   TASK_ISSUE_NUMBER=$(echo "$TASK_URL" | grep -oE '[0-9]+$')
   TASK_ISSUE_ID=$(gh api /repos/$REPO/issues/$TASK_ISSUE_NUMBER --jq '.id')
   ```

   c. Register as sub-issue of the spec issue:
   ```bash
   gh api \
     --method POST \
     -H "Accept: application/vnd.github+json" \
     -H "X-GitHub-Api-Version: 2022-11-28" \
     /repos/$REPO/issues/$SPEC_ISSUE_NUMBER/sub_issues \
     -f sub_issue_id="$TASK_ISSUE_ID"
   ```

6. **Add `ready` label** to the spec issue:
   ```bash
   gh label create "ready" --color "0075CA" --description "Spec tasks have been decomposed" --force 2>/dev/null || true
   gh issue edit $SPEC_ISSUE_NUMBER --add-label "ready"
   ```

7. **Output a summary:**
   ```
   ✅ Decomposed <n> tasks for spec: $FEATURE_NAME (granularity: <value>)

   Created task issues (sub-issues of #<spec_issue_number>):
     #<num> - <title> → <url>
     #<num> - <title> → <url>

   Next steps:
     - View progress: /pm:spec-status $FEATURE_NAME
     - Find next task: /pm:spec-next $FEATURE_NAME
   ```

## Prerequisites
- A spec issue must exist with a `## Task Breakdown` section (run `/pm:spec-plan <feature-name>` first)
- Must be authenticated: `gh auth status`
- Must be inside a GitHub repository
