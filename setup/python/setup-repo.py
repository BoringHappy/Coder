#!/usr/bin/env python3
import os
import subprocess
import sys


# Color codes
YELLOW = '\033[1;33m'
GREEN = '\033[1;32m'
RED = '\033[1;31m'
BLUE = '\033[1;34m'
MAGENTA = '\033[1;35m'
RESET = '\033[0m'


def run(cmd, check=True):
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    if check and result.returncode != 0:
        raise RuntimeError(f"Command failed: {cmd}\n{result.stderr}")
    return result


def get_repo_name_from_url(git_url):
    """Extract repository name from git URL."""
    # Remove .git suffix if present
    if git_url.endswith(".git"):
        git_url = git_url[:-4]

    # Extract the last part of the path
    # Works for both https://github.com/user/repo and git@github.com:user/repo
    repo_name = git_url.rstrip("/").split("/")[-1]
    return repo_name


def get_pr_template(workspace):
    """Read PR template from .github/PULL_REQUEST_TEMPLATE.md if it exists."""
    template_path = f"{workspace}/.github/PULL_REQUEST_TEMPLATE.md"
    if os.path.exists(template_path):
        with open(template_path, "r") as f:
            return f.read()
    return """## Summary
<N/A>

## Test plan
- [ ] Review and test changes
"""


def main():
    git_repo_url = os.environ["GIT_REPO_URL"]
    upstream_repo_url = os.getenv("UPSTREAM_REPO_URL", "")
    pr_title = os.getenv("PR_TITLE", "")

    branch_name = os.getenv("BRANCH_NAME", "")
    pr_number = os.getenv("PR_NUMBER", "")

    if not branch_name and not pr_number:
        print(f"{RED}Skipping git PR setup: GIT_REPO_URL or BRANCH_NAME/PR_NUMBER not set{RESET}")
        sys.exit(0)

    # Validate branch name is not main/master or default branch
    if branch_name:
        forbidden_branches = ["main", "master"]
        if branch_name.lower() in forbidden_branches:
            print(f"{RED}Error: Cannot use '{branch_name}' as branch name.{RESET}")
            print(f"{RED}Branch name cannot be 'main' or 'master'.{RESET}")
            sys.exit(1)

    print(f"{YELLOW}Setting up git repository...{RESET}")

    # Extract repo name from git URL
    repo_name = get_repo_name_from_url(git_repo_url)
    workspace = f"/home/agent/{repo_name}"

    # Ensure agent user has permission to the workspace directory
    run(f"sudo chown -R agent:agent {workspace}", check=False)

    if not os.path.exists(f"{workspace}/.git"):
        print(f"  Cloning repository: {BLUE}{git_repo_url}{RESET}")
        os.chdir("/home/agent")
        run(f"git clone {git_repo_url} {repo_name}")
        os.chdir(workspace)
    else:
        print(f"  Using existing repository")
        os.chdir(workspace)
        run("git fetch origin")

    # Add upstream remote if fork workflow
    if upstream_repo_url:
        print(f"  {MAGENTA}Fork workflow detected{RESET}")
        print(f"  Adding upstream remote: {BLUE}{upstream_repo_url}{RESET}")
        run(f"git remote add upstream {upstream_repo_url}", check=False)
        run("git fetch upstream", check=False)

    # Additional validation: check against repository's default branch
    if branch_name:
        result = run("gh repo view --json defaultBranchRef -q .defaultBranchRef.name", check=False)
        if result.returncode == 0:
            default_branch = result.stdout.strip()
            if default_branch and branch_name.lower() == default_branch.lower():
                print(f"{RED}Error: Cannot use '{branch_name}' as branch name.{RESET}")
                print(f"{RED}Branch name cannot be the repository's default branch '{default_branch}'.{RESET}")
                sys.exit(1)

    if pr_number:
        print(f"  Getting branch name from PR {MAGENTA}#{pr_number}{RESET}")
        run(f"gh pr checkout {pr_number}")
        result = run(f"gh pr view {pr_number} --json url -q .url")
        pr_url = result.stdout.strip()
    else:
        result = run(
            f"git show-ref --verify --quiet refs/heads/{branch_name}", check=False
        )
        if result.returncode == 0:
            print(f"  Branch {BLUE}{branch_name}{RESET} exists locally, switching to it")
            run(f"git checkout {branch_name}")
            run(f"git pull origin {branch_name}", check=False)
            result = run(
                f"gh pr list --head {branch_name} --json url -q '.[0].url'", check=False
            )
            pr_url = result.stdout.strip() if result.returncode == 0 else ""
        else:
            result = run(
                f"git show-ref --verify --quiet refs/remotes/origin/{branch_name}",
                check=False,
            )
            if result.returncode == 0:
                print(f"  Branch {BLUE}{branch_name}{RESET} exists remotely, checking it out")
                run(f"git checkout -b {branch_name} origin/{branch_name}")
                result = run(
                    f"gh pr list --head {branch_name} --json url -q '.[0].url'",
                    check=False,
                )
                pr_url = result.stdout.strip() if result.returncode == 0 else ""
            else:
                print(f"  Creating new branch: {BLUE}{branch_name}{RESET}")
                run(f"git checkout -b {branch_name}")

                # Check if fork workflow (upstream exists)
                if upstream_repo_url:
                    # Fork workflow: Don't create PR yet, let user create it when ready
                    print(f"  {YELLOW}Branch created locally. Use /pr:create when ready to submit PR.{RESET}")
                    pr_url = ""
                else:
                    # Standard workflow: Create PR immediately
                    run(f"git commit --allow-empty -m 'Initial commit for {branch_name}'")
                    run(f"git push -u origin {branch_name}")

                    print(f"  {MAGENTA}Creating pull request{RESET}")
                    pr_body = get_pr_template(workspace)
                    title = pr_title if pr_title else branch_name.replace("-", " ")
                    result = run(f"gh pr create --title '{title}' --body '{pr_body}'")
                    pr_url = result.stdout.strip()

    print(f"{GREEN}✓ Git setup completed successfully{RESET}")
    if pr_url:
        print(f"  PR URL: {BLUE}{pr_url}{RESET}")

    # Write PR status to file for skills to check
    pr_status_file = "/tmp/.pr_status"
    if pr_url:
        with open(pr_status_file, "w") as f:
            f.write(pr_url)
        print(f"  {GREEN}✓ PR status saved to {pr_status_file}{RESET}")
    else:
        # No PR exists, ensure file is empty
        with open(pr_status_file, "w") as f:
            f.write("")
        print(f"  {YELLOW}No PR exists yet. Create one when ready using /pr:create{RESET}")


if __name__ == "__main__":
    main()
