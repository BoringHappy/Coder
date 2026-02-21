---
name: spec-decompose
description: Fetches the spec GitHub Issue, parses the task breakdown table, creates task issues as sub-issues, and links them to the spec. Reconciles existing sub-issues on re-decompose. Use after spec-plan to prepare tasks. Accepts an optional --granularity flag (micro | pr | macro) to control task splitting.
argument-hint: <issue-number> [--granularity micro|pr|macro]
---

# Spec Decompose

Reads the Task Breakdown table from the spec GitHub Issue, creates individual task issues as sub-issues, and reconciles any changes on re-runs.

Usage: `/pm:spec-decompose <issue-number> [--granularity micro|pr|macro]`

## Preflight

!`if [ -z "$ARGUMENTS" ]; then echo "[ERROR] No issue number provided. Usage: /pm:spec-decompose <issue-number> [--granularity micro|pr|macro]"; exit 1; fi`

!`_H=$(find ~/.claude/plugins/cache/codemate/pm -name "helpers.sh" -path "*/spec-decompose/scripts/*" | head -1); source "$_H"; ARG=$(echo "$ARGUMENTS" | awk '{print $1}'); GRAN=""; if echo "$ARGUMENTS" | grep -q -- '--granularity'; then GRAN=$(parse_granularity "$ARGUMENTS") || exit 1; echo "[INFO] Granularity override: $GRAN"; fi; spec_decompose_fetch_issue "$ARG" "$GRAN"`

## Instructions

1. **Find and verify the approved plan comment:**

   ```bash
   REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner')
   # Find the most recent comment with a rocket reaction (marks it as the plan comment)
   COMMENT_ID=$(gh api /repos/$REPO/issues/<spec_issue_number>/comments \
     --jq '[.[] | select(.body | contains("## Task Breakdown"))] | last | .id')

   if [ -z "$COMMENT_ID" ] || [ "$COMMENT_ID" = "null" ]; then
     echo "[ERROR] No plan comment found on issue #<spec_issue_number>. Run /pm:spec-plan first."
     exit 1
   fi

   ROCKET=$(gh api /repos/$REPO/issues/comments/$COMMENT_ID/reactions \
     --jq '[.[] | select(.content == "rocket")] | length')

   if [ "$ROCKET" = "0" ]; then
     echo "[ERROR] Comment #$COMMENT_ID is not a valid plan comment (missing 🚀 reaction)."
     exit 1
   fi

   # Check for +1 (👍) approval reaction
   APPROVED=$(gh api /repos/$REPO/issues/comments/$COMMENT_ID/reactions \
     --jq '[.[] | select(.content == "+1")] | length')

   if [ "$APPROVED" = "0" ]; then
     echo "[ERROR] Plan comment #$COMMENT_ID has not been approved. React with 👍 on the plan comment to approve."
     exit 1
   fi

   echo "[INFO] Plan approved (👍 x$APPROVED). Proceeding with decomposition."
   ```

   If no plan comment exists or it has no 👍 reaction, abort.

2. **Determine task splitting rules** from the granularity reported in preflight:
   - `micro` — Split aggressively. Each task: 0.5–1 day. One concern per task (single endpoint, single component, single migration).
   - `pr` (default) — Keep tasks as PR-sized units. Each task: 1–3 days. Merge very small rows if they naturally belong together; split rows that are clearly too large.
   - `macro` — Merge related tasks into milestones. Each task: 3–7 days. Group rows by area. Aim for 3–5 tasks total.

3. **Parse the Task Breakdown table** from the approved plan comment body. Apply the splitting rules to produce the **new task list** (list of titles + tags + dependencies).

4. **Reconcile** against existing sub-issues fetched in preflight:

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

5. **Ensure labels exist**:
   ```bash
   source "$BASE_DIR/scripts/helpers.sh"
   SPEC_LABEL=$(gh issue view <spec_issue_number> --json labels --jq '[.labels[].name | select(startswith("spec:"))] | .[0]')
   ensure_task_labels "${SPEC_LABEL#spec:}"
   ```

6. **Close orphan sub-issues** (removed from spec):

   a. Close the issue with a comment:
   ```bash
   gh issue close <orphan_number> --comment "Closing: this task was removed from spec #<spec_issue_number> during re-decomposition."
   ```

   b. Remove it from the spec issue's sub-issues:
   ```bash
   source "$BASE_DIR/scripts/helpers.sh"
   remove_sub_issue "$REPO" "$SPEC_ISSUE_NUMBER" "<orphan_issue_id>"
   ```

7. **Create new task issues** and register as sub-issues:

   a. Read the task issue template to understand the expected fields:
   ```bash
   TASK_TEMPLATE=".github/ISSUE_TEMPLATE/task.yml"
   if [ -f "$TASK_TEMPLATE" ]; then
     echo "[OK] Using task template: $TASK_TEMPLATE"
     cat "$TASK_TEMPLATE"
   else
     echo "[WARN] No task template found at $TASK_TEMPLATE, using plain body"
   fi
   ```

   b. Write the task body to a temp file and create the issue:
   ```bash
   source "$BASE_DIR/scripts/helpers.sh"
   SPEC_LABEL=$(gh issue view <spec_issue_number> --json labels --jq '[.labels[].name | select(startswith("spec:"))] | .[0]')
   write_issue_body "<body content>" /tmp/task-body.md

   TASK_URL=$(gh issue create \
     --title "<task title>" \
     --label "task" \
     --label "$SPEC_LABEL" \
     --body-file /tmp/task-body.md)
   rm -f /tmp/task-body.md
   ```

   c. Get the task issue's numeric ID (not number):
   ```bash
   TASK_ISSUE_NUMBER=$(echo "$TASK_URL" | grep -oE '[0-9]+$')
   TASK_ISSUE_ID=$(gh api /repos/$REPO/issues/$TASK_ISSUE_NUMBER --jq '.id')
   ```

   d. Register as sub-issue of the spec issue:
   ```bash
   source "$BASE_DIR/scripts/helpers.sh"
   register_sub_issue "$REPO" "$SPEC_ISSUE_NUMBER" "$TASK_ISSUE_ID"
   ```

8. **Add `ready` label** to the spec issue:
   ```bash
   source "$BASE_DIR/scripts/helpers.sh"
   ensure_ready_label
   gh issue edit $SPEC_ISSUE_NUMBER --add-label "ready"
   ```

9. **Output a summary:**
   ```
   ✅ Decomposed <n> tasks for spec #<spec_issue_number> (granularity: <value>)

   Created (<n> new):
     #<num> - <title> → <url>

   Closed orphans (<n> removed):
     #<num> - <title>

   Unchanged (<n> skipped):
     #<num> - <title>

   Next steps:
     - View progress: /pm:spec-status <spec_issue_number>
     - Find next task: /pm:spec-next <spec_issue_number>
   ```

## Prerequisites
- A spec issue must exist with a plan comment containing `## Task Breakdown` and a 👍 reaction (run `/pm:spec-plan <issue-number>` first, then approve the comment)
- Must be authenticated: `gh auth status`
- Must be inside a GitHub repository
