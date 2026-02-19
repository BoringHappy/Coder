# Issue Plugin

GitHub Issue workflow management plugin for CodeMate.

## Skills

### `/issue:read-issue`
Reads details of a GitHub issue including title, description, labels, assignees, and comments.

```
/issue:read-issue 44
```

### `/issue:refine`
Rewrites an issue body to fully satisfy the matching issue template, incorporating context from comments. Uses a plan-then-execute workflow — shows a proposed refined body and waits for approval before making any changes. After approval, automatically invokes `/issue:judge` to apply labels.

```
/issue:refine 44
```

### `/issue:judge`
Analyzes an issue and applies priority (`priority:high`, `priority:medium`, `priority:low`) and category (`bug`, `enhancement`, `documentation`, `question`) labels based on content, impact, and urgency.

```
/issue:judge 44
```

### `/issue:clean`
Identifies unclear or missing information in an issue and posts targeted clarifying questions as a comment. Adds the `needs-more-info` label if clarification is needed. If the issue is already clear, reports that no action is needed.

```
/issue:clean 44
```
