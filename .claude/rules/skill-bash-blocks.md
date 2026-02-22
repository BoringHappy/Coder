# Skill Preflight: Use Multiline Bash Blocks

In SKILL.md files, always use multiline bash blocks for preflight commands instead of inline backtick syntax.

**Wrong:**
```
!`if [ -z "$ARGUMENTS" ]; then echo "error"; exit 1; fi`
```

**Correct:**
````
!```bash
if [ -z "$ARGUMENTS" ]; then
  echo "error"
  exit 1
fi
```
````

Inline backtick syntax with semicolons triggers ambiguous command separator errors in the permission checker.
