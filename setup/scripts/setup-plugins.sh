#!/bin/bash
set -e

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

printf "${CYAN}Setting up Claude Code plugins...${RESET}\n"

# Create tmp directory in .claude to avoid cross-device link errors
printf "  Creating temp directory at /home/agent/.claude/tmp\n"
mkdir -p /home/agent/.claude/tmp
export TMPDIR=/home/agent/.claude/tmp

# Add marketplaces (functions check if already added)
printf "\n${CYAN}Adding marketplaces:${RESET}\n"
add_marketplace "1/2" "vercel-labs/agent-browser" "vercel-labs/agent-browser"
add_marketplace "2/2" "codemate" "BoringHappy/CodeMate"

# Install plugins (functions check if already installed)
printf "\n${CYAN}Installing plugins:${RESET}\n"
install_and_verify_plugin "1/3" "agent-browser@agent-browser" "/agent-browser:agent-browser"
install_and_verify_plugin "2/3" "git@codemate" "/git:commit"
install_and_verify_plugin "3/3" "pr@codemate" "/pr:get-details, /pr:fix-comments, /pr:update"

printf "\n${GREEN}✓ Plugin setup complete${RESET}\n"
