#!/bin/bash

# CodeMate Start Script
# This script sets up and runs CodeMate in a Docker container

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;36m'
NC='\033[0m' # No Color

# Default values
GIT_REPO_URL="${GIT_REPO_URL:-$(git config --get remote.origin.url 2>/dev/null || echo '')}"
BRANCH_NAME="${BRANCH_NAME:-}"
PR_NUMBER="${PR_NUMBER:-}"
PR_TITLE="${PR_TITLE:-}"
CODEMATE_IMAGE="${CODEMATE_IMAGE:-ghcr.io/boringhappy/codemate:main}"

# Function to print colored messages
print_info() {
    printf "${BLUE}ℹ ${NC}%s\n" "$1"
}

print_success() {
    printf "${GREEN}✓${NC} %s\n" "$1"
}

print_warning() {
    printf "${YELLOW}⚠${NC} %s\n" "$1"
}

print_error() {
    printf "${RED}✗${NC} %s\n" "$1"
}

# Function to ask yes/no question
ask_yes_no() {
    local prompt="$1"
    local response
    while true; do
        printf "${YELLOW}?${NC} %s (y/n): " "$prompt"
        read -r response
        case "$response" in
            [Yy]* ) return 0;;
            [Nn]* ) return 1;;
            * ) echo "Please answer y or n.";;
        esac
    done
}

# Function to create .env file
create_env_file() {
    local env_file="$1"
    cat > "$env_file" << 'EOF'
# CodeMate Environment Configuration

# Optional: Default repository URL
# GIT_REPO_URL=
EOF
    print_success "Created $env_file"
}

# Function to create settings.json
create_settings_json() {
    local settings_file="$1"
    cat > "$settings_file" << 'EOF'
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "<fill your token>",
    "ANTHROPIC_BASE_URL": "<fill your base_url>",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1"
  },
  "attribution": {
    "commit": "",
    "pr": ""
  },
  "permissions": {
    "allow": [],
    "deny": []
  },
  "theme": "dark",
  "dangerouslyDisablePermissions": true,
  "defaultMode": "bypassPermissions"
}
EOF
    print_success "Created $settings_file"
}

# Function to create .claude_in_docker.json
create_claude_json() {
    local claude_json="$1"
    echo '{}' > "$claude_json"
    print_success "Created $claude_json"
}

# Function to update start.sh script
update_script() {
    local script_path="$0"
    local temp_file="/tmp/start.sh.tmp"
    local repo_url="https://raw.githubusercontent.com/BoringHappy/CodeMate/main/start.sh"

    print_info "Updating start.sh from repository..."

    # Download the latest version
    if command -v curl &> /dev/null; then
        if ! curl -fsSL "$repo_url" -o "$temp_file"; then
            print_error "Failed to download update"
            exit 1
        fi
    elif command -v wget &> /dev/null; then
        if ! wget -q "$repo_url" -O "$temp_file"; then
            print_error "Failed to download update"
            exit 1
        fi
    else
        print_error "Neither curl nor wget is available"
        exit 1
    fi

    # Verify the downloaded file is not empty
    if [ ! -s "$temp_file" ]; then
        print_error "Downloaded file is empty"
        rm -f "$temp_file"
        exit 1
    fi

    # Replace the current script
    if ! mv "$temp_file" "$script_path"; then
        print_error "Failed to replace script"
        rm -f "$temp_file"
        exit 1
    fi

    # Make it executable
    chmod +x "$script_path"

    print_success "start.sh has been updated successfully!"
    echo ""
    print_info "Please run the script again to use the new version"
    exit 0
}

# Function to setup CodeMate files
setup_codemate_files() {
    local current_dir="$(pwd)"

    print_info "Setting up CodeMate configuration files in: $current_dir"
    echo ""

    # Create .claude_in_docker directory
    if [ ! -d "$current_dir/.claude_in_docker" ]; then
        mkdir -p "$current_dir/.claude_in_docker"
        print_success "Created .claude_in_docker directory"
    else
        print_warning ".claude_in_docker directory already exists"
    fi

    # Create .claude_in_docker.json
    if [ ! -f "$current_dir/.claude_in_docker.json" ]; then
        create_claude_json "$current_dir/.claude_in_docker.json"
    else
        print_warning ".claude_in_docker.json already exists"
    fi

    # Create settings.json
    if [ ! -f "$current_dir/settings.json" ]; then
        create_settings_json "$current_dir/settings.json"
    else
        print_warning "settings.json already exists"
    fi

    # Create .env file
    if [ ! -f "$current_dir/.env" ]; then
        create_env_file "$current_dir/.env"
    else
        print_warning ".env already exists"
    fi

    echo ""
    print_success "Setup complete!"
    echo ""
    print_info "Next steps:"
    echo "  1. Edit settings.json to add necessary config"
    echo "  2. Run: ./start.sh --repo <repo-url> --branch <branch-name>"
    echo ""
    echo "Example:"
    echo "  ./start.sh --repo https://github.com/user/repo.git --branch feature/my-feature"
    echo ""
}

