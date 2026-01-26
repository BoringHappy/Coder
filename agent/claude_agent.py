#!/usr/bin/env python3
"""
Claude Code Agent - Python-controlled loop for automated PR comment handling.

This agent implements the functionality of `claude --dangerously-skip-permissions`
with automated GitHub PR comment monitoring and resolution.
"""

import os
import sys
import json
import time
import subprocess
import logging
import asyncio
from pathlib import Path
from typing import Dict, List, Optional, Any
from datetime import datetime

from claude_agent_sdk import (
    ClaudeSDKClient,
    ClaudeAgentOptions,
    AssistantMessage,
    TextBlock,
    ToolUseBlock,
    ResultMessage
)


# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class GitHubPRMonitor:
    """Monitors GitHub PR for new comments."""

    def __init__(self, repo: str, pr_number: int):
        self.repo = repo
        self.pr_number = pr_number
        self.last_check_time = datetime.now()
        self.processed_comment_ids = set()

    def get_pr_comments(self) -> List[Dict[str, Any]]:
        """Fetch PR review comments using gh CLI."""
        try:
            # Get review comments
            result = subprocess.run(
                ['gh', 'api', f'/repos/{self.repo}/pulls/{self.pr_number}/comments'],
                capture_output=True,
                text=True,
                check=True
            )
            review_comments = json.loads(result.stdout)

            # Get issue comments (general PR comments)
            result = subprocess.run(
                ['gh', 'api', f'/repos/{self.repo}/issues/{self.pr_number}/comments'],
                capture_output=True,
                text=True,
                check=True
            )
            issue_comments = json.loads(result.stdout)

            return review_comments + issue_comments
        except subprocess.CalledProcessError as e:
            logger.error(f"Failed to fetch PR comments: {e}")
            return []

    def get_new_comments(self) -> List[Dict[str, Any]]:
        """Get comments that haven't been processed yet."""
        all_comments = self.get_pr_comments()
        new_comments = []

        for comment in all_comments:
            comment_id = comment['id']
            comment_time = datetime.fromisoformat(
                comment['created_at'].replace('Z', '+00:00')
            )

            if (comment_id not in self.processed_comment_ids and
                comment_time > self.last_check_time):
                new_comments.append(comment)
                self.processed_comment_ids.add(comment_id)

        return new_comments


class ClaudeCodeAgent:
    """Main agent that controls Claude Code with automated PR comment handling."""

    def __init__(
        self,
        api_key: str,
        repo: str,
        pr_number: int,
        check_interval: int = 60,
        system_prompt_path: Optional[str] = None
    ):
        self.api_key = api_key
        self.repo = repo
        self.pr_number = pr_number
        self.check_interval = check_interval
        self.pr_monitor = GitHubPRMonitor(repo, pr_number)

        # Load system prompt
        self.system_prompt = self._load_system_prompt(system_prompt_path)

        # Configure Claude Agent SDK options
        self.options = ClaudeAgentOptions(
            tools=['*'],  # Enable all tools
            permission_mode='bypassPermissions',  # Equivalent to --dangerously-skip-permissions
            system_prompt=self.system_prompt
        )

        # Initialize Claude SDK Client
        self.client = None

        logger.info(f"Initialized ClaudeCodeAgent for {repo} PR #{pr_number}")
        logger.info("Configured with all tools enabled and bypass permissions mode")

    def _load_system_prompt(self, path: Optional[str]) -> str:
        """Load system prompt from file or use default."""
        if path and Path(path).exists():
            return Path(path).read_text()

        # Default system prompt path
        default_path = Path("/usr/local/bin/setup/prompt/system_prompt.txt")
        if default_path.exists():
            return default_path.read_text()

        return "You are a helpful AI assistant specialized in managing GitHub Pull Request workflows."

    def _format_comment_for_query(self, comment: Dict[str, Any]) -> str:
        """Format a PR comment into a query for Claude."""
        author = comment.get('user', {}).get('login', 'Unknown')
        body = comment.get('body', '')
        path = comment.get('path', '')
        line = comment.get('line', '')

        query = f"PR Review Comment from {author}:\n\n"

        if path:
            query += f"File: {path}\n"
        if line:
            query += f"Line: {line}\n"

        query += f"\nComment:\n{body}\n\n"
        query += "Please address this review comment by making the necessary code changes."

        return query

    async def handle_new_comments(self) -> None:
        """Check for new PR comments and handle them."""
        new_comments = self.pr_monitor.get_new_comments()

        if not new_comments:
            logger.debug("No new comments found")
            return

        logger.info(f"Found {len(new_comments)} new comment(s)")

        for comment in new_comments:
            try:
                query = self._format_comment_for_query(comment)
                logger.info(f"Processing comment {comment['id']}: {comment.get('body', '')[:50]}...")

                # Create client if not exists
                if self.client is None:
                    self.client = ClaudeSDKClient(options=self.options)
                    await self.client.connect()

                # Send query to Claude
                await self.client.query(query)

                # Process response
                async for message in self.client.receive_response():
                    if isinstance(message, AssistantMessage):
                        for block in message.content:
                            if isinstance(block, TextBlock):
                                logger.info(f"Claude: {block.text[:100]}...")
                    elif isinstance(message, ResultMessage):
                        logger.info(f"Task completed in {message.duration_ms}ms")

                # Optionally reply to the comment
                self._reply_to_comment(comment['id'], "Changes have been made to address this comment.")

            except Exception as e:
                logger.error(f"Failed to handle comment {comment['id']}: {e}")

    def _reply_to_comment(self, comment_id: int, message: str) -> None:
        """Reply to a PR comment."""
        try:
            subprocess.run(
                ['gh', 'api', '-X', 'POST',
                 f'/repos/{self.repo}/pulls/{self.pr_number}/comments/{comment_id}/replies',
                 '-f', f'body={message}'],
                capture_output=True,
                text=True,
                check=True
            )
            logger.info(f"Replied to comment {comment_id}")
        except subprocess.CalledProcessError as e:
            logger.error(f"Failed to reply to comment: {e}")

    async def run(self) -> None:
        """Main loop - continuously monitor for new comments and handle them."""
        logger.info("Starting Claude Code Agent loop...")
        logger.info(f"Monitoring PR #{self.pr_number} every {self.check_interval} seconds")

        try:
            while True:
                try:
                    await self.handle_new_comments()
                except Exception as e:
                    logger.error(f"Error in main loop: {e}")

                await asyncio.sleep(self.check_interval)

        except KeyboardInterrupt:
            logger.info("Agent stopped by user")
        finally:
            if self.client:
                await self.client.disconnect()


