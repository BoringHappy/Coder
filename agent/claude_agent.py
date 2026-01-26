#!/usr/bin/env python3
"""
Claude Code Agent - Python-controlled loop for automated PR comment handling.

This agent monitors GitHub PR comments and uses Claude Code to automatically
address review feedback using a continuous conversation session.
"""

import asyncio
import os
import sys
from datetime import datetime
from pathlib import Path

from claude_agent_sdk import (
    AssistantMessage,
    ClaudeAgentOptions,
    ClaudeSDKClient,
    TextBlock,
)
from dotenv import load_dotenv
from github import Github
from loguru import logger
from tenacity import retry, stop_after_attempt, wait_exponential

# Load environment variables
load_dotenv()


class GitHubPRMonitor:
    """Monitors GitHub PR for new comments using PyGithub."""

    def __init__(self, github_token: str, repo_name: str, pr_number: int):
        self.github = Github(github_token)
        self.repo = self.github.get_repo(repo_name)
        self.pr = self.repo.get_pull(pr_number)
        self.pr_number = pr_number
        self.last_check_time = datetime.now()
        self.processed_comment_ids = set()

        logger.info(f"Monitoring PR #{pr_number} in {repo_name}")

    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=4, max=10),
        reraise=True,
    )
    def has_new_comments(self) -> bool:
        """Check if there are new comments since last check."""
        # Get review comments
        review_comments = list(self.pr.get_review_comments())
        issue_comments = list(self.pr.get_issue_comments())

        all_comments = review_comments + issue_comments

        for comment in all_comments:
            if (
                comment.id not in self.processed_comment_ids
                and comment.created_at.replace(tzinfo=None) > self.last_check_time
            ):
                logger.info(f"New comment detected: {comment.id}")
                # Update last_check_time before returning to avoid re-processing
                self.last_check_time = datetime.now()
                return True

        return False

    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=4, max=10),
        reraise=True,
    )
    def mark_comments_processed(self):
        """Mark all current comments as processed."""
        review_comments = list(self.pr.get_review_comments())
        issue_comments = list(self.pr.get_issue_comments())

        for comment in review_comments + issue_comments:
            self.processed_comment_ids.add(comment.id)


class ClaudeCodeAgent:
    """Main agent that uses Claude Code to fix PR comments with continuous conversation."""

    def __init__(
        self,
        github_token: str,
        repo_name: str,
        pr_number: int,
        check_interval: int = 60,
        system_prompt_path: str | None = None,
        initial_query: str | None = None,
    ):
        self.pr_monitor = GitHubPRMonitor(github_token, repo_name, pr_number)
        self.check_interval = check_interval
        self.initial_query = initial_query

        # Load system prompt
        system_prompt = self._load_system_prompt(system_prompt_path)

        # Configure Claude Agent SDK options
        self.options = ClaudeAgentOptions(
            system_prompt={
                "type": "preset",
                "preset": "claude_code",
                "append": system_prompt,
            },
            permission_mode="bypassPermissions",
            setting_sources=["user", "project", "local"],  # Load all settings
        )

        logger.info("ClaudeCodeAgent initialized")

    def _load_system_prompt(self, path: str | None) -> str:
        """Load additional system prompt from file."""
        if path and Path(path).exists():
            return Path(path).read_text()

        # Default additional instructions
        return """
When you detect new PR comments, use the /pr:fix-comments skill to address them.
This skill will automatically read all comments, make necessary changes, and reply to reviewers.
"""

    async def _process_response(self, client: ClaudeSDKClient) -> None:
        """Process response from Claude SDK client."""
        async for message in client.receive_response():
            if isinstance(message, AssistantMessage):
                for block in message.content:
                    if isinstance(block, TextBlock):
                        logger.debug(f"Claude: {block.text[:100]}...")
            else:
                logger.debug(f"Received message: {type(message).__name__} - {message}")

    async def run(self) -> None:
        """Main loop - continuously monitor for new comments and handle them."""
        logger.info(f"Starting agent loop (checking every {self.check_interval}s)")

        async with ClaudeSDKClient(self.options) as client:
            # Send initial query if provided
            if self.initial_query:
                logger.info(f"Sending initial query: {self.initial_query}")
                await client.query(self.initial_query)
                await self._process_response(client)

            # Main monitoring loop
            while True:
                if self.pr_monitor.has_new_comments():
                    logger.info("New comments detected, asking Claude to fix them")

                    # Send query to Claude - maintains conversation context
                    await client.query(
                        "Please use the /pr:fix-comments skill to address all of them."
                    )
                    await self._process_response(client)

                    # Mark comments as processed
                    self.pr_monitor.mark_comments_processed()
                    logger.info("Comments processed successfully")
                else:
                    logger.debug("No new comments found")

                await asyncio.sleep(self.check_interval)


def main():
    """Main entry point for the Claude Code Agent."""
    import argparse

    parser = argparse.ArgumentParser(
        description="Claude Code Agent - Automated PR comment handling"
    )
    parser.add_argument(
        "--github-token",
        default=os.environ.get("GITHUB_TOKEN"),
        help="GitHub token (default: GITHUB_TOKEN env var)",
    )
    parser.add_argument(
        "--repo",
        default=os.environ.get("GITHUB_REPOSITORY"),
        help="GitHub repository (owner/repo format)",
    )
    parser.add_argument("--pr", type=int, default=os.environ.get("PR_NUMBER"), help="PR number")
    parser.add_argument(
        "--interval",
        type=int,
        default=int(os.environ.get("CHECK_INTERVAL", "60")),
        help="Check interval in seconds (default: 60)",
    )
    parser.add_argument(
        "--system-prompt",
        default=os.environ.get("SYSTEM_PROMPT_PATH"),
        help="Path to additional system prompt file",
    )
    parser.add_argument(
        "--query",
        help="Initial query to send to Claude before starting the monitoring loop",
    )

    args = parser.parse_args()

    # Validate required arguments
    if not args.github_token:
        logger.error("GITHUB_TOKEN not set. Use --github-token or set environment variable.")
        sys.exit(1)

    if not args.repo:
        logger.error("GITHUB_REPOSITORY not set. Use --repo or set environment variable.")
        sys.exit(1)

    if not args.pr:
        logger.error("PR_NUMBER not set. Use --pr or set environment variable.")
        sys.exit(1)

    # Verify ANTHROPIC_API_KEY is set (required by SDK)
    if not os.environ.get("ANTHROPIC_API_KEY"):
        logger.error("ANTHROPIC_API_KEY not set. The Claude Agent SDK requires this.")
        sys.exit(1)

    logger.info(f"Repository: {args.repo}")
    logger.info(f"PR Number: {args.pr}")

    # Create and run agent
    agent = ClaudeCodeAgent(
        github_token=args.github_token,
        repo_name=args.repo,
        pr_number=args.pr,
        check_interval=args.interval,
        system_prompt_path=args.system_prompt,
        initial_query=args.query,
    )

    asyncio.run(agent.run())


if __name__ == "__main__":
    main()
