# pm Plugin

Spec-driven project management for GitHub repos. Manages feature specs as GitHub Issues — from requirements through task decomposition using sub-issues.

## Workflow

```
/pm:spec-list              # discover existing specs (GitHub Issues)
/pm:spec-init <name>       # brainstorm → create spec GitHub Issue
      ↓
/pm:spec-plan <name>       # requirements → technical plan appended to spec issue
      ↓
/pm:spec-decompose <name>  # task breakdown → task issues as sub-issues of spec
      ↓
/pm:spec-status <name>     # live progress summary from GitHub Issues
/pm:spec-next <name>       # find next actionable task based on dependencies
```

## Skills

### `/pm:spec-list`
Lists all spec GitHub Issues (labeled `spec`) with state and task counts. Suggests the next action for each spec based on its labels.

### `/pm:spec-init <feature-name>`
Runs a guided discovery session and creates a GitHub Issue titled `[Spec]: <feature-name>` with labels `spec` and `spec:<feature-name>`.

Covers: problem statement, user stories, functional/non-functional requirements, out of scope, dependencies, success criteria.

### `/pm:spec-plan <feature-name> [--granularity micro|pr|macro]`
Fetches the spec issue and appends a technical implementation plan: architecture decisions, area-by-area approach, and a task breakdown table. Adds a `planned` label to the spec issue.

### `/pm:spec-decompose <feature-name> [--granularity micro|pr|macro]`
Parses the task breakdown table from the spec issue, creates individual task GitHub Issues, and registers them as **sub-issues** of the spec issue. The `--granularity` flag controls how tasks are split:
- `micro` — split aggressively into 0.5–1 day tasks
- `pr` (default) — PR-sized 1–3 day tasks; auto-detected from spec if set by `spec-plan`
- `macro` — merge into 3–7 day milestones

Adds a `ready` label to the spec issue.

### `/pm:spec-status <feature-name>`
Fetches the spec issue and all task sub-issues from GitHub. Shows a progress table (✅ closed / 🔄 open), a progress bar, and what's next to work on.

### `/pm:spec-next <feature-name>`
Finds the next actionable task(s) by checking live GitHub Issue status and resolving dependencies. Lists tasks that are open with all dependencies closed, and highlights blocked tasks.

### `/pm:spec-abandon <feature-name>`
Closes the spec GitHub Issue and optionally closes all linked task issues. Use when a feature is cancelled or no longer being pursued.

## Labels Used

| Label | Purpose |
|-------|---------|
| `spec` | Marks a spec-level issue |
| `spec:<name>` | Groups all issues (spec + tasks) for a spec |
| `task` | Marks a task-level issue |
| `planned` | Spec has a technical plan |
| `ready` | Spec tasks have been decomposed into sub-issues |

## Requirements

- `gh` CLI authenticated (`gh auth login`)
- Must be run inside a GitHub repository
