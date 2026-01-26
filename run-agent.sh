#!/bin/bash

# Run Agent Script
# This script runs the Python agent with automatic configuration detection

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;36m'
NC='\033[0m' # No Color

# Default values
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
GITHUB_REPOSITORY="${GITHUB_REPOSITORY:-}"
PR_NUMBER="${PR_NUMBER:-}"
CHECK_INTERVAL="${CHECK_INTERVAL:-60}"
INITIAL_QUERY=""
SYSTEM_PROMPT=""

# Function to print colored messages
print_info() {
    printf "${BLUE}ℹ ${NC}%s\n" "$1"
}

print_success() {
    printf "${GREEN}✓${NC} %s\n" "$1"
}

print_error() {
    printf "${RED}✗${NC} %s\n" "$1"
}

# Function to check prerequisites
check_prerequisites() {
    local missing_deps=()

    # Check gh CLI
    if ! command -v gh &> /dev/null; then
        missing_deps+=("gh (GitHub CLI)")
    fi

    # Check git
    if ! command -v git &> /dev/null; then
        missing_deps+=("git")
    fi

    # Check uv
    if ! command -v uv &> /dev/null; then
        missing_deps+=("uv")
    fi

    if [ ${#missing_deps[@]} -gt 0 ]; then
        print_error "Missing required dependencies:"
        for dep in "${missing_deps[@]}"; do
            echo "  - $dep"
        done
        echo ""
        echo "Please install the missing dependencies and try again."
        exit 1
    fi
}

# Function to get GitHub token
get_github_token() {
    if [ -n "$GITHUB_TOKEN" ]; then
        print_success "Using GITHUB_TOKEN from environment"
        return
    fi

    # Try to get token from gh CLI
    if command -v gh &> /dev/null; then
        GITHUB_TOKEN=$(gh auth token 2>/dev/null)
        if [ -n "$GITHUB_TOKEN" ]; then
            print_success "Got GitHub token from gh CLI"
            return
        fi
    fi

    print_error "GitHub token not found"
    echo "Please either:"
    echo "  1. Run: gh auth login"
    echo "  2. Set GITHUB_TOKEN environment variable"
    exit 1
}

# Function to get repository
get_repository() {
    if [ -n "$GITHUB_REPOSITORY" ]; then
        print_success "Using repository from environment: $GITHUB_REPOSITORY"
        return
    fi

    # Try to get from git remote
    if command -v git &> /dev/null && git rev-parse --git-dir &> /dev/null; then
        local remote_url=$(git config --get remote.origin.url 2>/dev/null || echo "")
        if [ -n "$remote_url" ]; then
            # Extract owner/repo from URL
            # Handle both HTTPS and SSH URLs
            GITHUB_REPOSITORY=$(echo "$remote_url" | sed -E 's|^(https://github.com/\|git@github.com:)||' | sed 's|\.git$||')
            print_success "Detected repository from git remote: $GITHUB_REPOSITORY"
            return
        fi
    fi

    print_error "Repository not found"
    echo "Please either:"
    echo "  1. Run from a git repository directory"
    echo "  2. Set GITHUB_REPOSITORY environment variable (format: owner/repo)"
    echo "  3. Use --repo option"
    exit 1
}

# Function to get PR number
get_pr_number() {
    if [ -n "$PR_NUMBER" ]; then
        print_success "Using PR number from environment: $PR_NUMBER"
        return
    fi

    # Try to get from current branch
    if command -v gh &> /dev/null && git rev-parse --git-dir &> /dev/null; then
        PR_NUMBER=$(gh pr view --json number -q .number 2>/dev/null || echo "")
        if [ -n "$PR_NUMBER" ]; then
            print_success "Detected PR number from current branch: $PR_NUMBER"
            return
        fi
    fi

    print_error "PR number not found"
    echo "Please either:"
    echo "  1. Run from a branch with an open PR"
    echo "  2. Set PR_NUMBER environment variable"
    echo "  3. Use --pr option"
    exit 1
}

# Function to show usage
show_usage() {
    cat << EOF
Run Agent - Python agent for automated PR comment handling

Usage: $0 [OPTIONS]

Options:
  --repo OWNER/REPO    GitHub repository (format: owner/repo)
  --pr NUMBER          PR number to monitor
  --interval SECONDS   Check interval in seconds (default: 60)
  --query TEXT         Initial query to send before monitoring loop
  --system-prompt PATH Path to custom system prompt file
  --help               Show this help message

Environment Variables:
  GITHUB_TOKEN         GitHub personal access token (auto-detected from gh CLI)
  GITHUB_REPOSITORY    Repository in owner/repo format (auto-detected from git remote)
  PR_NUMBER            PR number (auto-detected from current branch)
  CHECK_INTERVAL       Check interval in seconds (default: 60)
  ANTHROPIC_API_KEY    Anthropic API key (required)

Examples:
  # Run with auto-detection (from current git repo and branch)
  $0

  # Run with specific PR
  $0 --pr 123

  # Run with custom repository and PR
  $0 --repo owner/repo --pr 123

  # Run with initial query
  $0 --pr 123 --query "Please review the code and suggest improvements"

  # Run with custom check interval
  $0 --pr 123 --interval 30

  # Run with custom system prompt
  $0 --pr 123 --system-prompt /path/to/prompt.txt

EOF
}

# Main script logic
main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --repo)
                GITHUB_REPOSITORY="$2"
                shift 2
                ;;
            --pr)
                PR_NUMBER="$2"
                shift 2
                ;;
            --interval)
                CHECK_INTERVAL="$2"
                shift 2
                ;;
            --query)
                INITIAL_QUERY="$2"
                shift 2
                ;;
            --system-prompt)
                SYSTEM_PROMPT="$2"
                shift 2
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    echo ""
    print_info "Python Agent for Automated PR Comment Handling"
    echo ""

    # Check prerequisites
    check_prerequisites

    # Get configuration
    get_github_token
    get_repository
    get_pr_number

    # Check for ANTHROPIC_API_KEY
    if [ -z "$ANTHROPIC_API_KEY" ]; then
        print_error "ANTHROPIC_API_KEY not set"
        echo "Please set the ANTHROPIC_API_KEY environment variable"
        exit 1
    fi

    print_success "ANTHROPIC_API_KEY is set"

    echo ""
    print_info "Configuration:"
    echo "  Repository: $GITHUB_REPOSITORY"
    echo "  PR Number: $PR_NUMBER"
    echo "  Check Interval: ${CHECK_INTERVAL}s"
    if [ -n "$INITIAL_QUERY" ]; then
        echo "  Initial Query: $INITIAL_QUERY"
    fi
    if [ -n "$SYSTEM_PROMPT" ]; then
        echo "  System Prompt: $SYSTEM_PROMPT"
    fi
    echo ""

    # Build command arguments
    local cmd_args=(
        --github-token "$GITHUB_TOKEN"
        --repo "$GITHUB_REPOSITORY"
        --pr "$PR_NUMBER"
        --interval "$CHECK_INTERVAL"
    )

    if [ -n "$INITIAL_QUERY" ]; then
        cmd_args+=(--query "$INITIAL_QUERY")
    fi

    if [ -n "$SYSTEM_PROMPT" ]; then
        cmd_args+=(--system-prompt "$SYSTEM_PROMPT")
    fi

    # Run the agent
    print_info "Starting agent..."
    echo ""

    export ANTHROPIC_API_KEY
    export GITHUB_TOKEN
    export GITHUB_REPOSITORY
    export PR_NUMBER

    uv run agent "${cmd_args[@]}"
}

# Run main function
main "$@"
