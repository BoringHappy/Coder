#!/bin/bash
set -e

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

if [ -z "$CLOUDFLARE_TUNNEL_TOKEN" ]; then
    printf "${YELLOW}CLOUDFLARE_TUNNEL_TOKEN not set, skipping Cloudflare Tunnel${RESET}\n"
    exit 0
fi

# Check if cloudflared is installed
if ! command -v cloudflared &>/dev/null; then
    printf "${RED}Error: cloudflared is not installed${RESET}\n"
    printf "${YELLOW}Install it or run without Cloudflare Tunnel${RESET}\n"
    exit 1
fi

printf "${YELLOW}Starting Cloudflare Tunnel...${RESET}\n"

# Start cloudflared tunnel in the background
cloudflared tunnel run --token "$CLOUDFLARE_TUNNEL_TOKEN" &
CLOUDFLARED_PID=$!

# Write PID to file for later management
echo "$CLOUDFLARED_PID" > /tmp/.cloudflared_pid

# Verify the process started
sleep 2
if kill -0 "$CLOUDFLARED_PID" 2>/dev/null; then
    printf "${GREEN}✓ Cloudflare Tunnel started (PID: $CLOUDFLARED_PID)${RESET}\n"
else
    printf "${RED}Error: Cloudflare Tunnel failed to start${RESET}\n"
    exit 1
fi
