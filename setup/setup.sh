#!/bin/bash
set -e

SETUP_DIR="/usr/local/bin/setup"

echo "Running setup-git.sh..."
bash "$SETUP_DIR/shell/setup-git.sh"

echo "Running setup-gh.sh..."
bash "$SETUP_DIR/shell/setup-gh.sh"

echo "Running setup-repo.py..."
python3 "$SETUP_DIR/python/setup-repo.py"

echo "All setup scripts completed successfully"
exec "$@"
