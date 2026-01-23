#!/bin/bash

# Color codes
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
RED='\033[1;31m'
RESET='\033[0m'

if [ -z "$GITHUB_TOKEN" ]; then
    printf "${RED}Error: GITHUB_TOKEN environment variable is required${RESET}\n"
    exit 1
fi

printf "${YELLOW}Setting up GitHub CLI authentication...${RESET}\n"

TOKEN="$GITHUB_TOKEN"
unset GITHUB_TOKEN
echo "$TOKEN" | gh auth login --with-token

printf "${YELLOW}Setting up git credential helper...${RESET}\n"
gh auth setup-git

printf "${GREEN}✓ GitHub CLI authentication completed successfully${RESET}\n"
