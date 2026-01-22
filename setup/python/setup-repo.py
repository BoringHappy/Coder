#!/usr/bin/env python3
import os
import subprocess
import sys


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
    pr_title = os.getenv("PR_TITLE", "")

    branch_name = os.getenv("BRANCH_NAME", "")
    pr_number = os.getenv("PR_NUMBER", "")

    if not branch_name and not pr_number:
        print("Skipping git PR setup: GIT_REPO_URL or BRANCH_NAME/PR_NUMBER not set")
        sys.exit(0)

    print("Setting up git repository...")

    # Extract repo name from git URL
    repo_name = get_repo_name_from_url(git_repo_url)
    workspace = f"/home/agent/{repo_name}"

    # Ensure agent user has permission to the workspace directory
    run(f"sudo chown -R agent:agent {workspace}", check=False)

    if not os.path.exists(f"{workspace}/.git"):
        print(f"Cloning repository: {git_repo_url}")
        os.chdir("/home/agent")
        run(f"git clone {git_repo_url} {repo_name}")
        os.chdir(workspace)
    else:
        print("Using existing repository")
        os.chdir(workspace)
        run("git fetch origin")

    if pr_number:
        print(f"Getting branch name from PR #{pr_number}")
        run(f"gh pr checkout {pr_number}")
        result = run(f"gh pr view {pr_number} --json url -q .url")
        pr_url = result.stdout.strip()
    else:
        result = run(
            f"git show-ref --verify --quiet refs/heads/{branch_name}", check=False
        )
        if result.returncode == 0:
            print(f"Branch {branch_name} exists locally, switching to it")
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
                print(f"Branch {branch_name} exists remotely, checking it out")
                run(f"git checkout -b {branch_name} origin/{branch_name}")
                result = run(
                    f"gh pr list --head {branch_name} --json url -q '.[0].url'",
                    check=False,
                )
                pr_url = result.stdout.strip() if result.returncode == 0 else ""
            else:
                print(f"Creating new branch: {branch_name}")
                run(f"git checkout -b {branch_name}")
                run(f"git commit --allow-empty -m 'Initial commit for {branch_name}'")
                run(f"git push -u origin {branch_name}")

                print("Creating pull request")
                pr_body = get_pr_template(workspace)
                title = pr_title if pr_title else branch_name.replace("-", " ")
                result = run(f"gh pr create --title '{title}' --body '{pr_body}'")
                pr_url = result.stdout.strip()

    print("Git setup completed successfully")
    if pr_url:
        print(f"PR URL: {pr_url}")


if __name__ == "__main__":
    main()
