#!/bin/bash

# Color codes
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
RED='\033[1;31m'
RESET='\033[0m'

if [ -z "$GITHUB_TOKEN" ]; then
    echo -e "${RED}Error: GITHUB_TOKEN environment variable is required${RESET}"
    exit 1
fi

echo -e "${YELLOW}Setting up GitHub CLI authentication...${RESET}"

TOKEN="$GITHUB_TOKEN"
unset GITHUB_TOKEN
echo "$TOKEN" | gh auth login --with-token

echo -e "${YELLOW}Setting up git credential helper...${RESET}"
gh auth setup-git

echo -e "${GREEN}✓ GitHub CLI authentication completed successfully${RESET}"
