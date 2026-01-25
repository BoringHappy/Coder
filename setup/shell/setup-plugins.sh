#!/bin/bash
set -e

# Color codes
CYAN='\033[1;36m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RESET='\033[0m'

printf "${CYAN}Setting up Claude Code plugins...${RESET}\n"

# Create tmp directory in .claude to avoid cross-device link errors
mkdir -p /home/agent/.claude/tmp
export TMPDIR=/home/agent/.claude/tmp

# Check if plugins are already installed
if claude plugin list 2>/dev/null | grep -q "git@codemate" && \
   claude plugin list 2>/dev/null | grep -q "pr@codemate" && \
   claude plugin list 2>/dev/null | grep -q "agent-browser@agent-browser"; then
    printf "${GREEN}✓ Plugins already installed${RESET}\n"
    exit 0
fi

printf "${YELLOW}Installing plugins...${RESET}\n"

# Add marketplaces
printf "  Adding vercel-labs/agent-browser marketplace...\n"
claude plugin marketplace add vercel-labs/agent-browser 2>/dev/null || true

printf "  Adding local codemate marketplace...\n"
claude plugin marketplace add /usr/local/bin/setup/marketplace 2>/dev/null || true

# Install plugins
printf "  Installing agent-browser plugin...\n"
claude plugin install agent-browser@agent-browser 2>/dev/null || printf "${YELLOW}  Warning: agent-browser plugin installation failed${RESET}\n"

printf "  Installing git plugin...\n"
claude plugin install git@codemate 2>/dev/null || printf "${YELLOW}  Warning: git plugin installation failed${RESET}\n"

printf "  Installing pr plugin...\n"
claude plugin install pr@codemate 2>/dev/null || printf "${YELLOW}  Warning: pr plugin installation failed${RESET}\n"

# Verify installations
printf "\n${CYAN}Verifying plugin installations...${RESET}\n"
if claude plugin list 2>/dev/null | grep -q "git@codemate"; then
    printf "${GREEN}✓ git@codemate installed${RESET}\n"
else
    printf "${YELLOW}⚠ git@codemate not found${RESET}\n"
fi

if claude plugin list 2>/dev/null | grep -q "pr@codemate"; then
    printf "${GREEN}✓ pr@codemate installed${RESET}\n"
else
    printf "${YELLOW}⚠ pr@codemate not found${RESET}\n"
fi

if claude plugin list 2>/dev/null | grep -q "agent-browser@agent-browser"; then
    printf "${GREEN}✓ agent-browser@agent-browser installed${RESET}\n"
else
    printf "${YELLOW}⚠ agent-browser@agent-browser not found${RESET}\n"
fi

printf "${GREEN}✓ Plugin setup complete${RESET}\n"
