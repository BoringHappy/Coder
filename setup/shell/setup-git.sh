#!/bin/bash

# Color codes
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
RED='\033[1;31m'
BLUE='\033[1;34m'
RESET='\033[0m'

if [ -z "$GIT_USER_NAME" ]; then
    echo -e "${RED}Error: GIT_USER_NAME environment variable is required${RESET}"
    exit 1
fi

if [ -z "$GIT_USER_EMAIL" ]; then
    echo -e "${RED}Error: GIT_USER_EMAIL environment variable is required${RESET}"
    exit 1
fi

echo -e "${YELLOW}Setting up git config...${RESET}"

echo -e "  Setting git user.name: ${BLUE}$GIT_USER_NAME${RESET}"
git config --global user.name "$GIT_USER_NAME"

echo -e "  Setting git user.email: ${BLUE}$GIT_USER_EMAIL${RESET}"
git config --global user.email "$GIT_USER_EMAIL"

echo -e "${GREEN}✓ Git config setup completed successfully${RESET}"
