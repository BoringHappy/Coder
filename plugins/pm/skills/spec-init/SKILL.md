---
name: spec-init
description: Starts a guided brainstorming session to create a new SPEC.md for a feature. Use when the user wants to define requirements for a new feature before writing any code.
---

# Spec Init

Creates a new feature spec at `.claude/specs/$ARGUMENTS.md` through a guided requirements session.

## Preflight

!`
SPEC=".claude/specs/$ARGUMENTS.md"
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

# Check for existing spec
if [ -f "$SPEC" ]; then
  echo "[WARN] Spec already exists: $SPEC"
else
  echo "[OK] Ready to create: $SPEC"
  mkdir -p .claude/specs
fi
`

## Instructions

1. **If the spec already exists**, ask the user: "Spec already exists at `.claude/specs/$ARGUMENTS.md`. Overwrite? (yes/no)". Stop if they say no.

2. **Run a discovery session** — ask the user focused questions to understand the feature. Cover:
   - What problem does this solve?
   - Who are the users and what are their goals?
   - What are the key use cases / user stories?
   - What are the functional requirements?
   - What are the non-functional requirements (performance, security, scale)?
   - What is explicitly out of scope?
   - What are the dependencies or constraints?
   - How will success be measured?

3. **Write the spec** to `.claude/specs/$ARGUMENTS.md` with this exact structure:

```markdown
---
name: $ARGUMENTS
status: draft
created: <ISO datetime from: date -u +"%Y-%m-%dT%H:%M:%SZ">
tasks: []
pr: ""
---

# Spec: $ARGUMENTS

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

4. Confirm: "✅ Spec created: `.claude/specs/$ARGUMENTS.md`"
5. Suggest next step: "Ready to plan the implementation? Run: `/pm:spec-plan $ARGUMENTS`"

## Prerequisites
- Feature name must be provided as argument
- Feature name must be kebab-case
