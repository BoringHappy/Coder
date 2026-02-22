---
name: spec-list
description: Lists all spec GitHub Issues with their status and task counts. Use when the user wants to discover existing specs or get a project overview.
---

# Spec List

Lists all feature specs as GitHub Issues labeled with `spec`.

## Specs

!```bash
echo "--- Fetching spec issues ---"
gh issue list --label "spec" --state all --limit 200 \
  --json number,title,state,url,labels \
  --jq '[.[] | select(.labels | map(.name) | contains(["done"]) | not)] | if length == 0 then "No spec issues found. Create your first spec with: /pm:spec-init <title>" else "SPEC_ISSUES:\n" + (. | tojson) end' \
  2>/dev/null || echo "[]"
```

## Instructions

Display the spec list shown above. If no specs exist, prompt the user to create one with `/pm:spec-init <title>`.

Format the output as:

```
## Feature Specs

| Issue | Title | State |
|-------|-------|-------|
| #12 | [Spec]: user auth | 🔄 OPEN |
| #8  | [Spec]: dark mode | ✅ CLOSED |
```

For each spec, suggest the appropriate next step based on its state and labels:
- Has no `planned` label → `/pm:spec-plan <number>`
- Has `planned` but no `ready` label → `/pm:spec-decompose <number>`
- Has `ready` label, issue open → `/pm:spec-status <number>`
- Issue is CLOSED → spec complete
