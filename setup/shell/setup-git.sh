#!/bin/bash

# Color codes
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
RED='\033[1;31m'
BLUE='\033[1;34m'
RESET='\033[0m'

if [ -z "$GIT_USER_NAME" ]; then
    printf "${RED}Error: GIT_USER_NAME environment variable is required${RESET}\n"
    exit 1
fi

if [ -z "$GIT_USER_EMAIL" ]; then
    printf "${RED}Error: GIT_USER_EMAIL environment variable is required${RESET}\n"
    exit 1
fi

printf "${YELLOW}Setting up git config...${RESET}\n"

printf "  Setting git user.name: ${BLUE}$GIT_USER_NAME${RESET}\n"
git config --global user.name "$GIT_USER_NAME"

printf "  Setting git user.email: ${BLUE}$GIT_USER_EMAIL${RESET}\n"
git config --global user.email "$GIT_USER_EMAIL"

printf "${GREEN}✓ Git config setup completed successfully${RESET}\n"
