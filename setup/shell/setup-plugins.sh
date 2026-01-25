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
printf "  [1/2] Adding vercel-labs/agent-browser marketplace...\n"
if claude plugin marketplace add vercel-labs/agent-browser 2>&1; then
    printf "  ${GREEN}✓ vercel-labs/agent-browser marketplace added${RESET}\n"
else
    printf "  ${YELLOW}⚠ Failed to add vercel-labs/agent-browser marketplace${RESET}\n"
fi

printf "  [2/2] Adding local codemate marketplace...\n"
if claude plugin marketplace add /usr/local/bin/setup/marketplace 2>&1; then
    printf "  ${GREEN}✓ codemate marketplace added${RESET}\n"
else
    printf "  ${YELLOW}⚠ Failed to add codemate marketplace${RESET}\n"
fi

# Install plugins
printf "\n${CYAN}Installing plugins:${RESET}\n"
printf "  [1/3] Installing agent-browser@agent-browser...\n"
if claude plugin install agent-browser@agent-browser 2>&1; then
    printf "  ${GREEN}✓ agent-browser@agent-browser installed${RESET}\n"
else
    printf "  ${RED}✗ agent-browser@agent-browser installation failed${RESET}\n"
fi

printf "  [2/3] Installing git@codemate...\n"
if claude plugin install git@codemate 2>&1; then
    printf "  ${GREEN}✓ git@codemate installed${RESET}\n"
else
    printf "  ${RED}✗ git@codemate installation failed${RESET}\n"
fi

printf "  [3/3] Installing pr@codemate...\n"
if claude plugin install pr@codemate 2>&1; then
    printf "  ${GREEN}✓ pr@codemate installed${RESET}\n"
else
    printf "  ${RED}✗ pr@codemate installation failed${RESET}\n"
fi

# Verify installations and show loaded plugins
printf "\n${CYAN}Verifying plugin installations:${RESET}\n"
INSTALLED_PLUGINS=$(claude plugin list 2>/dev/null || echo "")

if echo "$INSTALLED_PLUGINS" | grep -q "git@codemate"; then
    printf "${GREEN}✓ git@codemate${RESET}\n"
    printf "  Skills: /git:commit\n"
else
    printf "${RED}✗ git@codemate not found${RESET}\n"
fi

if echo "$INSTALLED_PLUGINS" | grep -q "pr@codemate"; then
    printf "${GREEN}✓ pr@codemate${RESET}\n"
    printf "  Skills: /pr:get-details, /pr:fix-comments, /pr:update\n"
else
    printf "${RED}✗ pr@codemate not found${RESET}\n"
fi

if echo "$INSTALLED_PLUGINS" | grep -q "agent-browser@agent-browser"; then
    printf "${GREEN}✓ agent-browser@agent-browser${RESET}\n"
    printf "  Skills: /agent-browser:agent-browser\n"
else
    printf "${RED}✗ agent-browser@agent-browser not found${RESET}\n"
fi

printf "\n${GREEN}✓ Plugin setup complete${RESET}\n"
