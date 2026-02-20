#!/bin/bash
# Shared helpers for pm spec skills
# Usage: source <BASE_DIR>/scripts/helpers.sh

# Ensure required labels exist for a spec
# Usage: ensure_spec_labels <feature-name>
ensure_spec_labels() {
  local name="$1"
  gh label create "spec" --color "5319E7" --description "Spec-level tracking issue" --force 2>/dev/null || true
  gh label create "spec:$name" --color "0E8A16" --description "Part of spec: $name" --force 2>/dev/null || true
}

# Ensure required labels exist for tasks
# Usage: ensure_task_labels <feature-name>
ensure_task_labels() {
  local name="$1"
  gh label create "task" --color "1D76DB" --description "Task from spec" --force 2>/dev/null || true
  gh label create "spec:$name" --color "0E8A16" --description "Part of spec: $name" --force 2>/dev/null || true
}

# Ensure planned label exists
ensure_planned_label() {
  gh label create "planned" --color "FBCA04" --description "Spec has a technical plan" --force 2>/dev/null || true
}

# Ensure ready label exists
ensure_ready_label() {
  gh label create "ready" --color "0075CA" --description "Spec tasks have been decomposed" --force 2>/dev/null || true
}


# Write issue body to temp file and create/edit a GitHub issue
# Usage: write_issue_body <content> <tempfile>
write_issue_body() {
  local content="$1"
  local tmpfile="$2"
  printf '%s' "$content" > "$tmpfile"
}

# Get repo nameWithOwner
# Usage: get_repo
get_repo() {
  gh repo view --json nameWithOwner -q '.nameWithOwner'
}

# Register a sub-issue under a parent spec issue
# Usage: register_sub_issue <repo> <spec_issue_number> <task_issue_id>
register_sub_issue() {
  local repo="$1"
  local spec_num="$2"
  local task_id="$3"
  gh api \
    --method POST \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "/repos/$repo/issues/$spec_num/sub_issues" \
    -f sub_issue_id="$task_id"
}

# Remove a sub-issue from a parent spec issue
# Usage: remove_sub_issue <repo> <spec_issue_number> <task_issue_id>
remove_sub_issue() {
  local repo="$1"
  local spec_num="$2"
  local task_id="$3"
  gh api \
    --method DELETE \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "/repos/$repo/issues/$spec_num/sub_issues" \
    -f sub_issue_id="$task_id"
}

# List sub-issues for a spec issue
# Usage: list_sub_issues <repo> <spec_issue_number>
list_sub_issues() {
  local repo="$1"
  local spec_num="$2"
  gh api \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "/repos/$repo/issues/$spec_num/sub_issues" \
    --jq '.' 2>/dev/null || echo "[]"
}
