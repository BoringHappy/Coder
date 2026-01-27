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

# Check which plugins are already installed
printf "\n${CYAN}Checking existing plugins...${RESET}\n"
EXISTING_PLUGINS=$(claude plugin list 2>/dev/null || echo "")

# Track which plugins need to be installed
NEED_AGENT_BROWSER=true
NEED_GIT=true
NEED_PR=true

if echo "$EXISTING_PLUGINS" | grep -q "agent-browser@agent-browser"; then
    printf "  ${GREEN}✓ agent-browser@agent-browser already installed${RESET}\n"
    NEED_AGENT_BROWSER=false
fi

if echo "$EXISTING_PLUGINS" | grep -q "git@codemate"; then
    printf "  ${GREEN}✓ git@codemate already installed${RESET}\n"
    NEED_GIT=false
fi

if echo "$EXISTING_PLUGINS" | grep -q "pr@codemate"; then
    printf "  ${GREEN}✓ pr@codemate already installed${RESET}\n"
    NEED_PR=false
fi

# Exit early if all plugins are installed
if [ "$NEED_AGENT_BROWSER" = false ] && [ "$NEED_GIT" = false ] && [ "$NEED_PR" = false ]; then
    printf "\n${GREEN}✓ All plugins already installed${RESET}\n"
    exit 0
fi

printf "\n${YELLOW}Installing missing plugins...${RESET}\n\n"

# Add marketplaces only if needed
if [ "$NEED_AGENT_BROWSER" = true ]; then
    printf "${CYAN}Adding agent-browser marketplace:${RESET}\n"
    add_marketplace "1/1" "vercel-labs/agent-browser" "vercel-labs/agent-browser"
fi

if [ "$NEED_GIT" = true ] || [ "$NEED_PR" = true ]; then
    printf "${CYAN}Adding codemate marketplace:${RESET}\n"
    add_marketplace "1/1" "codemate" "BoringHappy/CodeMate"
fi

# Install only missing plugins
printf "\n${CYAN}Installing missing plugins:${RESET}\n"
INSTALL_COUNT=0
INSTALL_TOTAL=0

# Count how many plugins need to be installed
[ "$NEED_AGENT_BROWSER" = true ] && INSTALL_TOTAL=$((INSTALL_TOTAL + 1))
[ "$NEED_GIT" = true ] && INSTALL_TOTAL=$((INSTALL_TOTAL + 1))
[ "$NEED_PR" = true ] && INSTALL_TOTAL=$((INSTALL_TOTAL + 1))

if [ "$NEED_AGENT_BROWSER" = true ]; then
    INSTALL_COUNT=$((INSTALL_COUNT + 1))
    install_and_verify_plugin "${INSTALL_COUNT}/${INSTALL_TOTAL}" "agent-browser@agent-browser" "/agent-browser:agent-browser"
fi

if [ "$NEED_GIT" = true ]; then
    INSTALL_COUNT=$((INSTALL_COUNT + 1))
    install_and_verify_plugin "${INSTALL_COUNT}/${INSTALL_TOTAL}" "git@codemate" "/git:commit"
fi

if [ "$NEED_PR" = true ]; then
    INSTALL_COUNT=$((INSTALL_COUNT + 1))
    install_and_verify_plugin "${INSTALL_COUNT}/${INSTALL_TOTAL}" "pr@codemate" "/pr:get-details, /pr:fix-comments, /pr:update"
fi

printf "\n${GREEN}✓ Plugin setup complete${RESET}\n"
