---
name: spec-abandon
description: Marks a spec as abandoned and optionally closes its linked GitHub Issues. Use when a feature is cancelled or no longer being pursued.
---

# Spec Abandon

Marks `.claude/specs/$ARGUMENTS.md` as abandoned and optionally closes any linked GitHub Issues.

## Preflight

!`
SPEC=".claude/specs/$ARGUMENTS.md"

if [ -z "$ARGUMENTS" ]; then
  echo "[ERROR] No feature name provided. Usage: /pm:spec-abandon <feature-name>"
  if [ -d ".claude/specs" ]; then
    echo ""
    echo "Available specs:"
    for f in .claude/specs/*.md; do
      [ -f "$f" ] && echo "  • $(basename "$f" .md)"
    done
  fi
  exit 1
fi

if [ ! -f "$SPEC" ]; then
  echo "[ERROR] Spec not found: $SPEC"
  if [ -d ".claude/specs" ]; then
    echo ""
    echo "Available specs:"
    for f in .claude/specs/*.md; do
      [ -f "$f" ] && echo "  • $(basename "$f" .md)"
    done
  fi
  exit 1
fi

spec_status=$(grep "^status:" "$SPEC" | head -1 | sed 's/^status: *//')
echo "[OK] Spec found: $SPEC (status: ${spec_status:-draft})"

echo ""
echo "--- Synced issues ---"
grep "issue_url:" "$SPEC" | grep "https" | sed 's/.*issue_url: *"//' | sed 's/"//' | while read url; do
  issue_num=$(echo "$url" | grep -oE '[0-9]+$')
  if [ -n "$issue_num" ]; then
    gh issue view "$issue_num" --json number,title,state \
      -q '"#\(.number) [\(.state | ascii_upcase)] \(.title)"' 2>/dev/null || echo "#$issue_num [ERROR] Could not fetch"
  fi
done
`

## Instructions

1. **Confirm with the user** before making any changes:
   - Show the spec name and current status from preflight output
   - List any synced issues found above
   - Ask: "Are you sure you want to abandon `$ARGUMENTS`? This will mark the spec as abandoned. Reply with yes/no, and whether to also close any open GitHub Issues (yes/no)."
   - Stop if they say no.

2. **Update the spec status** to `abandoned` by editing the frontmatter in `.claude/specs/$ARGUMENTS.md`:
   - Change `status: <current>` to `status: abandoned`

3. **If the user wants to close open issues**, for each synced issue that is OPEN:
   - Run: `gh issue close <number> --comment "Closing: parent spec \`$ARGUMENTS\` has been abandoned."`

4. Confirm: "✅ Spec `$ARGUMENTS` marked as abandoned."
   - If issues were closed, list them: "Closed issues: #N, #N, ..."
   - Suggest cleanup: "To delete the spec file entirely, run: `rm .claude/specs/$ARGUMENTS.md`"

## Prerequisites
- Spec must exist at `.claude/specs/$ARGUMENTS.md`
- GitHub CLI authenticated (only needed if closing issues)
