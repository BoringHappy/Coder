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

# Check if plugins are already installed
printf "\n${CYAN}Checking existing plugins...${RESET}\n"
EXISTING_PLUGINS=$(claude plugin list 2>/dev/null || echo "")
if echo "$EXISTING_PLUGINS" | grep -q "git@codemate" && \
   echo "$EXISTING_PLUGINS" | grep -q "pr@codemate" && \
   echo "$EXISTING_PLUGINS" | grep -q "agent-browser@agent-browser"; then
    printf "${GREEN}✓ All plugins already installed${RESET}\n"
    printf "\n${CYAN}Currently loaded plugins:${RESET}\n"
    echo "$EXISTING_PLUGINS" | grep -E "(git@codemate|pr@codemate|agent-browser@agent-browser)" || true
    exit 0
fi

printf "${YELLOW}Installing plugins...${RESET}\n\n"

# Add marketplaces
printf "${CYAN}Adding marketplaces:${RESET}\n"
add_marketplace "1/2" "vercel-labs/agent-browser" "vercel-labs/agent-browser"
add_marketplace "2/2" "codemate" "/usr/local/bin/setup/marketplace"

# Install and verify plugins
printf "\n${CYAN}Installing and verifying plugins:${RESET}\n"
install_and_verify_plugin "1/3" "agent-browser@agent-browser" "/agent-browser:agent-browser"
install_and_verify_plugin "2/3" "git@codemate" "/git:commit"
install_and_verify_plugin "3/3" "pr@codemate" "/pr:get-details, /pr:fix-comments, /pr:update"

printf "\n${GREEN}✓ Plugin setup complete${RESET}\n"
