---
name: spec-list
description: Lists all spec GitHub Issues with their status and task counts. Use when the user wants to discover existing specs or get a project overview.
---

# Spec List

Lists all feature specs as GitHub Issues labeled with `spec`.

## Specs

!`echo "--- Fetching spec issues ---"; gh issue list --label "spec" --state all --limit 200 --json number,title,state,url,labels --jq 'if length == 0 then "No spec issues found. Create your first spec with: /pm:spec-init <title>" else "SPEC_ISSUES:\n" + (. | tojson) end' 2>/dev/null || echo "[]"`

!`echo "TASK_ISSUES:"; gh issue list --label "task" --state all --limit 500 --json number,title,state,labels --jq '.' 2>/dev/null || echo "[]"`

## Instructions

Display the spec list shown above. If no specs exist, prompt the user to create one with `/pm:spec-init <title>`.

Using the two JSON arrays from preflight (spec issues + all task issues), compute task counts client-side:
- For each spec issue, extract its `spec:<name>` label to get the spec name
- Count total and closed task issues whose labels include `spec:<name>`

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