def get_repo_info() -> tuple[str, int]:
    """Get repository and PR information from environment or git."""
    # Try to get PR number from environment
    pr_number = os.environ.get('PR_NUMBER')
    if pr_number:
        pr_number = int(pr_number)
    else:
        # Try to get from current branch
        try:
            result = subprocess.run(
                ['gh', 'pr', 'view', '--json', 'number'],
                capture_output=True,
                text=True,
                check=True
            )
            pr_data = json.loads(result.stdout)
            pr_number = pr_data['number']
        except (subprocess.CalledProcessError, KeyError, json.JSONDecodeError):
            logger.error("Could not determine PR number. Set PR_NUMBER environment variable.")
            sys.exit(1)

    # Get repository
    repo = os.environ.get('GITHUB_REPOSITORY')
    if not repo:
        try:
            result = subprocess.run(
                ['gh', 'repo', 'view', '--json', 'nameWithOwner'],
                capture_output=True,
                text=True,
                check=True
            )
            repo_data = json.loads(result.stdout)
            repo = repo_data['nameWithOwner']
        except (subprocess.CalledProcessError, KeyError, json.JSONDecodeError):
            logger.error("Could not determine repository. Set GITHUB_REPOSITORY environment variable.")
            sys.exit(1)

    return repo, pr_number


def main():
    """Main entry point for the Claude Code Agent."""
    import argparse

    parser = argparse.ArgumentParser(
        description='Claude Code Agent - Automated PR comment handling'
    )
    parser.add_argument(
        '--api-key',
        default=os.environ.get('ANTHROPIC_API_KEY'),
        help='Anthropic API key (default: ANTHROPIC_API_KEY env var)'
    )
    parser.add_argument(
        '--repo',
        help='GitHub repository (owner/repo format, default: auto-detect)'
    )
    parser.add_argument(
        '--pr',
        type=int,
        help='PR number (default: auto-detect from current branch)'
    )
    parser.add_argument(
        '--interval',
        type=int,
        default=60,
        help='Check interval in seconds (default: 60)'
    )
    parser.add_argument(
        '--system-prompt',
        help='Path to system prompt file'
    )
    parser.add_argument(
        '--once',
        action='store_true',
        help='Run once and exit (don\'t loop)'
    )

    args = parser.parse_args()

    # Validate API key
    if not args.api_key:
        logger.error("ANTHROPIC_API_KEY not set. Use --api-key or set environment variable.")
        sys.exit(1)

    # Get repo and PR info
    if args.repo and args.pr:
        repo = args.repo
        pr_number = args.pr
    else:
        repo, pr_number = get_repo_info()

    logger.info(f"Repository: {repo}")
    logger.info(f"PR Number: {pr_number}")

    # Create and run agent
    agent = ClaudeCodeAgent(
        api_key=args.api_key,
        repo=repo,
        pr_number=pr_number,
        check_interval=args.interval,
        system_prompt_path=args.system_prompt
    )

    if args.once:
        logger.info("Running once...")
        asyncio.run(agent.handle_new_comments())
    else:
        asyncio.run(agent.run())


if __name__ == '__main__':
    main()
