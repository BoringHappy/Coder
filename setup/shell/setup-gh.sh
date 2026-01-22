#!/bin/bash

if [ -z "$GH_TOKEN" ]; then
    echo "Error: GH_TOKEN environment variable is required"
    exit 1
fi

echo "Setting up GitHub CLI authentication..."

echo "$GH_TOKEN" | gh auth login --with-token

echo "GitHub CLI authentication completed successfully"
