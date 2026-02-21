#!/bin/bash

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

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

# Verify token permissions against target repository
if [ -n "$GIT_REPO_URL" ]; then
    printf "${YELLOW}Verifying token permissions...${RESET}\n"
    REPO_PATH=$(echo "$GIT_REPO_URL" | sed 's|.*github\.com[:/]||' | sed 's|\.git$||')

    # Contents: Write (required for push/clone)
    PUSH_ACCESS=$(gh api "repos/$REPO_PATH" --jq '.permissions.push' 2>/dev/null)
    if [ "$PUSH_ACCESS" = "true" ]; then
        printf "${GREEN}✓ Contents: Read and write${RESET}\n"
    else
        printf "${RED}✗ Contents: Write access missing — cannot push commits${RESET}\n"
        printf "${RED}  Fix: Set 'Contents' to 'Read and write' in your fine-grained token.${RESET}\n"
        printf "${RED}  Org repo? Ensure the org has approved fine-grained tokens.${RESET}\n"
        exit 1
    fi

    # Pull requests: Read (required for PR operations)
    if gh api "repos/$REPO_PATH/pulls" -F per_page=1 > /dev/null 2>&1; then
        printf "${GREEN}✓ Pull requests: Read${RESET}\n"
    else
        printf "${RED}✗ Pull requests: Read access missing — PR operations will fail${RESET}\n"
        printf "${RED}  Fix: Set 'Pull requests' to 'Read and write' in your fine-grained token.${RESET}\n"
        exit 1
    fi

    # Issues: Read (required for issue plugins, non-fatal)
    if gh api "repos/$REPO_PATH/issues" -F per_page=1 > /dev/null 2>&1; then
        printf "${GREEN}✓ Issues: Read${RESET}\n"
    else
        printf "${YELLOW}⚠ Issues: Read access missing — issue plugins will not work${RESET}\n"
        printf "${YELLOW}  Fix: Set 'Issues' to 'Read and write' in your fine-grained token.${RESET}\n"
    fi
fi
