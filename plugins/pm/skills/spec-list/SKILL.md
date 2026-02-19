---
name: spec-list
description: Lists all specs in .claude/specs/ with their status and task counts. Use when the user wants to discover existing specs or get a project overview.
---

# Spec List

Lists all feature specs in `.claude/specs/` with status and task summary.

## Specs

!`
if [ ! -d ".claude/specs" ] || [ -z "$(ls .claude/specs/*.md 2>/dev/null)" ]; then
  echo "No specs found. Create your first spec with: /pm:spec-init <feature-name>"
  exit 0
fi

echo "📋 Feature Specs"
echo "================"
echo ""

for spec in .claude/specs/*.md; do
  [ -f "$spec" ] || continue
  name=$(basename "$spec" .md)
  status=$(grep "^status:" "$spec" | head -1 | sed 's/^status: *//')
  created=$(grep "^created:" "$spec" | head -1 | sed 's/^created: *//' | cut -c1-10)
  total=$(grep -c "^  - title:" "$spec" 2>/dev/null || echo 0)
  synced=$(grep -c 'issue_url: "https' "$spec" 2>/dev/null || echo 0)

  case "$status" in
    draft)       icon="📝" ;;
    planned)     icon="📐" ;;
    ready)       icon="✅" ;;
    in-progress) icon="🔄" ;;
    completed)   icon="🎉" ;;
    *)           icon="📄" ;;
  esac

  echo "$icon  $name"
  echo "    Status: ${status:-draft} | Created: ${created:-unknown} | Tasks: $synced/$total synced"
  echo ""
done

echo "Total: $(ls .claude/specs/*.md 2>/dev/null | wc -l) spec(s)"
`

## Instructions

Display the spec list shown above. If no specs exist, prompt the user to create one with `/pm:spec-init <feature-name>`.

For each spec, suggest the appropriate next step based on its status:
- `draft` → `/pm:spec-plan <name>`
- `planned` → `/pm:spec-decompose <name>`
- `ready` → `/pm:spec-sync <name>`
- `in-progress` → `/pm:spec-status <name>`