# Function to check prerequisites
check_prerequisites() {
    local missing_deps=()

    # Check Docker
    if ! command -v docker &> /dev/null; then
        missing_deps+=("docker")
    fi

    # Check gh CLI
    if ! command -v gh &> /dev/null; then
        missing_deps+=("gh (GitHub CLI)")
    fi

    # Check git
    if ! command -v git &> /dev/null; then
        missing_deps+=("git")
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

    # Check if gh is authenticated (only if GITHUB_TOKEN not in .env)
    if [ -z "$GITHUB_TOKEN" ] && ! gh auth status &> /dev/null; then
        print_error "GitHub CLI is not authenticated"
        echo "Please run: gh auth login or set GITHUB_TOKEN"
        exit 1
    fi

    # Check Docker environment
    print_info "Checking Docker environment..."
    if ! docker info &> /dev/null; then
        print_error "Docker is not running or not accessible"
        echo ""
        echo "Possible solutions:"
        echo "  - Start Docker Desktop (macOS/Windows)"
        echo "  - Start Docker daemon: sudo systemctl start docker (Linux)"
        echo "  - Check Docker permissions: sudo usermod -aG docker \$USER (Linux)"
        echo "  - If using Colima: colima start"
        echo ""
        echo "After fixing, you may need to log out and back in for group changes to take effect."
        exit 1
    fi
    print_success "Docker is running"
}

# Function to run CodeMate container
run_codemate() {
    local current_dir="$(pwd)"
    local custom_mounts=("$@")

    # Source .env file if it exists
    if [ -f "$current_dir/.env" ]; then
        set -a
        source "$current_dir/.env"
        set +a
    fi

    # Get GitHub token from gh CLI if not already set in .env
    if [ -z "$GITHUB_TOKEN" ]; then
        GITHUB_TOKEN=$(gh auth token 2>/dev/null)
        if [ -z "$GITHUB_TOKEN" ]; then
            print_error "Failed to get GitHub token or gh is not authenticated"
            exit 1
        fi
    fi

    # Get git user info
    GIT_USER_NAME="${GIT_USER_NAME:-$(git config user.name)}"
    GIT_USER_EMAIL="${GIT_USER_EMAIL:-$(git config user.email)}"

    if [ -z "$GIT_USER_NAME" ] || [ -z "$GIT_USER_EMAIL" ]; then
        print_error "Git user name or email not configured"
        echo "Please set them in .env or run:"
        printf "  ${BLUE}git config --global user.name \"Your Name\"${NC}\n"
        printf "  ${BLUE}git config --global user.email \"your.email@example.com\"${NC}\n"
        exit 1
    fi

    # Determine container name
    local branch_for_name="${BRANCH_NAME:-main}"
    CONTAINER_NAME="codemate-$(echo "$branch_for_name" | sed 's/[^a-zA-Z0-9_-]/-/g')"

    # Extract repo name from git URL
    REPO_NAME=$(echo "$GIT_REPO_URL" | sed 's/\.git$//' | sed 's|.*/||')

    # Detect OS for network flag
    NETWORK_FLAG=""
    if [ "$(uname -s)" != "Darwin" ]; then
        NETWORK_FLAG="--network host"
    fi

    # Check if container is already running
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        print_success "Container $CONTAINER_NAME is running"
        print_info "Attaching zsh..."
        docker exec -it "$CONTAINER_NAME" zsh
        return
    fi

    # Create new container
    print_info "Creating new container $CONTAINER_NAME..."

    # Build volume mounts
    local volume_mounts=(
        -v "$current_dir/.claude_in_docker:/home/agent/.claude"
        -v "$current_dir/.claude_in_docker.json:/home/agent/.claude.json"
        -v "$current_dir/settings.json:/home/agent/.claude/settings.json"
    )

    # Mount skills directory if it exists in current directory
    if [ -d "$current_dir/skills" ]; then
        volume_mounts+=(-v "$current_dir/skills:/home/agent/.claude/skills")
        print_info "Mounting local skills directory"
    fi

    # Add custom volume mounts
    for mount in "${custom_mounts[@]}"; do
        if [ -n "$mount" ]; then
            volume_mounts+=(-v "$mount")
            print_info "Adding custom mount: $mount"
        fi
    done

    docker run --rm --name "$CONTAINER_NAME" \
        --pull always \
        $NETWORK_FLAG \
        -it \
        "${volume_mounts[@]}" \
        -e "GIT_REPO_URL=$GIT_REPO_URL" \
        -e "BRANCH_NAME=$BRANCH_NAME" \
        -e "PR_NUMBER=$PR_NUMBER" \
        -e "PR_TITLE=$PR_TITLE" \
        -e "GITHUB_TOKEN=$GITHUB_TOKEN" \
        -e "GIT_USER_NAME=$GIT_USER_NAME" \
        -e "GIT_USER_EMAIL=$GIT_USER_EMAIL" \
        -w "/home/agent/$REPO_NAME" \
        "$CODEMATE_IMAGE"
}

