#!/bin/bash
set -e

SETUP_DIR="/usr/local/bin/setup"

# Source common utilities
source "$SETUP_DIR/shell/common.sh"

run_setup_script "$SETUP_DIR/shell/setup-git.sh" "Running setup-git.sh..."
run_setup_script "$SETUP_DIR/shell/setup-gh.sh" "Running setup-gh.sh..."
run_setup_script "$SETUP_DIR/shell/setup-plugins.sh" "Running setup-plugins.sh..."

# Cloudflare Tunnel is optional — only start if token is provided
if [ -n "$CLOUDFLARE_TUNNEL_TOKEN" ]; then
    run_setup_script "$SETUP_DIR/shell/setup-cloudflared.sh" "Running setup-cloudflared.sh..."
else
    printf "\n${YELLOW}Skipping Cloudflare Tunnel (CLOUDFLARE_TUNNEL_TOKEN not set)${RESET}\n"
    printf "${YELLOW}Server will listen on port ${WEBHOOK_PORT:-8080} — use port forwarding or a reverse proxy${RESET}\n"
fi

printf "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
printf "${GREEN}✓ All setup scripts completed successfully${RESET}\n"
printf "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
exec "$@"
