# pm Plugin

Spec-driven project management for GitHub repos. Guides a feature from raw requirements through GitHub Issues using a single `SPEC.md` doc as the source of truth.

## Workflow

```
/pm:spec-list              # discover existing specs
/pm:spec-init <name>       # brainstorm → write requirements
      ↓
/pm:spec-plan <name>       # requirements → technical plan + task breakdown
      ↓
/pm:spec-decompose <name>  # task breakdown → structured tasks in frontmatter
      ↓
/pm:spec-sync <name>       # tasks → GitHub Issues, issue numbers written back to spec
      ↓
/pm:spec-status <name>     # live progress summary from spec + GitHub Issues
```

## Skills

### `/pm:spec-list`
Lists all specs in `.claude/specs/` with status, creation date, and task sync counts. Suggests the next action for each spec based on its current status.

### `/pm:spec-init <feature-name>`
Runs a guided discovery session and writes a `SPEC.md` to `.claude/specs/<feature-name>.md`.

Covers: problem statement, user stories, functional/non-functional requirements, out of scope, dependencies, success criteria.

### `/pm:spec-plan <feature-name>`
Reads the spec and appends a technical implementation plan: architecture decisions, area-by-area approach, and a task breakdown table (max 10 tasks, sized 1–3 days each).

### `/pm:spec-decompose <feature-name>`
Parses the task breakdown table and writes structured task entries into the spec's `tasks:` frontmatter field. Each task gets: title, tags, dependencies, and empty issue/issue_url fields ready for sync.

### `/pm:spec-sync <feature-name>`
Creates a GitHub Issue per task using the repo's issue template and writes the issue number and URL back into the spec frontmatter. Skips already-synced tasks (idempotent). Updates spec `status` to `in-progress`.

### `/pm:spec-status <feature-name>`
Reads the spec and fetches live issue state from GitHub for each task. Shows a progress table (✅ closed / 🔄 open / ⚠️ not synced), a progress bar, blocked tasks, and what's next to work on.

## Spec Format

```markdown
---
name: feature-name
status: draft | planned | ready | in-progress
created: 2026-01-01T00:00:00Z
tasks:
  - title: "Setup database schema"
    tags: [data]
    depends_on: []
    issue: 42
    issue_url: "https://github.com/org/repo/issues/42"
---

# Spec: feature-name
...
```

## Requirements

- `gh` CLI authenticated (`gh auth login`)
- Must be run inside a GitHub repository
