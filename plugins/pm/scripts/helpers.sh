#!/bin/bash
# Shared helpers for pm spec skills
# Expected layout: plugins/pm/scripts/helpers.sh
# Source from a skill with: source "$BASE_DIR/../scripts/helpers.sh"
# ($BASE_DIR is set by the skill runner to the skill's own directory)

# Parse and validate granularity from ARGUMENTS string
# Prints the resolved granularity value (micro|pr|macro) or errors and returns 1
# Usage: parse_granularity "$ARGUMENTS"
parse_granularity() {
  local args="$1"
  local granularity
  granularity=$(echo "$args" | sed -n 's/.*--granularity[[:space:]]\+\([^[:space:]]\+\).*/\1/p')
  granularity="${granularity:-pr}"
  case "$granularity" in
    micro|pr|macro) echo "$granularity" ;;
    *) echo "[ERROR] Invalid granularity: '$granularity'. Must be one of: micro, pr, macro" >&2; return 1 ;;
  esac
}

# Fetch spec issue and print body for spec-plan preflight
# Usage: spec_plan_fetch_issue <issue-number>
spec_plan_fetch_issue() {
  local arg="$1"
  echo "--- Fetching spec issue ---"
  local spec
  spec=$(gh issue view "$arg" --json number,title,url,body,state 2>/dev/null)
  if [ -z "$spec" ] || [ "$spec" = "null" ]; then
    echo "[ERROR] Issue #$arg not found"
    return 1
  fi
  printf '%s' "$spec" | jq -r '"[OK] Found spec issue #\(.number): \(.url)"'
  if printf '%s' "$spec" | jq -r '.body' | grep -q "## Architecture Decisions"; then
    echo "[WARN] Plan sections already exist in spec issue"
  else
    echo "[OK] Ready to plan"
  fi
  echo ""
  echo "--- Current spec issue body ---"
  printf '%s' "$spec" | jq -r '.body'
}

# Fetch spec issue and print body for spec-decompose preflight
# Usage: spec_decompose_fetch_issue <issue-number> [granularity-override]
spec_decompose_fetch_issue() {
  local arg="$1"
  local gran_override="$2"
  echo "--- Fetching spec issue ---"
  local spec
  spec=$(gh issue view "$arg" --json number,title,url,body,state,labels 2>/dev/null)
  if [ -z "$spec" ] || [ "$spec" = "null" ]; then
    echo "[ERROR] Issue #$arg not found"
    return 1
  fi
  local spec_num spec_url spec_label spec_body detected gran repo
  spec_num=$(printf '%s' "$spec" | jq -r '.number')
  spec_url=$(printf '%s' "$spec" | jq -r '.url')
  spec_label=$(printf '%s' "$spec" | jq -r '[.labels[].name | select(startswith("spec:"))] | .[0]')
  echo "[OK] Found spec issue #$spec_num: $spec_url"
  spec_body=$(printf '%s' "$spec" | jq -r '.body')
  if ! printf '%s' "$spec_body" | grep -q "## Task Breakdown"; then
    echo "[ERROR] No Task Breakdown section found. Run /pm:spec-plan $arg first."
    return 1
  fi
  detected=$(printf '%s' "$spec_body" | grep -m1 '<!-- granularity:' | sed 's/.*granularity: *\([^ >]*\).*/\1/')
  gran="${gran_override:-${detected:-pr}}"
  echo "[INFO] Granularity: $gran | Label: $spec_label"
  repo=$(gh repo view --json nameWithOwner -q '.nameWithOwner')
  echo "[INFO] Repo: $repo | Spec issue: #$spec_num"
  echo ""
  echo "--- Existing sub-issues ---"
  gh api \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "/repos/$repo/issues/$spec_num/sub_issues" \
    --jq '.[] | "  #\(.number) [\(.state)] \(.title)"' 2>/dev/null || echo "  None"
  echo ""
  echo "--- Spec issue body ---"
  printf '%s\n' "$spec_body"
}

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
