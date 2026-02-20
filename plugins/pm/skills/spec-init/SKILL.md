---
name: spec-init
description: Starts a guided brainstorming session to create a new spec as a GitHub Issue. Use when the user wants to define requirements for a new feature before writing any code.
---

# Spec Init

Creates a new feature spec as a GitHub Issue through a guided requirements session.

Usage: `/pm:spec-init <feature-name>`

## Preflight

!`
NAME="$ARGUMENTS"

# Validate argument
if [ -z "$NAME" ]; then
  echo "[ERROR] No feature name provided. Usage: /pm:spec-init <feature-name>"
  exit 1
fi

# Validate kebab-case
if ! echo "$NAME" | grep -qE '^[a-z][a-z0-9-]*$'; then
  echo "[ERROR] Feature name must be kebab-case (lowercase letters, numbers, hyphens). Example: user-auth"
  exit 1
fi

# Check GitHub auth
gh auth status 2>&1 | head -3

# Check for existing open spec issue with this name
echo ""
echo "--- Checking for existing spec issue ---"
EXISTING=$(gh issue list --label "spec:$NAME" --label "spec" --state open --json number,title,url --jq '.[] | "#\(.number) \(.title) \(.url)"' 2>/dev/null || echo "")
if [ -n "$EXISTING" ]; then
  echo "[WARN] Existing open spec issue found:"
  echo "$EXISTING"
else
  echo "[OK] No existing spec issue for: $NAME"
fi

# Show repo
gh repo view --json nameWithOwner -q '"Repo: \(.nameWithOwner)"' | cat
`

## Instructions

1. **If an existing spec issue was found** in preflight, ask the user: "A spec issue already exists for `$ARGUMENTS`. Open a new one anyway? (yes/no)". Stop if they say no.

2. **Run a discovery session** — ask the user focused questions to understand the feature. Cover:
   - What problem does this solve?
   - Who are the users and what are their goals?
   - What are the key use cases / user stories?
   - What are the functional requirements?
   - What are the non-functional requirements (performance, security, scale)?
   - What is explicitly out of scope?
   - What are the dependencies or constraints?
   - How will success be measured?

3. **Ensure labels exist** before creating the issue:
   ```bash
   gh label create "spec" --color "5319E7" --description "Spec-level tracking issue" --force 2>/dev/null || true
   gh label create "spec:$ARGUMENTS" --color "0E8A16" --description "Part of spec: $ARGUMENTS" --force 2>/dev/null || true
   ```

4. **Create the spec issue** with the structured content from the discovery session:

   ```bash
   gh issue create \
     --title "[Spec]: $ARGUMENTS" \
     --label "spec" \
     --label "spec:$ARGUMENTS" \
     --body "<body>"
   ```

   Use this body format:

   ```
   ## Problem Statement
   <what problem this solves and why it matters>

   ## Users & Goals
   <who uses this and what they want to achieve>

   ## User Stories
   - As a <persona>, I want to <action> so that <outcome>

   ## Functional Requirements
   - <requirement 1>
   - <requirement 2>

   ## Non-Functional Requirements
   - <performance, security, reliability, etc.>

   ## Out of Scope
   - <explicit exclusions>

   ## Dependencies & Constraints
   - <external services, team dependencies, technical constraints>

   ## Success Criteria
   - <measurable outcomes that define done>
   ```

5. Confirm: "✅ Spec issue created: `[Spec]: $ARGUMENTS` → <issue_url>"
6. Suggest next step: "Ready to plan the implementation? Run: `/pm:spec-plan $ARGUMENTS`"

## Prerequisites
- Feature name must be provided as argument
- Feature name must be kebab-case
- Must be authenticated: `gh auth status`
- Must be inside a GitHub repository
