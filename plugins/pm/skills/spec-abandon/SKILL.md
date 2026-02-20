---
name: spec-abandon
description: Closes the spec GitHub Issue and optionally closes its linked task issues. Use when a feature is cancelled or no longer being pursued.
---

# Spec Abandon

Closes the spec GitHub Issue for `<feature-name>` and optionally closes all linked task issues.

## Preflight

!`if [ -z "$ARGUMENTS" ]; then echo "[ERROR] No feature name provided. Usage: /pm:spec-abandon <feature-name>"; echo ""; echo "Available specs (open spec issues):"; gh issue list --label "spec" --state open --json number,title --jq '.[] | "  - \(.title) (#\(.number))"' 2>/dev/null || echo "  (none found)"; exit 1; fi`

!`echo "--- Fetching spec issue ---"; gh issue list --label "spec:$ARGUMENTS" --label "spec" --state open --json number,title,url,state --jq 'if length > 0 then ".[0] | \"[OK] Spec issue #\(.number): \(.url)\"" else "[WARN] No open spec issue found for: $ENV.ARGUMENTS" end' 2>/dev/null || echo "[ERROR] Failed to fetch spec issue for: $ARGUMENTS"`

!`gh issue list --label "spec:$ARGUMENTS" --label "spec" --state open --json number,title,url,state --jq '.[0] | "[OK] Spec issue #\(.number): \(.url)"' 2>/dev/null`

!`echo "--- Open task issues ---"; gh issue list --label "spec:$ARGUMENTS" --label "task" --state open --json number,title,url --jq '.[] | "#\(.number) \(.title) \(.url)"' 2>/dev/null || echo "(none)"`

## Instructions

1. **Confirm with the user** before making any changes:
   - Show the spec issue number and URL from preflight
   - List any open task issues found above
   - Ask: "Are you sure you want to abandon `$ARGUMENTS`? This will close the spec issue. Reply with yes/no, and whether to also close any open task issues (yes/no)."
   - Stop if they say no.

2. **Close the spec issue** with an explanatory comment:
   ```bash
   gh issue close <spec_issue_number> --comment "Closing: spec **$ARGUMENTS** has been abandoned."
   ```

3. **If the user wants to close open task issues**, for each open task issue:
   ```bash
   gh issue close <task_issue_number> --comment "Closing: parent spec **$ARGUMENTS** has been abandoned."
   ```

4. Confirm:
   ```
   ✅ Spec `$ARGUMENTS` abandoned.
   Closed spec issue: #<num>
   Closed task issues: #<num>, #<num>, ...  (if applicable)
   ```

## Prerequisites
- A spec issue must exist for the given feature name
- GitHub CLI authenticated
