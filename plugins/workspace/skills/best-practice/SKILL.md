---
name: best-practice
description: Bootstraps a target repo with spec workflow resources — GitHub Issue templates for specs and tasks, standard labels, and a PR template. Run once to set up a repo for spec-driven development.
---

# Best Practice

Adds spec workflow resources to the current repository: GitHub Issue templates, standard labels, and a PR template.

Usage: `/workspace:best-practice`

## Preflight

!`
REPO=$(gh repo view --json nameWithOwner -q '.nameWithOwner' 2>/dev/null)
if [ -z "$REPO" ]; then
  echo "[ERROR] Not inside a GitHub repository or not authenticated."
  exit 1
fi
echo "[OK] Repo: $REPO"

echo ""
echo "--- Checking existing resources ---"
if [ -d ".github/ISSUE_TEMPLATE" ]; then
  echo "[INFO] .github/ISSUE_TEMPLATE/ exists:"
  ls .github/ISSUE_TEMPLATE/
else
  echo "[INFO] .github/ISSUE_TEMPLATE/ not found (will create)"
fi

if [ -f ".github/pull_request_template.md" ]; then
  echo "[INFO] pull_request_template.md exists"
else
  echo "[INFO] pull_request_template.md not found (will create)"
fi

echo ""
echo "--- Checking existing issue templates ---"
for TMPL in "bug_report.yml" "feature_request.yml" "spec.yml" "task.yml"; do
  if [ -f ".github/ISSUE_TEMPLATE/$TMPL" ]; then
    echo "[OK] $TMPL exists"
  else
    echo "[MISSING] $TMPL"
  fi
done

echo ""
echo "--- Checking existing labels ---"
EXISTING_LABELS=$(gh label list --json name -q '.[].name' 2>/dev/null || echo "")
for LABEL in "spec" "planned" "ready" "task"; do
  if echo "$EXISTING_LABELS" | grep -qx "$LABEL"; then
    echo "[OK] Label '$LABEL' already exists"
  else
    echo "[MISSING] Label '$LABEL'"
  fi
done

echo ""
echo "--- Comparing templates with best-practice ---"
for TMPL in "spec.yml" "task.yml"; do
  if [ -f ".github/ISSUE_TEMPLATE/$TMPL" ]; then
    if ! grep -q "^type:" ".github/ISSUE_TEMPLATE/$TMPL"; then
      echo "[SUGGEST] $TMPL: missing 'type:' field (best-practice requires it)"
    else
      echo "[OK] $TMPL: $(grep '^type:' .github/ISSUE_TEMPLATE/$TMPL)"
    fi
  fi
done

echo ""
echo "--- Checking repo issue types ---"
OWNER=$(echo $REPO | cut -d'/' -f1)
ACCOUNT_TYPE=$(gh api users/$OWNER --jq '.type' 2>/dev/null || echo "")
if [ "$ACCOUNT_TYPE" = "Organization" ]; then
  ISSUE_TYPES=$(gh api orgs/$OWNER/issue-types --jq '.[].name' 2>/dev/null || echo "")
  for IT in "Spec" "Task"; do
    if echo "$ISSUE_TYPES" | grep -qx "$IT"; then
      echo "[OK] Issue type '$IT' exists"
    else
      echo "[MISSING] Issue type '$IT'"
    fi
  done
else
  echo "[SKIP] Issue types are only supported for organization accounts"
fi
`

## Instructions

1. **Create `.github/ISSUE_TEMPLATE/bug_report.yml`** if it doesn't exist:

   ```yaml
   name: Bug Report
   description: Report a bug or unexpected behavior
   title: "[Bug]: "
   labels: ["bug"]
   body:
     - type: textarea
       id: what-happened
       attributes:
         label: What happened?
         description: Describe the bug and what you expected instead
         placeholder: |
           When I run... I get an error...
           I expected it to...
       validations:
         required: true

     - type: textarea
       id: steps
       attributes:
         label: Steps to Reproduce
         placeholder: |
           1. Run '...'
           2. Execute '...'
           3. See error
       validations:
         required: true

     - type: textarea
       id: environment
       attributes:
         label: Environment (optional)
         description: OS, versions, architecture, etc.
         placeholder: |
           - OS: Ubuntu 22.04
           - Version: 1.0.0

     - type: textarea
       id: logs
       attributes:
         label: Logs or Additional Context (optional)
         placeholder: Paste logs or add additional information here...
         render: shell
   ```