# Function to show usage
show_usage() {
    cat << EOF
CodeMate - Docker-based Claude Code environment

Usage: $0 [OPTIONS]

Options:
  --setup              Run setup to create configuration files
  --update             Update start.sh to the latest version from repository
  --branch NAME        Branch name to work on
  --pr NUMBER          Existing PR number to work on
  --pr-title TITLE     PR title (optional)
  --repo URL           Git repository URL
  --mount PATH:PATH    Custom volume mount (can be used multiple times)
  --help               Show this help message

Environment Variables:
  GIT_REPO_URL         Repository URL (defaults to current repo's remote)
  BRANCH_NAME          Branch to work on
  PR_NUMBER            Existing PR number
  PR_TITLE             PR title
  GITHUB_TOKEN         GitHub personal access token
  GIT_USER_NAME        Git commit author name
  GIT_USER_EMAIL       Git commit author email

Examples:
  # First time setup
  $0 --setup

  # Update start.sh to latest version
  $0 --update

  # Run with custom repo
  $0 --repo https://github.com/user/repo.git --branch feature/xyz

  # Run with branch name
  $0 --branch feature/my-feature

  # Run with existing PR
  $0 --pr 123

  # Run with custom volume mounts
  $0 --branch feature/xyz --mount /local/path:/container/path
  $0 --branch feature/xyz --mount ~/data:/data --mount ~/config:/config

EOF
}

# Main script logic
main() {
    local force_setup=false
    local current_dir="$(pwd)"
    local custom_mounts=()

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --setup)
                force_setup=true
                shift
                ;;
            --update)
                update_script
                ;;
            --branch)
                BRANCH_NAME="$2"
                shift 2
                ;;
            --pr)
                PR_NUMBER="$2"
                shift 2
                ;;
            --pr-title)
                PR_TITLE="$2"
                shift 2
                ;;
            --repo)
                GIT_REPO_URL="$2"
                shift 2
                ;;
            --mount)
                custom_mounts+=("$2")
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

    # Check if configuration files exist
    local needs_setup=false
    if [ ! -d "$current_dir/.claude_in_docker" ] || \
       [ ! -f "$current_dir/.claude_in_docker.json" ] || \
       [ ! -f "$current_dir/settings.json" ] || \
       [ ! -f "$current_dir/.env" ]; then
        needs_setup=true
    fi

    # If setup is needed or forced, ask user
    if [ "$force_setup" = true ] || [ "$needs_setup" = true ]; then
        echo ""
        print_info "CodeMate Setup"
        echo ""

        if [ "$needs_setup" = true ]; then
            print_warning "Configuration files not found in current directory"
            echo "The following will be created:"
            echo "  1. .claude_in_docker/ directory"
            echo "  2. .claude_in_docker.json file"
            echo "  3. settings.json file"
            echo "  4. .env file"
            echo ""
        fi

        if ask_yes_no "Create CodeMate configuration files in $(pwd)?"; then
            setup_codemate_files
            exit 0
        else
            print_info "Setup cancelled"
            exit 0
        fi
    fi

    # Check prerequisites
    check_prerequisites

    # Validate required parameters
    if [ -z "$BRANCH_NAME" ] && [ -z "$PR_NUMBER" ]; then
        print_error "Either --branch or --pr must be specified"
        echo ""
        show_usage
        exit 1
    fi

    if [ -z "$GIT_REPO_URL" ]; then
        print_error "GIT_REPO_URL not set"
        echo ""
        echo "The repository URL can be provided in three ways (in priority order):"
        echo "  1. Use --repo option: ./start.sh --repo https://github.com/user/repo.git --branch xyz"
        echo "  2. Set GIT_REPO_URL in .env file"
        echo "  3. Run from a git repository directory (auto-detects remote origin)"
        echo ""
        exit 1
    fi

    # Run CodeMate
    run_codemate "${custom_mounts[@]}"
}

# Run main function
main "$@"

