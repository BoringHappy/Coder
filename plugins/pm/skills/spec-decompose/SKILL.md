---
name: spec-decompose
description: Fetches the spec GitHub Issue, parses the task breakdown table, creates task issues as sub-issues, and links them to the spec. Reconciles existing sub-issues on re-decompose. Use after spec-plan to prepare tasks. Accepts an optional --granularity flag (micro | pr | macro) to control task splitting.
argument-hint: <feature-name> [--granularity micro|pr|macro]
---

# Spec Decompose

Reads the Task Breakdown table from the spec GitHub Issue for `<feature-name>`, creates individual task issues as sub-issues, and reconciles any changes on re-runs.

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

# Fetch existing sub-issues via REST API
REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner')
echo ""
echo "--- Existing sub-issues ---"
EXISTING_SUB_ISSUES=$(gh api \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  /repos/$REPO/issues/$SPEC_ISSUE_NUMBER/sub_issues \
  --jq '.' 2>/dev/null || echo "[]")

if [ "$EXISTING_SUB_ISSUES" != "[]" ] && [ -n "$EXISTING_SUB_ISSUES" ]; then
  echo "$EXISTING_SUB_ISSUES" | jq -r '.[] | "  #\(.number) [\(.state)] \(.title) (id: \(.id))"'
else
  echo "  None"
fi

echo ""
echo "[INFO] Repo: $REPO"
echo "[INFO] Spec issue number: $SPEC_ISSUE_NUMBER"
echo ""
echo "--- Spec issue body ---"
echo "$SPEC_BODY"
`

## Instructions

1. **Determine task splitting rules** from the granularity reported in preflight:
   - `micro` — Split aggressively. Each task: 0.5–1 day. One concern per task (single endpoint, single component, single migration).
   - `pr` (default) — Keep tasks as PR-sized units. Each task: 1–3 days. Merge very small rows if they naturally belong together; split rows that are clearly too large.
   - `macro` — Merge related tasks into milestones. Each task: 3–7 days. Group rows by area. Aim for 3–5 tasks total.

2. **Parse the Task Breakdown table** from the spec issue body. Apply the splitting rules to produce the **new task list** (list of titles + tags + dependencies).

3. **Reconcile** against existing sub-issues fetched in preflight:

   - **Match** existing sub-issues to new tasks using semantic similarity — consider two tasks the same if they describe the same intent, even if the title wording differs slightly (e.g. "Set up DB schema" matches "Database schema setup"). Do not rely on exact string comparison.
   - **New tasks** (in new list, no semantically matching sub-issue) → create issue + register as sub-issue.
   - **Orphan tasks** (existing sub-issue, no semantically matching new task) → close issue with comment + remove from sub-issues.
   - **Unchanged tasks** (semantically matched) → skip, already consistent.

   If there are orphans or new tasks to create, show the diff to the user and confirm before proceeding:
   ```
   Reconcile plan:
     + Create: "Task A", "Task B"
     - Close orphan: #42 "Old Task C" (removed from spec)
   Proceed? (yes/no)
   ```

4. **Ensure labels exist**:
   ```bash
   gh label create "task" --color "1D76DB" --description "Task from spec" --force 2>/dev/null || true
   gh label create "spec:$FEATURE_NAME" --color "0E8A16" --description "Part of spec: $FEATURE_NAME" --force 2>/dev/null || true
   ```

5. **Close orphan sub-issues** (removed from spec):

   a. Close the issue with a comment:
   ```bash
   gh issue close <orphan_number> --comment "Closing: this task was removed from spec **$FEATURE_NAME** during re-decomposition."
   ```

   b. Remove it from the spec issue's sub-issues:
   ```bash
   gh api \
     --method DELETE \
     -H "Accept: application/vnd.github+json" \
     -H "X-GitHub-Api-Version: 2022-11-28" \
     /repos/$REPO/issues/$SPEC_ISSUE_NUMBER/sub_issues \
     -f sub_issue_id=<orphan_issue_id>
   ```

6. **Create new task issues** and register as sub-issues:

   a. Write the task body to a temp file and create the issue using the `task` template fields:
   ```bash
   cat > /tmp/task-body.md << 'TASKEOF'
   ### Parent Spec
   #<spec_issue_number>

   ### User Story
   As a <role>, I want to <action> so that <outcome>.

   ### Description
   <1-2 sentence technical description of the task>

   ### Acceptance Criteria
   - [ ] <criterion 1>
   - [ ] <criterion 2>

   ### Definition of Done
   - [ ] Code reviewed and approved
   - [ ] Tests written and passing
   - [ ] No regressions introduced
   - [ ] Documentation updated if needed
   - [ ] Deployed to staging / feature env (if applicable)

   ### Story Points
   <fibonacci estimate: 1, 2, 3, 5, 8, or 13>

   ### Tags
   <tags>

   ### Depends On
   <dependency task numbers or 'none'>
   TASKEOF
   TASK_URL=$(gh issue create \
     --title "<task title>" \
     --label "task" \
     --label "spec:$FEATURE_NAME" \
     --body-file /tmp/task-body.md)
   rm -f /tmp/task-body.md
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

7. **Add `ready` label** to the spec issue:
   ```bash
   gh label create "ready" --color "0075CA" --description "Spec tasks have been decomposed" --force 2>/dev/null || true
   gh issue edit $SPEC_ISSUE_NUMBER --add-label "ready"
   ```

8. **Output a summary:**
   ```
   ✅ Decomposed <n> tasks for spec: $FEATURE_NAME (granularity: <value>)

   Created (<n> new):
     #<num> - <title> → <url>

   Closed orphans (<n> removed):
     #<num> - <title>

   Unchanged (<n> skipped):
     #<num> - <title>

   Next steps:
     - View progress: /pm:spec-status $FEATURE_NAME
     - Find next task: /pm:spec-next $FEATURE_NAME
   ```

## Prerequisites
- A spec issue must exist with a `## Task Breakdown` section (run `/pm:spec-plan <feature-name>` first)
- Must be authenticated: `gh auth status`
- Must be inside a GitHub repository
