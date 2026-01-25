#!/bin/bash
set -e

SETUP_DIR="/usr/local/bin/setup"

# Color codes
CYAN='\033[1;36m'
GREEN='\033[1;32m'
RESET='\033[0m'

printf "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
printf "${CYAN}Running setup-git.sh...${RESET}\n"
printf "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
bash "$SETUP_DIR/shell/setup-git.sh"

printf "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
printf "${CYAN}Running setup-gh.sh...${RESET}\n"
printf "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
bash "$SETUP_DIR/shell/setup-gh.sh"

printf "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
printf "${CYAN}Setting up plugin marketplace...${RESET}\n"
printf "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"

# Add the local marketplace and install plugins
if [ ! -f /home/agent/.claude/settings.json ] || ! grep -q "codemate" /home/agent/.claude/settings.json 2>/dev/null; then
    printf "${CYAN}Adding CodeMate marketplace...${RESET}\n"
    mkdir -p /home/agent/.claude

    # Create or update settings.json with marketplace configuration
    cat > /home/agent/.claude/settings.json <<'EOF'
{
  "extraKnownMarketplaces": {
    "codemate": {
      "source": "/usr/local/bin/setup/marketplace"
    }
  },
  "enabledPlugins": {
    "pr@codemate": true,
    "external@codemate": true
  }
}
EOF
    printf "${GREEN}✓ CodeMate marketplace configured${RESET}\n"
else
    printf "${GREEN}✓ CodeMate marketplace already configured${RESET}\n"
fi

printf "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
printf "${CYAN}Running setup-repo.py...${RESET}\n"
printf "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
python3 "$SETUP_DIR/python/setup-repo.py"

printf "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
printf "${GREEN}✓ All setup scripts completed successfully${RESET}\n"
printf "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
exec "$@"
