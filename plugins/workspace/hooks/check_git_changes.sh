#!/bin/bash
# Check for uncommitted git changes and inject a commit prompt if found.
# Works both as a standalone Stop hook and when sourced by monitor_pr.sh.

_git_changes_inject() {
    printf '{"decision":"block","reason":"Please use /git:commit skill to submit changes to github"}'
}

check_git_changes() {
    local git_changes
    git_changes=$(git status --porcelain 2>/dev/null || echo "")
    if [ -n "$git_changes" ]; then
        _git_changes_inject
        exit 0
    fi
}

# Run directly when executed as a standalone hook
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    check_git_changes
fi
