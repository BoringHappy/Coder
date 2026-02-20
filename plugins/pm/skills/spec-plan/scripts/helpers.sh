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

# Fetch open spec issue JSON for a feature name
# Usage: fetch_spec_issue <feature-name> [all|open|closed]
# Prints JSON of first matching issue, or empty string if not found
fetch_spec_issue() {
  local name="$1"
  local state="${2:-open}"
  gh issue list --label "spec:$name" --label "spec" --state "$state" \
    --json number,title,url,body,state,labels \
    --jq '.[0]' 2>/dev/null || echo ""
}

# Parse feature name from ARGUMENTS (first word)
# Usage: feature_name_from_args "$ARGUMENTS"
feature_name_from_args() {
  echo "$1" | awk '{print $1}'
}

# Parse --granularity flag from ARGUMENTS
# Usage: granularity_from_args "$ARGUMENTS" [default]
granularity_from_args() {
  local args="$1"
  local default="${2:-pr}"
  local val
  val=$(echo "$args" | sed -n 's/.*--granularity[[:space:]]\+\([^[:space:]]\+\).*/\1/p')
  echo "${val:-$default}"
}

# Validate granularity value
# Usage: validate_granularity <value>
# Returns 0 if valid, 1 if invalid
validate_granularity() {
  case "$1" in
    micro|pr|macro) return 0 ;;
    *) return 1 ;;
  esac
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
