#!/bin/bash

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

SETTINGS_FILE="$HOME/.claude/settings.json"

printf "${YELLOW}Setting up CCometixLine status line...${RESET}\n"

# Create settings.json with empty object if it doesn't exist
if [ ! -f "$SETTINGS_FILE" ]; then
    mkdir -p "$(dirname "$SETTINGS_FILE")"
    echo '{}' > "$SETTINGS_FILE"
fi

# Only add statusLine if not already present
if python3 -c "import json,sys; d=json.load(open('$SETTINGS_FILE')); sys.exit(0 if 'statusLine' in d else 1)" 2>/dev/null; then
    printf "  ${GREEN}✓ statusLine already configured, skipping${RESET}\n"
else
    printf "  Adding statusLine to ${BLUE}${SETTINGS_FILE}${RESET}...\n"
    python3 - <<'EOF'
import json, os

settings_file = os.path.expanduser("~/.claude/settings.json")
with open(settings_file, "r") as f:
    data = json.load(f)

data["statusLine"] = {
    "type": "command",
    "command": "~/.claude/ccline/ccline",
    "padding": 0
}

with open(settings_file, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
EOF
    printf "  ${GREEN}✓ statusLine configured${RESET}\n"
fi

printf "${GREEN}✓ CCometixLine setup completed successfully${RESET}\n"
