# Issue Plugin

GitHub Issue workflow management plugin for CodeMate.

## Skills

### `/issue:read-issue`
Reads details of a GitHub issue including title, description, labels, assignees, and comments.

```
/issue:read-issue 44
```

### `/issue:refine-issue`
Rewrites an issue body to fully satisfy the matching issue template, incorporating context from comments. Uses a plan-then-execute workflow — shows a proposed refined body and waits for approval before making any changes. After approval, automatically invokes `/issue:judge-issue` to apply labels.

```
/issue:refine-issue 44
```

### `/issue:judge-issue`
Analyzes an issue and applies priority (`priority:high`, `priority:medium`, `priority:low`) and category (`bug`, `enhancement`, `documentation`, `question`) labels based on content, impact, and urgency.

```
/issue:judge-issue 44
```

### `/issue:classify-issue`
Identifies unclear or missing information in an issue and posts targeted clarifying questions as a comment. Adds the `needs-more-info` label if clarification is needed. If the issue is already clear, reports that no action is needed.

```
/issue:classify-issue 44
```
