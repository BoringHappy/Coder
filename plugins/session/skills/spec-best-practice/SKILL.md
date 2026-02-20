---
name: spec-best-practice
description: Bootstraps a target repo with spec workflow resources — GitHub Issue templates for specs and tasks, standard labels, and a PR template. Run once to set up a repo for spec-driven development.
---

# Spec Best Practice

Adds spec workflow resources to the current repository: GitHub Issue templates, standard labels, and a PR template.

Usage: `/session:spec-best-practice`

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
elif [ -f ".github/PULL_REQUEST_TEMPLATE.md" ]; then
  echo "[WARN] PULL_REQUEST_TEMPLATE.md exists with uppercase name (will rename to lowercase)"
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

4. **Create `.github/ISSUE_TEMPLATE/spec.yml`**. If it already exists, ask the user to confirm overwrite before proceeding.

   Write this content:

   ```yaml
   name: "📋 Spec"
   description: Define requirements for a new feature before implementation
   labels: ["spec"]
   body:
     - type: markdown
       attributes:
         value: |
           Use this template to define a feature spec. Run `/pm:spec-init <feature-name>` in CodeMate to create one interactively.

     - type: input
       id: feature-name
       attributes:
         label: Feature Name
         description: Kebab-case identifier (e.g. user-auth, payment-flow)
         placeholder: my-feature
       validations:
         required: true

     - type: textarea
       id: problem
       attributes:
         label: Problem Statement
         description: What problem does this solve and why does it matter?
       validations:
         required: true

     - type: textarea
       id: users-goals
       attributes:
         label: Users & Goals
         description: Who uses this and what do they want to achieve?
       validations:
         required: true

     - type: textarea
       id: user-stories
       attributes:
         label: User Stories
         description: "Format: As a <persona>, I want to <action> so that <outcome>"
         placeholder: |
           - As a developer, I want to ...
       validations:
         required: true

     - type: textarea
       id: functional-requirements
       attributes:
         label: Functional Requirements
         placeholder: |
           - Requirement 1
           - Requirement 2
       validations:
         required: true

     - type: textarea
       id: non-functional
       attributes:
         label: Non-Functional Requirements
         description: Performance, security, reliability, scalability
         placeholder: |
           - Response time < 200ms

     - type: textarea
       id: out-of-scope
       attributes:
         label: Out of Scope
         placeholder: |
           - Feature X is explicitly excluded

     - type: textarea
       id: dependencies
       attributes:
         label: Dependencies & Constraints
         placeholder: |
           - Requires Auth service

     - type: textarea
       id: success-criteria
       attributes:
         label: Success Criteria
         description: Measurable outcomes that define done
         placeholder: |
           - All acceptance tests pass
       validations:
         required: true
   ```

5. **Create `.github/ISSUE_TEMPLATE/task.yml`**. If it already exists, ask the user to confirm overwrite.

   ```yaml
   name: "✅ Task"
   description: Implementation task linked to a spec
   labels: ["task"]
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
       id: description
       attributes:
         label: Description
         description: What needs to be done?
       validations:
         required: true

     - type: input
       id: tags
       attributes:
         label: Tags
         description: Area tags (e.g. api, ui, data, infra)
         placeholder: api, data

     - type: input
       id: estimate
       attributes:
         label: Effort Estimate
         placeholder: 1d

     - type: input
       id: depends-on
       attributes:
         label: Depends On
         description: Task issue numbers this depends on
         placeholder: "#10, #11"

     - type: textarea
       id: acceptance-criteria
       attributes:
         label: Acceptance Criteria
         placeholder: |
           - [ ] Criterion 1
           - [ ] Criterion 2
       validations:
         required: true
   ```

6. **Create `.github/ISSUE_TEMPLATE/config.yml`** if it doesn't exist:

   ```yaml
   blank_issues_enabled: true
   ```

7. **Ensure standard labels exist**:

   ```bash
   gh label create "spec"    --color "5319E7" --description "Spec-level tracking issue"       --force 2>/dev/null || true
   gh label create "planned" --color "FBCA04" --description "Spec has a technical plan"        --force 2>/dev/null || true
   gh label create "ready"   --color "0075CA" --description "Spec tasks have been decomposed"  --force 2>/dev/null || true
   gh label create "task"    --color "1D76DB" --description "Task from spec"                   --force 2>/dev/null || true
   ```

8. **Create or update `.github/pull_request_template.md`** (lowercase):
   - If `.github/PULL_REQUEST_TEMPLATE.md` (uppercase) exists, rename it to lowercase with `git mv`.
   - If `.github/pull_request_template.md` already exists and contains a `## Related Spec` section, skip.
   - If it exists but lacks `## Related Spec`, append it after the first `## ` section.
   - If it doesn't exist, create it with the content below.

   Full template content (use when creating from scratch):

   ```markdown
   ## Summary

   <!-- Briefly describe what this PR does and why it's needed -->

   ## Related Spec

   <!-- Link the parent spec issue: Closes #<spec-issue-number> -->
   <!-- Link the task this PR implements: Implements #<task-issue-number> -->

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

9. **Commit all created/modified files** using `/git:commit`.

10. Output a summary:

   ```
   ✅ Spec best practices bootstrapped for <repo>

   Files added/updated:
     .github/ISSUE_TEMPLATE/bug_report.yml
     .github/ISSUE_TEMPLATE/feature_request.yml
     .github/ISSUE_TEMPLATE/spec.yml
     .github/ISSUE_TEMPLATE/task.yml
     .github/ISSUE_TEMPLATE/config.yml
     .github/pull_request_template.md

   Labels ensured:
     spec, planned, ready, task

   Next steps:
     - Create your first spec: /pm:spec-init <feature-name>
   ```

## Prerequisites
- Must be inside a GitHub repository
- Must be authenticated: `gh auth status`
