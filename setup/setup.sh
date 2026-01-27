#!/bin/bash
set -e

SETUP_DIR="/usr/local/bin/setup"

# Source common utilities
source "$SETUP_DIR/shell/common.sh"

# Export environment variables for cron jobs
# Cron runs in a minimal environment and doesn't inherit Docker runtime env vars
ENV_FILE="/home/agent/.cron-env"
printf "${GREEN}Exporting environment variables for cron...${RESET}\n"
env | grep -E '^(GIT_REPO_URL|GITHUB_TOKEN|CLAUDE_SESSION|STATE_FILE|REPO_DIR|HOME|PATH|LANG|LC_ALL)=' > "$ENV_FILE" 2>/dev/null || true
chmod 600 "$ENV_FILE"

# Start cron daemon for PR monitoring
printf "${GREEN}Starting cron daemon...${RESET}\n"
sudo service cron start || sudo cron || true

run_setup_script "$SETUP_DIR/shell/setup-git.sh" "Running setup-git.sh..."
run_setup_script "$SETUP_DIR/shell/setup-gh.sh" "Running setup-gh.sh..."
run_setup_script "$SETUP_DIR/shell/setup-plugins.sh" "Running setup-plugins.sh..."
run_setup_script "$SETUP_DIR/python/setup-repo.py" "Running setup-repo.py..."

printf "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
printf "${GREEN}✓ All setup scripts completed successfully${RESET}\n"
printf "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
exec "$@"

