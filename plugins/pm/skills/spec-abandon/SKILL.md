---
name: spec-abandon
description: Closes the spec GitHub Issue and optionally closes its linked task issues. Use when a feature is cancelled or no longer being pursued.
argument-hint: <issue-number>
---

# Spec Abandon

Closes the spec GitHub Issue and optionally closes all linked task issues.

Usage: `/pm:spec-abandon <issue-number>`

## Preflight

!`if [ -z "$ARGUMENTS" ]; then echo "[ERROR] No issue number provided. Usage: /pm:spec-abandon <issue-number>"; echo ""; echo "Available specs:"; gh issue list --label "spec" --state open --json number,title --jq '.[] | "  #\(.number) \(.title)"' 2>/dev/null || echo "  (none found)"; exit 1; fi`

!`echo "--- Fetching spec issue ---"; gh issue view "$ARGUMENTS" --json number,title,url,state --jq 'if .state == "OPEN" then "[OK] Spec issue #\(.number): \(.url)" else "[WARN] Spec issue #\(.number) is already \(.state)" end' 2>/dev/null || echo "[ERROR] Issue #$ARGUMENTS not found"`

!`echo "--- Open task issues ---"; REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner'); gh api /repos/$REPO/issues/$ARGUMENTS/sub_issues --jq '.[] | select(.state == "open") | "#\(.number) \(.title) \(.html_url)"' 2>/dev/null || echo "(none)"`

## Instructions

1. **Confirm with the user** before making any changes:
   - Show the spec issue number and URL from preflight
   - List any open task issues found above
   - Ask: "Are you sure you want to abandon spec #<spec_issue_number>? This will close the spec issue. Reply with yes/no, and whether to also close any open task issues (yes/no)."
   - Stop if they say no.

2. **Close the spec issue** with an explanatory comment:
   ```bash
   gh issue close <spec_issue_number> --comment "Closing: this spec has been abandoned."
   ```

3. **If the user wants to close open task issues**, for each open task issue:
   ```bash
   gh issue close <task_issue_number> --comment "Closing: parent spec #<spec_issue_number> has been abandoned."
   ```

4. Confirm:
   ```
   ✅ Spec #<spec_issue_number> abandoned.
   Closed spec issue: #<num>
   Closed task issues: #<num>, #<num>, ...  (if applicable)
   ```

## Prerequisites
- A spec issue must exist
- GitHub CLI authenticated
