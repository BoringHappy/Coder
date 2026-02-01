#!/bin/bash
set -e

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

printf "${CYAN}Setting up Claude Code plugins...${RESET}\n"

# Create tmp directory in .claude to avoid cross-device link errors
printf "  Creating temp directory at /home/agent/.claude/tmp\n"
mkdir -p /home/agent/.claude/tmp
export TMPDIR=/home/agent/.claude/tmp

# Add default marketplaces (functions check if already added)
printf "\n${CYAN}Adding default marketplaces:${RESET}\n"
add_marketplace "1/2" "vercel-labs/agent-browser" "vercel-labs/agent-browser"
add_marketplace "2/2" "codemate" "BoringHappy/CodeMate"

# Add custom marketplaces from environment variable
if [ -n "$CUSTOM_MARKETPLACES" ]; then
    printf "\n${CYAN}Adding custom marketplaces:${RESET}\n"
    IFS=',' read -ra MARKETPLACE_ARRAY <<< "$CUSTOM_MARKETPLACES"
    marketplace_count=${#MARKETPLACE_ARRAY[@]}
    marketplace_index=1
    for marketplace in "${MARKETPLACE_ARRAY[@]}"; do
        # Trim whitespace
        marketplace=$(echo "$marketplace" | xargs)
        if [ -n "$marketplace" ]; then
            # Extract marketplace name from path (e.g., "username/repo" -> "repo")
            marketplace_name=$(echo "$marketplace" | sed 's|.*/||')
            add_marketplace "$marketplace_index/$marketplace_count" "$marketplace_name" "$marketplace"
            marketplace_index=$((marketplace_index + 1))
        fi
    done
fi

# Install default plugins (functions check if already installed)
printf "\n${CYAN}Installing default plugins:${RESET}\n"
install_and_verify_plugin "1/3" "agent-browser@agent-browser" "/agent-browser:agent-browser"
install_and_verify_plugin "2/3" "git@codemate" "/git:commit"
install_and_verify_plugin "3/3" "pr@codemate" "/pr:get-details, /pr:fix-comments, /pr:update"

# Install custom plugins from environment variable
if [ -n "$CUSTOM_PLUGINS" ]; then
    printf "\n${CYAN}Installing custom plugins:${RESET}\n"
    IFS=',' read -ra PLUGIN_ARRAY <<< "$CUSTOM_PLUGINS"
    plugin_count=${#PLUGIN_ARRAY[@]}
    plugin_index=1
    for plugin in "${PLUGIN_ARRAY[@]}"; do
        # Trim whitespace
        plugin=$(echo "$plugin" | xargs)
        if [ -n "$plugin" ]; then
            install_and_verify_plugin "$plugin_index/$plugin_count" "$plugin" ""
            plugin_index=$((plugin_index + 1))
        fi
    done
fi

printf "\n${GREEN}✓ Plugin setup complete${RESET}\n"