2. **Create `.github/ISSUE_TEMPLATE/feature_request.yml`** if it doesn't exist:

   ```yaml
   name: Feature Request
   description: Suggest a new feature or enhancement
   title: "[Feature]: "
   labels: ["enhancement"]
   body:
     - type: textarea
       id: description
       attributes:
         label: What would you like to see?
         description: Describe the feature and why it would be useful
         placeholder: |
           I would like to support...
           This would help because...
       validations:
         required: true

     - type: textarea
       id: solution
       attributes:
         label: How should it work?
         description: Describe how you envision this feature working
         placeholder: When I run... it should...
       validations:
         required: true

     - type: textarea
       id: additional
       attributes:
         label: Additional Context (optional)
         description: Alternatives considered, examples, or other context
         placeholder: Any additional information...
   ```

3. **Create `.github/ISSUE_TEMPLATE/spec.yml`**. If it already exists, compare it against the best-practice definition below and output any differences as suggestions (e.g. missing `type:` field). Ask the user if they want to apply updates.

   Write this content:

   ```yaml
   name: Spec
   description: Track a feature spec managed by the pm plugin
   title: "[Spec]: "
   labels: ["spec"]
   type: Spec
   body:
     - type: markdown
       attributes:
         value: |
           This issue tracks a feature spec. It is managed automatically by the `/pm:spec-*` skills.

     - type: textarea
       id: problem
       attributes:
         label: Problem Statement
         description: What problem does this solve and why does it matter?
         placeholder: |
           Users currently have to... which causes...
           This spec addresses that by...
       validations:
         required: true

     - type: textarea
       id: user-stories
       attributes:
         label: User Stories
         description: "As a <role>, I want to <action> so that <outcome>"
         placeholder: |
           - As a developer, I want to... so that...
           - As an admin, I want to... so that...
       validations:
         required: true

     - type: textarea
       id: acceptance-criteria
       attributes:
         label: Acceptance Criteria
         description: Measurable outcomes that define done at the feature level
         placeholder: |
           - [ ] Users can...
           - [ ] System handles...
       validations:
         required: true

     - type: textarea
       id: out-of-scope
       attributes:
         label: Out of Scope
         description: What is explicitly excluded from this spec?
         placeholder: |
           - Not included: ...

     - type: textarea
       id: dependencies
       attributes:
         label: Dependencies & Constraints (optional)
         description: What blocks or limits this spec?
         placeholder: |
           - Requires Auth service
           - Must use existing DB schema
   ```

4. **Create `.github/ISSUE_TEMPLATE/task.yml`**. If it already exists, compare it against the best-practice definition below and output any differences as suggestions (e.g. missing `type:` field). Ask the user if they want to apply updates.

   ```yaml
   name: Task
   description: Implementation task linked to a spec
   title: "[Task]: "
   labels: ["task"]
   type: Task
   body:
     - type: markdown
       attributes:
         value: |
           Tasks are normally created automatically by `/pm:spec-decompose`. Use this template only for manual task creation.

     - type: input
       id: spec-ref
       attributes:
         label: Parent Spec
         description: Link to the parent spec issue (e.g. #42)
         placeholder: "#42"
       validations:
         required: true

     - type: textarea
       id: user-story
       attributes:
         label: User Story
         description: Who needs this and why?
         placeholder: |
           As a <role>, I want to <action> so that <outcome>.
       validations:
         required: true

     - type: textarea
       id: description
       attributes:
         label: Description
         description: Technical details of what needs to be implemented
       validations:
         required: true

     - type: textarea
       id: acceptance-criteria
       attributes:
         label: Acceptance Criteria
         description: Definition of Done — all boxes must be checked before closing
         placeholder: |
           - [ ] Criterion 1
           - [ ] Criterion 2
       validations:
         required: true

     - type: textarea
       id: definition-of-done
       attributes:
         label: Definition of Done
         description: Standard checklist that applies to every task
         value: |
           - [ ] Code reviewed and approved
           - [ ] Tests written and passing
           - [ ] No regressions introduced
           - [ ] Documentation updated if needed
           - [ ] Deployed to staging / feature env (if applicable)

     - type: input
       id: story-points
       attributes:
         label: Story Points
         description: Effort estimate using Fibonacci scale (1, 2, 3, 5, 8, 13)
         placeholder: "3"

     - type: dropdown
       id: priority
       attributes:
         label: Priority
         options:
           - Low
           - Medium
           - High
           - Critical

     - type: input
       id: tags
       attributes:
         label: Tags
         description: Area tags (e.g. api, ui, data, infra)
         placeholder: api, data

     - type: input
       id: depends-on
       attributes:
         label: Depends On
         description: Task issue numbers this depends on
         placeholder: "#10, #11"
   ```

