#!/bin/bash

if [ -z "$GITHUB_TOKEN" ]; then
    echo "Error: GITHUB_TOKEN environment variable is required"
    exit 1
fi

echo "Setting up GitHub CLI authentication..."

TOKEN="$GITHUB_TOKEN"
unset GITHUB_TOKEN
echo "$TOKEN" | gh auth login --with-token

echo "GitHub CLI authentication completed successfully"
