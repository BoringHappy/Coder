#!/bin/bash

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

if [ -z "$GITHUB_TOKEN" ]; then
    if [ -n "$GITHUB_APP_ID" ]; then
        printf "${YELLOW}No GITHUB_TOKEN set; GitHub App mode — webhook server handles auth at runtime${RESET}\n"
        exit 0
    fi
    printf "${RED}Error: GITHUB_TOKEN environment variable is required (or set GITHUB_APP_ID for App mode)${RESET}\n"
    exit 1
fi

printf "${YELLOW}Setting up GitHub CLI authentication...${RESET}\n"

TOKEN="$GITHUB_TOKEN"
unset GITHUB_TOKEN
echo "$TOKEN" | gh auth login --with-token

printf "${YELLOW}Setting up git credential helper...${RESET}\n"
gh auth setup-git

printf "${GREEN}✓ GitHub CLI authentication completed successfully${RESET}\n"
