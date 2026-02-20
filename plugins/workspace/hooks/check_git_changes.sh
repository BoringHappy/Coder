#!/bin/bash
# Check for uncommitted git changes and inject a commit prompt if found
# Sourced or called by monitor_pr.sh; uses inject_prompt from caller context
# Can also be run standalone (will output hook JSON directly)

check_git_changes() {
    local git_changes
    git_changes=$(git status --porcelain 2>/dev/null || echo "")
    if [ -n "$git_changes" ]; then
        inject_prompt "Please use /git:commit skill to submit changes to github"
    fi
}
