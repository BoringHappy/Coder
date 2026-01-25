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

