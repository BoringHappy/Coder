#!/bin/bash

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

CCLINE_REPO="https://github.com/Haleclipse/CCometixLine"
INSTALL_DIR="$HOME/.ccline"

printf "${YELLOW}Setting up CCometixLine...${RESET}\n"

if [ -d "$INSTALL_DIR" ]; then
    printf "  Updating existing CCometixLine installation...\n"
    git -C "$INSTALL_DIR" pull --ff-only 2>&1
else
    printf "  Cloning CCometixLine from ${BLUE}${CCLINE_REPO}${RESET}...\n"
    git clone "$CCLINE_REPO" "$INSTALL_DIR" 2>&1
fi

if [ -f "$INSTALL_DIR/install.sh" ]; then
    printf "  Running install.sh...\n"
    bash "$INSTALL_DIR/install.sh" 2>&1
elif [ -f "$INSTALL_DIR/setup.sh" ]; then
    printf "  Running setup.sh...\n"
    bash "$INSTALL_DIR/setup.sh" 2>&1
fi

printf "${GREEN}✓ CCometixLine setup completed successfully${RESET}\n"
