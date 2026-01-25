#!/bin/bash
# Common shell utilities for setup scripts

# Color codes
export CYAN='\033[1;36m'
export GREEN='\033[1;32m'
export YELLOW='\033[1;33m'
export RED='\033[1;31m'
export BLUE='\033[1;34m'
export RESET='\033[0m'

# Function to run a setup script with formatted output
# Usage: run_setup_script "script-name.sh" "Description"
run_setup_script() {
    local script_name="$1"
    local description="${2:-Running $script_name...}"

    printf "\n${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"
    printf "${CYAN}${description}${RESET}\n"
    printf "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}\n"

    # Determine how to run the script based on extension
    if [[ "$script_name" == *.py ]]; then
        python3 "$script_name"
    else
        bash "$script_name"
    fi
}

# Function to add a Claude plugin marketplace
# Usage: add_marketplace "index/total" "marketplace-name" "marketplace-path"
add_marketplace() {
    local progress="$1"
    local name="$2"
    local path="$3"

    printf "  [${progress}] Adding ${name} marketplace...\n"
    if claude plugin marketplace add "$path" 2>&1; then
        printf "  ${GREEN}✓ ${name} marketplace added${RESET}\n"
        return 0
    else
        printf "  ${YELLOW}⚠ Failed to add ${name} marketplace${RESET}\n"
        return 1
    fi
}

# Function to install and verify a Claude plugin
# Usage: install_and_verify_plugin "index/total" "plugin-name" "skill1, skill2, skill3"
install_and_verify_plugin() {
    local progress="$1"
    local plugin="$2"
    local skills="$3"

    printf "  [${progress}] Installing ${plugin}...\n"
    if claude plugin install "$plugin" 2>&1; then
        printf "  ${GREEN}✓ ${plugin} installed${RESET}\n"

        # Verify installation
        local installed_list=$(claude plugin list 2>/dev/null || echo "")
        if echo "$installed_list" | grep -q "$plugin"; then
            if [ -n "$skills" ]; then
                printf "    Skills: ${skills}\n"
            fi
            return 0
        else
            printf "  ${YELLOW}⚠ Plugin installed but not found in list${RESET}\n"
            return 1
        fi
    else
        printf "  ${RED}✗ ${plugin} installation failed${RESET}\n"
        return 1
    fi
}