5. **Ensure standard labels exist**:

   ```bash
   gh label create "spec"    --color "5319E7" --description "Spec-level tracking issue"       --force 2>/dev/null || true
   gh label create "planned" --color "FBCA04" --description "Spec has a technical plan"        --force 2>/dev/null || true
   gh label create "ready"   --color "0075CA" --description "Spec tasks have been decomposed"  --force 2>/dev/null || true
   gh label create "task"    --color "1D76DB" --description "Task from spec"                   --force 2>/dev/null || true
   ```

6. **Ensure issue types `Spec` and `Task` exist** — only supported for organization repos. Skip silently for personal user repos:

   ```bash
   OWNER=$(echo $REPO | cut -d'/' -f1)
   ACCOUNT_TYPE=$(gh api users/$OWNER --jq '.type' 2>/dev/null || echo "")
   if [ "$ACCOUNT_TYPE" = "Organization" ]; then
     EXISTING_TYPES=$(gh api orgs/$OWNER/issue-types --jq '.[].name' 2>/dev/null || echo "")
     for IT_NAME in "Spec" "Task"; do
       if ! echo "$EXISTING_TYPES" | grep -qx "$IT_NAME"; then
         # Prompt user: "Issue type '<IT_NAME>' not found. Create it? (yes/no)"
         # If approved:
         COLOR=$([ "$IT_NAME" = "Spec" ] && echo "5319E7" || echo "1D76DB")
         DESC=$([ "$IT_NAME" = "Spec" ] && echo "Spec-level tracking issue" || echo "Task from spec")
         gh api orgs/$OWNER/issue-types --method POST -f name="$IT_NAME" -f color="$COLOR" -f description="$DESC" 2>/dev/null || true
       fi
     done
   fi
   ```

7. **Create or update `.github/pull_request_template.md`**:
   - If it already exists and contains a `## Related Spec` section, skip.
   - If it exists but lacks `## Related Spec`, append it after the first `## ` section.
   - If it doesn't exist, create it with the content below.

   Full template content (use when creating from scratch):

   ```markdown
   ## Summary

   <!-- Briefly describe what this PR does and why it's needed -->

   ## Related Spec

   <!-- Link the parent spec issue: Implements #<spec-issue-number> -->
   <!-- Link the task this PR implements: Closes #<task-issue-number> -->

   ## Changes

   <!-- List the key changes made -->

   -

   ## Testing

   - [ ] Tested locally
   - [ ] All acceptance criteria from the task issue are met

   ## Checklist

   - [ ] Code follows project conventions
   - [ ] Documentation updated if needed
   - [ ] No breaking changes (or documented with migration guide)
   - [ ] Commit messages follow conventional commit style
   ```

8. **Commit all created/modified files** using `/git:commit`.

9. Output a summary:

   ```
   ✅ Spec best practices bootstrapped for <repo>

   Files added/updated:
     .github/ISSUE_TEMPLATE/bug_report.yml
     .github/ISSUE_TEMPLATE/feature_request.yml
     .github/ISSUE_TEMPLATE/spec.yml
     .github/ISSUE_TEMPLATE/task.yml
     .github/pull_request_template.md

   Labels ensured:
     spec, planned, ready, task

   Issue types ensured:
     Spec, Task

   Next steps:
     - Create your first spec: /pm:spec-init <feature-name>
   ```

## Prerequisites
- Must be inside a GitHub repository
- Must be authenticated: `gh auth status`
