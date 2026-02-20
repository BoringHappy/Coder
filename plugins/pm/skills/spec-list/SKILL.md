---
name: spec-list
description: Lists all spec GitHub Issues with their status and task counts. Use when the user wants to discover existing specs or get a project overview.
---

# Spec List

Lists all feature specs as GitHub Issues labeled with `spec`.

## Specs

!`
echo "--- Fetching spec issues ---"
SPECS=$(gh issue list --label "spec" --state all --json number,title,state,url,labels \
  --jq '.[] | "\(.number)\t\(.state)\t\(.title)\t\(.url)\t\(.labels | map(.name) | join(","))"' 2>/dev/null || echo "")

if [ -z "$SPECS" ]; then
  echo "No spec issues found. Create your first spec with: /pm:spec-init <feature-name>"
  exit 0
fi

echo "$SPECS"
echo ""

# For each spec, count its task issues
echo "--- Task counts per spec ---"
echo "$SPECS" | while IFS=$'\t' read -r num state title url labels; do
  # Extract spec:<name> label
  SPEC_NAME=$(echo "$labels" | tr ',' '\n' | grep '^spec:' | head -1 | sed 's/^spec://')
  if [ -n "$SPEC_NAME" ]; then
    TOTAL=$(gh issue list --label "spec:$SPEC_NAME" --label "task" --state all --json number --jq 'length' 2>/dev/null || echo 0)
    CLOSED=$(gh issue list --label "spec:$SPEC_NAME" --label "task" --state closed --json number --jq 'length' 2>/dev/null || echo 0)
    echo "#$num|$SPEC_NAME|$state|$CLOSED/$TOTAL"
  fi
done
`

## Instructions

Display the spec list shown above. If no specs exist, prompt the user to create one with `/pm:spec-init <feature-name>`.

Format the output as:

```
## Feature Specs

| Issue | Name | State | Tasks |
|-------|------|-------|-------|
| #12 | user-auth | 🔄 OPEN | 2/5 closed |
| #8  | dark-mode | ✅ CLOSED | 3/3 closed |
```

For each spec, suggest the appropriate next step based on its state and labels:
- Has no `planned` label → `/pm:spec-plan <name>`
- Has `planned` but no `ready` label → `/pm:spec-decompose <name>`
- Has `ready` label, tasks open → `/pm:spec-status <name>`
- Issue is CLOSED → spec complete
