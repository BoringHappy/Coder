---
name: spec-plan
description: Converts a SPEC.md into a technical implementation plan by appending architecture decisions, tech approach, and a task breakdown. Use after spec-init to turn requirements into an engineering plan.
---

# Spec Plan

Reads `.claude/specs/$ARGUMENTS.md` and appends a technical implementation plan to it.

## Preflight

!`
SPEC=".claude/specs/$ARGUMENTS.md"

if [ -z "$ARGUMENTS" ]; then
  echo "[ERROR] No feature name provided. Usage: /pm:spec-plan <feature-name>"
  exit 1
fi

if [ ! -f "$SPEC" ]; then
  echo "[ERROR] Spec not found: $SPEC. Create it first with: /pm:spec-init $ARGUMENTS"
  exit 1
fi

# Check if plan already exists
if grep -q "^## Architecture" "$SPEC" 2>/dev/null; then
  echo "[WARN] Plan sections already exist in spec"
else
  echo "[OK] Spec found, ready to plan"
fi

echo "--- Current spec ---"
cat "$SPEC"
`

## Instructions

1. **If plan sections already exist**, ask: "Technical plan already exists in this spec. Overwrite? (yes/no)". If yes, remove existing plan sections before proceeding.

2. **Analyze the spec** above and produce a technical plan covering:
   - Architecture decisions (patterns, data models, key choices and their rationale)
   - Tech approach broken down by layer (e.g. DB, API, UI, infra)
   - Task breakdown: a list of concrete, parallelizable tasks sized 1–3 days each. Max 10 tasks. Each task needs:
     - A short title
     - Which layer it belongs to
     - Whether it can run in parallel with others
     - What it depends on (if anything)

3. **Append** the following sections to the spec file (do not overwrite existing content):

```markdown

## Architecture Decisions
- <decision>: <rationale>

## Technical Approach

### Data Layer
<schema, models, migrations>

### Service / API Layer
<endpoints, business logic, integrations>

### UI Layer
<components, pages, interactions — omit if not applicable>

### Infrastructure
<deployment, config, observability — omit if not applicable>

## Task Breakdown
| # | Title | Layer | Parallel | Depends On |
|---|-------|-------|----------|------------|
| 1 | <title> | <layer> | yes/no | — |
| 2 | <title> | <layer> | yes/no | 1 |

## Effort Estimate
- Total tasks: <n>
- Parallel tasks: <n>
- Sequential tasks: <n>
```

4. Update the spec frontmatter `status` from `draft` to `planned`.

5. Confirm: "✅ Technical plan added to `.claude/specs/$ARGUMENTS.md`"
6. Suggest next step: "Ready to create tasks? Run: `/pm:spec-decompose $ARGUMENTS`"

## Prerequisites
- Spec must exist at `.claude/specs/$ARGUMENTS.md`
- Run `/pm:spec-init $ARGUMENTS` first if it doesn't
