#!/bin/bash
# Check for uncommitted git changes and inject a commit prompt if found.
# Works both as a standalone Stop hook and when sourced by monitor_pr.sh.
#
# Uses a counter file to avoid infinite blocking loops: after MAX_BLOCKS
# consecutive blocks without changes being committed, it downgrades to a
# warning so Claude can actually stop.

BLOCK_COUNTER_FILE="/tmp/.git_changes_block_count"
MAX_BLOCKS=2

_git_changes_inject() {
    printf '{"decision":"block","reason":"Please use /git:commit skill to submit changes to github"}'
}

_git_changes_warn() {
    printf '{"decision":"warn","reason":"Uncommitted changes remain. Use /git:commit to push them to github."}'
}

check_git_changes() {
    local git_changes
    git_changes=$(git status --porcelain 2>/dev/null || echo "")

    if [ -z "$git_changes" ]; then
        # Clean — reset counter
        rm -f "$BLOCK_COUNTER_FILE"
        return
    fi

    # Read current block count
    local count=0
    [ -f "$BLOCK_COUNTER_FILE" ] && count=$(cat "$BLOCK_COUNTER_FILE")

    if [ "$count" -lt "$MAX_BLOCKS" ]; then
        echo $((count + 1)) > "$BLOCK_COUNTER_FILE"
        _git_changes_inject
    else
        # Exceeded max blocks — warn instead of block to avoid infinite loop
        rm -f "$BLOCK_COUNTER_FILE"
        _git_changes_warn
    fi
    exit 0
}

# Run directly when executed as a standalone hook
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    check_git_changes
fi
