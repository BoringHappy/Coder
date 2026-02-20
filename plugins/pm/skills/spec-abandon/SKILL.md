---
name: spec-abandon
description: Closes the spec GitHub Issue and optionally closes its linked task issues. Use when a feature is cancelled or no longer being pursued.
argument-hint: <issue-number-or-feature-name>
---

# Spec Abandon

Closes the spec GitHub Issue and optionally closes all linked task issues.

Usage: `/pm:spec-abandon <issue-number-or-feature-name>`

## Preflight

!`if [ -z "$ARGUMENTS" ]; then echo "[ERROR] No argument provided. Usage: /pm:spec-abandon <issue-number-or-feature-name>"; echo ""; echo "Available specs:"; gh issue list --label "spec" --state open --json number,title --jq '.[] | "  #\(.number) \(.title)"' 2>/dev/null || echo "  (none found)"; exit 1; fi`

!`echo "--- Fetching spec issue ---"; if echo "$ARGUMENTS" | grep -qE '^[0-9]+$'; then gh issue view "$ARGUMENTS" --json number,title,url,state --jq 'if .state == "OPEN" then "[OK] Spec issue #\(.number): \(.url)" else "[WARN] Spec issue #\(.number) is already \(.state)" end' 2>/dev/null || echo "[ERROR] Issue #$ARGUMENTS not found"; else gh issue list --label "spec:$ARGUMENTS" --label "spec" --state open --json number,title,url --jq 'if length > 0 then .[0] | "[OK] Spec issue #\(.number): \(.url)" else "[ERROR] No open spec issue found for: $ENV.ARGUMENTS" end' 2>/dev/null; fi`

!`echo "--- Open task issues ---"; if echo "$ARGUMENTS" | grep -qE '^[0-9]+$'; then SPEC_LABEL=$(gh issue view "$ARGUMENTS" --json labels --jq '[.labels[].name | select(startswith("spec:"))] | .[0]' 2>/dev/null); gh issue list --label "$SPEC_LABEL" --label "task" --state open --json number,title,url --jq '.[] | "#\(.number) \(.title) \(.url)"' 2>/dev/null || echo "(none)"; else gh issue list --label "spec:$ARGUMENTS" --label "task" --state open --json number,title,url --jq '.[] | "#\(.number) \(.title) \(.url)"' 2>/dev/null || echo "(none)"; fi`

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
