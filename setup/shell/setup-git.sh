#!/bin/bash

if [ -z "$GIT_USER_NAME" ]; then
    echo "Error: GIT_USER_NAME environment variable is required"
    exit 1
fi

if [ -z "$GIT_USER_EMAIL" ]; then
    echo "Error: GIT_USER_EMAIL environment variable is required"
    exit 1
fi

echo "Setting up git config..."

echo "Setting git user.name: $GIT_USER_NAME"
git config --global user.name "$GIT_USER_NAME"

echo "Setting git user.email: $GIT_USER_EMAIL"
git config --global user.email "$GIT_USER_EMAIL"

echo "Git config setup completed successfully"
